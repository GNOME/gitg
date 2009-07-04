#include <glib/gi18n.h>

#include "gitg-branch-actions.h"

typedef enum
{
	GITG_PROGRESS_SUCCESS,
	GITG_PROGRESS_ERROR,
	GITG_PROGRESS_CANCELLED
} GitgProgress;

typedef void (*ProgressCallback)(GitgWindow *window, GitgProgress progress, gpointer data);

typedef struct
{
	GitgWindow *window;
	GitgRunner *runner;
	
	ProgressCallback callback;
	gpointer callback_data;
	
	guint timeout_id;
	
	GtkDialog *dialog;
	GtkProgressBar *progress;
} ProgressInfo;

static void
free_progress_info (ProgressInfo *info)
{
	if (info->timeout_id)
	{
		g_source_remove (info->timeout_id);
	}

	gtk_widget_destroy (GTK_WIDGET (info->dialog));

	g_object_unref (info->runner);
	g_slice_free (ProgressInfo, info);
}

static gchar const **
parse_valist(va_list ap)
{
	gchar const *a;
	gchar const **ret = NULL;
	guint num = 0;
	
	while ((a = va_arg(ap, gchar const *)) != NULL)
	{
		ret = g_realloc(ret, sizeof(gchar const *) * (++num + 1));
		ret[num - 1] = a;
	}
	
	ret[num] = NULL;
	return ret;
}

static void
on_progress_end (GitgRunner *runner, gboolean cancelled, ProgressInfo *info)
{
	GitgProgress progress;
	
	if (cancelled)
	{
		progress = GITG_PROGRESS_CANCELLED;
	}
	else if (gitg_runner_get_exit_status (runner) != 0)
	{
		progress = GITG_PROGRESS_ERROR;
	}
	else
	{
		progress = GITG_PROGRESS_SUCCESS;
	}

	GitgWindow *window = info->window;
	ProgressCallback callback = info->callback;
	gpointer data = info->callback_data;
	free_progress_info (info);
	
	callback (window, progress, data);
}

static void
on_progress_response (GtkDialog *dialog, GtkResponseType response, ProgressInfo *info)
{
	gitg_runner_cancel (info->runner);
}

static gboolean
on_progress_timeout (ProgressInfo *info)
{
	gtk_progress_bar_pulse (info->progress);
	return TRUE;
}

static GitgRunner *
run_progress (GitgWindow       *window,
              gchar const      *title,
              gchar const      *message,
              ProgressCallback  callback,
              gpointer          callback_data,
              ...)
{
	va_list ap;
	
	// Create runner
	va_start (ap, callback_data);
	
	GitgRunner *runner = gitg_runner_new (1000);
	gchar const **argv = parse_valist (ap);
	
	if (!gitg_repository_run_command (gitg_window_get_repository (window),
	                                  runner,
	                                  argv,
	                                  NULL))
	{
		g_free (argv);
		g_object_unref (runner);
		
		callback (window, GITG_PROGRESS_ERROR, callback_data);	

		return NULL;
	}
	
	g_free (argv);
	
	// Create dialog to show progress	
	GtkDialogFlags flags = GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT;
	GtkWidget *dlg;

	dlg = gtk_message_dialog_new (GTK_WINDOW (window),
	                              flags,
	                              GTK_MESSAGE_INFO,
	                              GTK_BUTTONS_CANCEL,
	                              "%s",
	                              title);

	gtk_message_dialog_format_secondary_text (GTK_MESSAGE_DIALOG (dlg),
	                                          "%s",
	                                          message);

	// Add progress bar
	GtkWidget *area = gtk_dialog_get_content_area (GTK_DIALOG (dlg));
	GtkWidget *progress = gtk_progress_bar_new ();
	gtk_widget_show (progress);
	
	gtk_box_pack_start (GTK_BOX (area), progress, FALSE, FALSE, 0);
	
	gtk_widget_show (dlg);
	
	ProgressInfo *info = g_slice_new0 (ProgressInfo);
	
	info->dialog = GTK_DIALOG (dlg);
	info->progress = GTK_PROGRESS_BAR (progress);
	info->callback = callback;
	info->callback_data = callback_data;
	info->window = window;
	info->runner = g_object_ref (runner);
	
	info->timeout_id = g_timeout_add (100, (GSourceFunc)on_progress_timeout, info);
	
	g_signal_connect (dlg, "response", G_CALLBACK (on_progress_response), info);
	g_signal_connect (runner, "end-loading", G_CALLBACK (on_progress_end), info);
	
	return runner;
}
              
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
gitg_branch_actions_remove (GitgWindow *window,
                            GitgRef    *ref)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
		
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

gboolean
gitg_branch_actions_checkout (GitgWindow *window,
                              GitgRef    *ref)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);

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
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	return FALSE;
}

gboolean
gitg_branch_actions_rebase (GitgWindow *window,
                            GitgRef    *source,
                            GitgRef    *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	return FALSE;
}

typedef struct
{
	GitgRef *source;
	GitgRef *dest;
} PushInfo;

static void
on_push_result (GitgWindow   *window,
                GitgProgress  progress,
                gpointer      data)
{
	PushInfo *info = (PushInfo *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		message_dialog (window,
			            GTK_MESSAGE_ERROR,
			            _("Failed to push local branch <%s> to remote <%s>"),
			            NULL,
			            NULL,
			            gitg_ref_get_shortname (info->source),
			            gitg_ref_get_shortname (info->dest));
	}
	else if (progress == GITG_PROGRESS_SUCCESS)
	{
		gitg_repository_reload (gitg_window_get_repository (window));
	}

	gitg_ref_free (info->source);
	gitg_ref_free (info->dest);
	g_slice_free (PushInfo, info);
}

GitgRunner *
gitg_branch_actions_push (GitgWindow *window,
                          GitgRef    *source,
                          GitgRef    *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_REMOTE, NULL);
	
	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _("Are you sure you want to push <%s> to <%s>?"),
	                    NULL,
	                    _("Push"),
	                    gitg_ref_get_shortname (source),
	                    gitg_ref_get_shortname (dest)) != GTK_RESPONSE_ACCEPT)
	{
		return NULL;
	}

	gchar const *prefix = gitg_ref_get_prefix (dest);
	gchar *local = gitg_ref_get_local_name (dest);
	gchar const *name = gitg_ref_get_shortname (source);
	
	gchar *spec = g_strconcat (name, ":", local, NULL);
	gchar *message = g_strdup_printf (_("Pushing local branch `%s' to remote branch `%s'"),
	                                  gitg_ref_get_shortname (source),
	                                  gitg_ref_get_shortname (dest));
	
	GitgRunner *ret;
	PushInfo *info = g_slice_new (PushInfo);
	info->source = gitg_ref_copy (source);
	info->dest = gitg_ref_copy (dest);
	
	ret = run_progress (window, 
	                    _("Push"), 
	                    message, 
	                    on_push_result,  
	                    info,
	                    "push",
	                    prefix,
	                    spec,
	                    NULL);
	
	g_free (message);
	g_free (local);
	g_free (spec);
	
	return ret;
}

gboolean
gitg_branch_actions_apply_stash (GitgWindow *window,
                                 GitgRef    *stash)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	return FALSE;
}

