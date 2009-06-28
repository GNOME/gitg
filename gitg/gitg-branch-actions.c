#include <glib/gi18n.h>

#include "gitg-branch-actions.h"

static gint
message_dialog (GitgWindow     *window,
                GtkMessageType  type,
                gchar const    *primary,
                gchar const    *secondary,
                gchar const    *accept,
                ...)
{
	GtkWidget *dlg;
	va_list ap;
	
	va_start (ap, accept);
	gchar *prim = g_strdup_vprintf (primary, ap);
	va_end (ap);
	
	GtkDialogFlags flags = GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT;
	dlg = gtk_message_dialog_new (GTK_WINDOW (window),
	                              flags,
	                              type,
	                              GTK_BUTTONS_NONE,
	                              "%s",
	                              prim);

	g_free (prim);
	
	if (secondary)
	{
		gtk_message_dialog_format_secondary_text (GTK_MESSAGE_DIALOG (dlg),
		                                          "%s",
		                                          secondary);
	}
	
	GtkWidget *button;
	
	button = gtk_button_new_from_stock (accept ? GTK_STOCK_CANCEL : GTK_STOCK_OK);
	gtk_widget_show (button);
	gtk_dialog_add_action_widget (GTK_DIALOG (dlg), 
	                              button, 
	                              accept ? GTK_RESPONSE_CANCEL : GTK_RESPONSE_ACCEPT);

	if (accept)
	{
		button = gtk_button_new_with_label (accept);
		gtk_widget_show (button);
	
		GtkWidget *image = gtk_image_new_from_stock (GTK_STOCK_OK, 
			                                         GTK_ICON_SIZE_BUTTON);
		gtk_widget_show (image);
	
		gtk_button_set_image (GTK_BUTTON (button), image);
		gtk_dialog_add_action_widget (GTK_DIALOG (dlg), 
			                          button, 
			                          GTK_RESPONSE_ACCEPT);
	}

	gint ret = gtk_dialog_run (GTK_DIALOG (dlg));
	gtk_widget_destroy (dlg);
	
	return ret;
}                

static gboolean
remove_local_branch (GitgWindow *window,
                     GitgRef    *ref)
{
	gchar const *name = gitg_ref_get_shortname (ref);
	GitgRepository *repository = gitg_window_get_repository (window);

	if (!gitg_repository_commandv (repository, NULL, "branch", "-d", name, NULL))
	{
		gint ret = message_dialog (window,
		                           GTK_MESSAGE_ERROR,
		                           _("Branch <%s> could not be removed"),
		                           _("This usually means that the branch is not fully merged in HEAD. Do you want to forcefully remove the branch?"),
		                           _("Force remove"),
		                           name);

		if (ret == GTK_RESPONSE_ACCEPT)
		{
			if (!gitg_repository_commandv (repository, NULL, "branch", "-D", name, NULL))
			{
				message_dialog (window, 
				                GTK_MESSAGE_ERROR,
				                _("Branch <%s> could not be forcefully removed"),
				                NULL,
				                NULL,
				                name);

				return FALSE;
			}
			else
			{
				gitg_repository_reload (repository);
				return TRUE;
			}
		}
	}
	else
	{
		gitg_repository_reload (repository);

		return TRUE;
	}
	
	return FALSE;
}

static gboolean
remove_remote_branch (GitgWindow *window,
                      GitgRef    *ref)
{
	gchar const *name = gitg_ref_get_shortname (ref);
	GitgRepository *repository = gitg_window_get_repository (window);

	gint ret = message_dialog (window,
	                          GTK_MESSAGE_QUESTION,
	                          _("Are you sure you want to remove the remote branch <%s>?"),
	                          _("This permanently removes the remote branch."),
	                          _("Remove remote branch"),
	                          name);
	
	if (ret == GTK_RESPONSE_ACCEPT)
	{
		gchar *local = gitg_ref_get_local_name (ref);
		gchar *rm = g_strconcat (":", local, NULL);
		g_free (local);
		
		if (!gitg_repository_commandv (repository,
		                               NULL,
		                               "push",
		                               gitg_ref_get_prefix (ref),
		                               rm,
		                               NULL))
		{
			message_dialog (window, 
			                GTK_MESSAGE_ERROR,
			                _("Failed to remove remote branch <%s>."),
			                NULL,
			                NULL,
			                name);
			return FALSE;
		}
		else
		{
			gitg_repository_reload (repository);
			return TRUE;
		}
	}
	
	return FALSE;
}

gboolean 
gitg_branch_actions_remove (GitgWindow *window,
                            GitgRef    *ref)
{
	GitgRef *cp = gitg_ref_copy (ref);
	gboolean ret = FALSE;
	
	switch (gitg_ref_get_ref_type (cp))
	{
		case GITG_REF_TYPE_BRANCH:
			ret = remove_local_branch (window, cp);
		break;
		case GITG_REF_TYPE_REMOTE:
			ret = remove_remote_branch (window, cp);
		break;
		default:
		break;
	}
	
	gitg_ref_free (cp);
	return ret;
}

static gboolean
stash_changes (GitgWindow *window,
               GitgRef    *ref)
{
	GitgRepository *repository = gitg_window_get_repository (window);
	
	gchar **output = gitg_repository_command_with_outputv (repository,
	                                                       NULL,
	                                                       "diff-files",
	                                                       NULL);

	if (output && *output && **output)
	{
		gint ret = message_dialog (window,
		                           GTK_MESSAGE_QUESTION,
		                           _("You have uncommited changes in your current working copy"),
		                           _("Do you want to temporarily stash these changes?"),
		                           _("Stash changes"));

		if (ret != GTK_RESPONSE_ACCEPT)
		{
			return FALSE;
		}
		
		if (!gitg_repository_commandv (repository, NULL, "stash", NULL))
		{
			message_dialog (window,
			                GTK_MESSAGE_ERROR,
			                _("Could not stash changes from your current working copy."),
			                NULL,
			                NULL);
			return FALSE;
		}
	}

	if (output)
	{
		g_strfreev (output);
	}
	
	return TRUE;
}

static gboolean
checkout_local_branch (GitgWindow *window,
                       GitgRef    *ref)
{
	if (!stash_changes (window, ref))
	{
		return FALSE;
	}
		
	GitgRepository *repository = gitg_window_get_repository (window);
	gchar const *name = gitg_ref_get_shortname (ref);
	
	if (!gitg_repository_commandv (repository, NULL, "checkout", name, NULL))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _("Failed to checkout local branch <%s>"),
		                NULL,
		                NULL,
		                name);
		return FALSE;
	}
	else
	{
		gitg_repository_load (repository, 1, (gchar const **)&name, NULL);
		return TRUE;
	}
}

static gboolean
checkout_remote_branch (GitgWindow *window,
                        GitgRef    *ref)
{
	if (!stash_changes (window, ref))
	{
		return FALSE;
	}
		
	GitgRepository *repository = gitg_window_get_repository (window);
	gchar const *name = gitg_ref_get_shortname (ref);
	gchar *local = gitg_ref_get_local_name (ref);
	gboolean ret;
	
	if (!gitg_repository_commandv (repository, 
	                               NULL, 
	                               "checkout", 
	                               "--track", 
	                               "-b",
	                               local,
	                               name,
	                               NULL))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _("Failed to checkout remote branch <%s> to local branch <%s>"),
		                NULL,
		                NULL,
		                name,
		                local);
		ret = FALSE;
	}
	else
	{
		gitg_repository_load (repository, 1, (gchar const **)&local, NULL);
		ret = TRUE;
	}
	
	g_free (local);
	return ret;
}

gboolean
gitg_branch_actions_checkout (GitgWindow *window,
                              GitgRef    *ref)
{
	GitgRef *cp = gitg_ref_copy (ref);
	gboolean ret = FALSE;
	
	switch (gitg_ref_get_ref_type (cp))
	{
		case GITG_REF_TYPE_BRANCH:
			ret = checkout_local_branch (window, cp);
		break;
		case GITG_REF_TYPE_REMOTE:
			ret = checkout_remote_branch (window, cp);
		break;
		default:
		break;
	}
	
	gitg_ref_free (cp);
	return ret;
}

gboolean
gitg_branch_actions_merge (GitgWindow *window,
                           GitgRef    *source,
                           GitgRef    *dest)
{
	return FALSE;
}

gboolean
gitg_branch_actions_rebase (GitgWindow *window,
                            GitgRef    *source,
                            GitgRef    *dest)
{
	return FALSE;
}

gboolean
gitg_branch_actions_apply_stash (GitgWindow *window,
                                 GitgRef    *stash)
{
	return FALSE;
}

