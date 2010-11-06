/*
 * gitg-branch-actions.h
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <glib/gi18n.h>
#include <libgitg/gitg-hash.h>
#include <unistd.h>

#include "gitg-branch-actions.h"

typedef enum
{
	GITG_PROGRESS_SUCCESS,
	GITG_PROGRESS_ERROR,
	GITG_PROGRESS_CANCELLED
} GitgProgress;

typedef void (*ProgressCallback) (GitgWindow *window, GitgProgress progress, gpointer data);

typedef struct
{
	GitgWindow *window;
	GitgShell *shell;

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

	g_object_unref (info->shell);
	g_slice_free (ProgressInfo, info);
}

static gchar const **
parse_valist (va_list ap)
{
	gchar const *a;
	gchar const **ret = NULL;
	guint num = 0;

	while ( (a = va_arg (ap, gchar const *)) != NULL)
	{
		ret = g_realloc (ret, sizeof (gchar const *) * (++num + 1));
		ret[num - 1] = a;
	}

	ret[num] = NULL;
	return ret;
}

static void
on_progress_end (GitgShell *shell, gboolean cancelled, ProgressInfo *info)
{
	GitgProgress progress;

	if (cancelled)
	{
		progress = GITG_PROGRESS_CANCELLED;
	}
	else if (gitg_io_get_exit_status (GITG_IO (shell)) != 0)
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
	gitg_io_cancel (GITG_IO (info->shell));
}

static gboolean
on_progress_timeout (ProgressInfo *info)
{
	gtk_progress_bar_pulse (info->progress);
	return TRUE;
}

static GitgShell *
run_progress (GitgWindow       *window,
              gchar const      *title,
              gchar const      *message,
              ProgressCallback  callback,
              gpointer          callback_data,
              ...)
{
	va_list ap;

	va_start (ap, callback_data);

	GitgShell *shell = gitg_shell_new (1000);
	gchar const **argv = parse_valist (ap);

	GitgCommand *cmd = gitg_command_newv (gitg_window_get_repository (window),
	                                      (gchar const * const *)argv);

	if (!gitg_shell_run (shell, cmd, NULL))
	{
		g_free (argv);
		g_object_unref (shell);

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

	gtk_window_set_title (GTK_WINDOW (dlg), _ ("gitg"));

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
	info->shell = g_object_ref (shell);

	info->timeout_id = g_timeout_add (100, (GSourceFunc)on_progress_timeout, info);

	g_signal_connect (dlg, "response", G_CALLBACK (on_progress_response), info);
	g_signal_connect (shell, "end", G_CALLBACK (on_progress_end), info);

	return shell;
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

	gtk_window_set_title (GTK_WINDOW (dlg), _ ("gitg"));

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

static GitgShell *
remove_local_branch (GitgWindow *window,
                     GitgRef    *ref)
{
	gchar const *name = gitg_ref_get_shortname (ref);
	GitgRepository *repository = gitg_window_get_repository (window);

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "branch",
	                                             "-d",
	                                             name,
	                                             NULL),
	                          NULL))
	{
		gint ret = message_dialog (window,
		                           GTK_MESSAGE_ERROR,
		                           _ ("Branch <%s> could not be removed"),
		                           _ ("This usually means that the branch is not fully merged in HEAD. Do you want to forcefully remove the branch?"),
		                           _ ("Force remove"),
		                           name);

		if (ret == GTK_RESPONSE_ACCEPT)
		{
			if (!gitg_shell_run_sync (gitg_command_new (repository,
			                                             "branch",
			                                             "-D",
			                                             name,
			                                             NULL),
			                          NULL))
			{
				message_dialog (window,
				                GTK_MESSAGE_ERROR,
				                _ ("Branch <%s> could not be forcefully removed"),
				                NULL,
				                NULL,
				                name);

				return NULL;
			}
			else
			{
				gitg_repository_reload (repository);
				return NULL;
			}
		}
	}
	else
	{
		gitg_repository_reload (repository);

		return NULL;
	}

	return NULL;
}

static void
on_remove_remote_result (GitgWindow *window, GitgProgress progress, gpointer data)
{
	GitgRef *ref = (GitgRef *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to remove remote branch <%s>."),
		                NULL,
		                NULL,
		                gitg_ref_get_shortname (ref));
	}
	else if (progress == GITG_PROGRESS_SUCCESS)
	{
		gitg_repository_reload (gitg_window_get_repository (window));
	}

	gitg_ref_free (ref);
}

static GitgShell *
remove_remote_branch (GitgWindow *window,
                      GitgRef    *ref)
{
	gchar const *name = gitg_ref_get_shortname (ref);

	gint r = message_dialog (window,
	                         GTK_MESSAGE_QUESTION,
	                         _ ("Are you sure you want to remove the remote branch <%s>?"),
	                         _ ("This permanently removes the remote branch."),
	                         _ ("Remove remote branch"),
	                         name);

	if (r != GTK_RESPONSE_ACCEPT)
	{
		return NULL;
	}

	gchar const *local = gitg_ref_get_local_name (ref);
	gchar *rm = g_strconcat (":", local, NULL);

	GitgShell *ret;
	gchar *message = g_strdup_printf ("Removing remote branch `%s'", name);

	ret = run_progress (window,
	                    _ ("Remove branch"),
	                    message,
	                    on_remove_remote_result,
	                    gitg_ref_copy (ref),
	                    "push",
	                    gitg_ref_get_prefix (ref),
	                    rm,
	                    NULL);
	g_free (message);

	return ret;
}

static gchar *
get_stash_refspec (GitgRepository *repository, GitgRef *stash)
{
	gchar **out;

	out = gitg_shell_run_sync_with_output (gitg_command_new (repository,
	                                                          "log",
	                                                          "--no-color",
	                                                          "--pretty=oneline",
	                                                          "-g",
	                                                          "refs/stash",
	                                                          NULL),
	                                       FALSE,
	                                       NULL);

	gchar **ptr = out;
	gchar *sha1 = gitg_hash_hash_to_sha1_new (gitg_ref_get_hash (stash));
	gchar *ret = NULL;

	while (ptr && *ptr)
	{
		if (g_str_has_prefix (*ptr, sha1))
		{
			gchar *start = *ptr + GITG_HASH_SHA_SIZE + 1;
			gchar *end = strchr (start, ':');

			if (end)
			{
				ret = g_strndup (start, end - start);
			}
			break;
		}
		ptr++;
	}

	g_strfreev (out);
	g_free (sha1);

	return ret;
}

static GitgShell *
remove_stash (GitgWindow *window, GitgRef *ref)
{
	gint r = message_dialog (window,
	                         GTK_MESSAGE_QUESTION,
	                         _ ("Are you sure you want to remove this stash item?"),
	                         _ ("This permanently removes the stash item"),
	                         _ ("Remove stash"));

	if (r != GTK_RESPONSE_ACCEPT)
	{
		return NULL;
	}

	GitgRepository *repository = gitg_window_get_repository (window);
	gchar *spec = get_stash_refspec (repository, ref);

	if (!spec)
	{
		return NULL;
	}

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "reflog",
	                                             "delete",
	                                             "--updateref",
	                                             "--rewrite",
	                                             spec,
	                                             NULL),
	                          NULL))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to remove stash"),
		                _ ("The stash item could not be successfully removed"),
		                NULL);
	}
	else
	{
		if (!gitg_shell_run_sync (gitg_command_new (repository,
		                                             "rev-parse",
		                                             "--verify",
		                                             "refs/stash@{0}",
		                                             NULL),
		                          NULL))
		{
			gitg_shell_run_sync (gitg_command_new (repository,
			                                        "update-ref",
			                                        "-d",
			                                        "refs/stash",
			                                        NULL),
			                     NULL);
		}

		gitg_repository_reload (repository);
	}

	g_free (spec);
	return NULL;
}

static GitgShell *
remove_tag (GitgWindow *window, GitgRef *ref)
{
	gchar const *name = gitg_ref_get_shortname (ref);
	gchar *message = g_strdup_printf (_ ("Are you sure you want to remove the tag <%s>?"),
	                                  name);
	gint r = message_dialog (window,
	                         GTK_MESSAGE_QUESTION,
	                         _ ("Remove tag"),
	                         message,
	                         _ ("Remove tag"));
	g_free (message);

	if (r != GTK_RESPONSE_ACCEPT)
	{
		return NULL;
	}

	GitgRepository *repository = gitg_window_get_repository (window);

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "tag",
	                                             "-d",
	                                             name,
	                                             NULL),
	                          NULL))
	{
		message = g_strdup_printf (_ ("The tag <%s> could not be successfully removed"),
		                           name);
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to remove tag"),
		                message,
		                NULL);
		g_free (message);
		return NULL;
	}
	else
	{
		gitg_repository_reload (repository);
		return NULL;
	}
}

GitgShell *
gitg_branch_actions_remove (GitgWindow *window,
                            GitgRef    *ref)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (ref != NULL, NULL);

	GitgRef *cp = gitg_ref_copy (ref);
	GitgShell *ret = NULL;

	switch (gitg_ref_get_ref_type (cp))
	{
		case GITG_REF_TYPE_BRANCH:
			ret = remove_local_branch (window, cp);
		break;
		case GITG_REF_TYPE_REMOTE:
			ret = remove_remote_branch (window, cp);
		break;
		case GITG_REF_TYPE_STASH:
			ret = remove_stash (window, cp);
		break;
		case GITG_REF_TYPE_TAG:
			ret = remove_tag (window, cp);
		break;
		default:
		break;
	}

	gitg_ref_free (cp);
	return ret;
}

static GitgShell *
rename_branch (GitgWindow  *window,
               GitgRef     *ref,
               const gchar *newname)
{
	gchar const *oldname = gitg_ref_get_shortname (ref);
	GitgRepository *repository = gitg_window_get_repository (window);

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "branch",
	                                             "-m",
	                                             oldname,
	                                             newname,
	                                             NULL),
	                          NULL))
	{
		gint ret = message_dialog (window,
		                           GTK_MESSAGE_ERROR,
		                           _ ("Branch <%s> could not be renamed to <%s>"),
		                           _ ("This usually means that a branch with that name already exists. Do you want to overwrite the branch?"),
		                           _ ("Force rename"),
		                           oldname, newname);

		if (ret == GTK_RESPONSE_ACCEPT)
		{
			if (!gitg_shell_run_sync (gitg_command_new (repository,
			                                             "branch",
			                                             "-M",
			                                             oldname,
			                                             newname,
			                                             NULL),
			                         NULL))
			{
				message_dialog (window,
				                GTK_MESSAGE_ERROR,
				                _ ("Branch <%s> could not be forcefully renamed"),
				                NULL,
				                NULL,
				                oldname);

				return NULL;
			}
			else
			{
				gitg_repository_reload (repository);
				return NULL;
			}
		}
	}
	else
	{
		gitg_repository_reload (repository);

		return NULL;
	}

	return NULL;
}

static gchar *
rename_dialog (GitgWindow *window, const gchar *oldname)
{
	GtkWidget *dlg;

	GtkDialogFlags flags = GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT;
	dlg = gtk_dialog_new_with_buttons ("gitg",
	                                   GTK_WINDOW (window),
	                                   flags,
	                                   GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
	                                   "_Rename", GTK_RESPONSE_OK,
	                                   NULL);

#if ! GTK_CHECK_VERSION(2, 22, 0)
	gtk_dialog_set_has_separator (GTK_DIALOG (dlg), FALSE);
#endif

	gtk_dialog_set_default_response (GTK_DIALOG (dlg), GTK_RESPONSE_OK);

	GtkWidget *box = gtk_hbox_new (FALSE, 6);
	GtkWidget *label = gtk_label_new (_("Name:"));
	GtkWidget *entry = gtk_entry_new ();

	gtk_entry_set_text (GTK_ENTRY (entry), oldname);
	gtk_entry_set_width_chars (GTK_ENTRY (entry), 25);
	gtk_entry_set_activates_default (GTK_ENTRY (entry), TRUE);

	gtk_box_pack_start (GTK_BOX (box), label, FALSE, FALSE, 0);
	gtk_box_pack_start (GTK_BOX (box), entry, TRUE, TRUE, 0);
	gtk_widget_show_all (box);
	gtk_box_pack_start (GTK_BOX (gtk_dialog_get_content_area (GTK_DIALOG (dlg))), box, TRUE, TRUE, 12);
	gint ret = gtk_dialog_run (GTK_DIALOG (dlg));

	gchar *newname = NULL;
	if (ret == GTK_RESPONSE_OK)
	{
		const gchar *text = gtk_entry_get_text (GTK_ENTRY (entry));
		if (*text != '\0' && strcmp (text, oldname))
		{
			newname = g_strdup (text);
		}
	}

	gtk_widget_destroy (dlg);

	return newname;
}

GitgShell *
gitg_branch_actions_rename (GitgWindow *window,
                            GitgRef    *ref)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (ref != NULL, NULL);

	if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_BRANCH)
	{
		gchar *newname = rename_dialog (window, gitg_ref_get_shortname (ref));

		if (newname)
		{
			GitgRef *cp = gitg_ref_copy (ref);
			GitgShell *ret = NULL;
			ret = rename_branch (window, cp, newname);
			gitg_ref_free (cp);
			g_free (newname);
			return ret;
		}
	}

	return NULL;
}

static void
reset_buffer (GitgShell *shell, GString *buffer)
{
	g_string_erase (buffer, 0, -1);
}

static void
update_buffer (GitgShell *shell, gchar **lines, GString *buffer)
{
	gchar **ptr = lines;

	while (ptr && *ptr)
	{
		if (buffer->len != 0)
		{
			g_string_append_c (buffer, '\n');
		}

		g_string_append (buffer, *ptr);
		++ptr;
	}
}

static gboolean
no_changes (GitgRepository *repository)
{
	return gitg_shell_run_sync (gitg_command_new (repository,
	                                               "update-index",
	                                               "--refresh",
	                                               NULL),
	                            NULL) &&
	       gitg_shell_run_sync (gitg_command_new (repository,
	                                               "diff-files",
	                                               "--no-ext-diff",
	                                               "--quiet",
	                                               NULL),
	                            NULL) &&
	       gitg_shell_run_sync (gitg_command_new (repository,
	                                               "diff-index",
	                                               "--no-ext-diff",
	                                               "--cached",
	                                               "--quiet",
	                                               "HEAD",
	                                               "--",
	                                               NULL),
	                            NULL);
}

static gboolean
stash_changes_real (GitgWindow *window, gchar **ref, gboolean storeref)
{
	GitgRepository *repository = gitg_window_get_repository (window);
	gboolean ret;
	gchar *tree = NULL;
	gchar *commit = NULL;
	gchar *head = NULL;
	gchar *msg = NULL;
	gboolean showerror = FALSE;

	GitgShell *shell = gitg_shell_new_synchronized (1000);
	GString *buffer = g_string_new ("");

	g_signal_connect (shell, "begin", G_CALLBACK (reset_buffer), buffer);
	g_signal_connect (shell, "update", G_CALLBACK (update_buffer), buffer);

	gchar const *secondary;

	if (storeref)
	{
		secondary = _ ("Do you want to temporarily stash these changes?");
	}
	else
	{
		secondary = _ ("Do you want to stash and reapply these changes?");
	}

	gint r = message_dialog (window,
	                         GTK_MESSAGE_QUESTION,
	                         _ ("You have uncommited changes in your current working tree"),
	                         secondary,
	                         _ ("Stash changes"));

	if (r != GTK_RESPONSE_ACCEPT)
	{
		ret = FALSE;
		goto cleanup;
	}

	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "log",
	                                   "--no-color",
	                                   "--abbrev-commit",
	                                   "--pretty=oneline",
	                                   "-n",
	                                   "1",
	                                   "HEAD",
	                                   NULL),
	                NULL);

	GitgRef *working = gitg_repository_get_current_working_ref (repository);

	if (working)
	{
		msg = g_strconcat (gitg_ref_get_shortname (working), ": ", buffer->str, NULL);
	}
	else
	{
		msg = g_strconcat (" (no branch): ", buffer->str, NULL);
	}

	// Create tree object of the current index
	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "write-tree",
	                                   NULL),
	                NULL);

	if (buffer->len == 0)
	{
		ret = FALSE;
		showerror = TRUE;

		goto cleanup;
	}

	tree = g_strndup (buffer->str, buffer->len);
	head = gitg_repository_parse_head (repository);

	gchar *idxmsg = g_strconcat ("index on ", msg, NULL);

	GInputStream *inp = g_memory_input_stream_new_from_data (idxmsg, -1, NULL);
	gitg_io_set_input (GITG_IO (shell), inp);
	g_object_unref (inp);

	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "commit-tree",
	                                   tree,
	                                   "-p",
	                                   head,
	                                   NULL),
	                NULL);

	g_free (idxmsg);
	gitg_io_set_input (GITG_IO (shell), NULL);

	if (buffer->len == 0)
	{
		ret = FALSE;
		showerror = TRUE;

		goto cleanup;
	}

	commit = g_strndup (buffer->str, buffer->len);

	// Working tree
	gchar *tmpname = NULL;
	gint fd = g_file_open_tmp ("gitg-temp-index-XXXXXX", &tmpname, NULL);

	if (fd == -1)
	{
		ret = FALSE;
		showerror = TRUE;

		goto cleanup;
	}

	GFile *customindex = g_file_new_for_path (tmpname);

	close (fd);

	GFile *git_dir = gitg_repository_get_git_dir (repository);
	GFile *index_ = g_file_get_child (git_dir, "index");

	gboolean copied = g_file_copy (index_, customindex, G_FILE_COPY_OVERWRITE, NULL, NULL, NULL, NULL);

	g_object_unref (index_);
	g_object_unref (git_dir);

	if (!copied)
	{
		g_object_unref (customindex);

		ret = FALSE;
		showerror = TRUE;
		goto cleanup;
	}

	tmpname = g_file_get_path (customindex);

	GitgCommand *cmd_read_tree = gitg_command_new (repository,
	                                                "read-tree",
	                                                "-m",
	                                                tree,
	                                                NULL);

	gitg_command_add_environment (cmd_read_tree,
	                              "GIT_INDEX_FILE",
	                              tmpname,
	                              NULL);

	GitgCommand *cmd_add = gitg_command_new (repository,
	                                          "add",
	                                          "-u",
	                                          NULL);

	gitg_command_add_environment (cmd_add,
	                              "GIT_INDEX_FILE",
	                              tmpname,
	                              NULL);

	GitgCommand *cmd_write_tree = gitg_command_new (repository,
	                                                 "write-tree",
	                                                 NULL);

	gitg_command_add_environment (cmd_write_tree,
	                              "GIT_INDEX_FILE",
	                              tmpname,
	                              NULL);

	g_free (tmpname);

	gboolean writestash;

	writestash = gitg_shell_run (shell, cmd_read_tree, NULL) &&
	             gitg_shell_run (shell, cmd_add, NULL) &&
	             gitg_shell_run (shell, cmd_write_tree, NULL);

	g_file_delete (customindex, NULL, NULL);
	g_object_unref (customindex);

	if (!writestash)
	{
		ret = FALSE;
		showerror = TRUE;

		goto cleanup;
	}

	gchar *stashtree = g_strndup (buffer->str, buffer->len);
	gchar *reason = g_strconcat ("gitg auto stash: ", msg, NULL);

	inp = g_memory_input_stream_new_from_data (reason, -1, NULL);
	gitg_io_set_input (GITG_IO (shell), inp);
	g_object_unref (inp);

	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "commit-tree",
	                                   stashtree,
	                                   "-p",
	                                   head,
	                                   "-p",
	                                   commit,
	                                   NULL),
	                NULL);

	gitg_io_set_input (GITG_IO (shell), NULL);

	g_free (stashtree);

	if (buffer->len == 0)
	{
		g_free (reason);

		ret = FALSE;
		showerror = TRUE;

		goto cleanup;
	}

	gchar *rref = g_strndup (buffer->str, buffer->len);

	if (ref)
	{
		*ref = g_strdup (rref);
	}

	git_dir = gitg_repository_get_git_dir (repository);
	gchar *git_path = g_file_get_path (git_dir);

	gchar *path = g_build_filename (git_path,
	                                "logs",
	                                "refs",
	                                "stash",
	                                NULL);

	g_object_unref (git_dir);
	g_free (git_path);

	GFile *reflog = g_file_new_for_path (path);
	GFileOutputStream *stream = g_file_create (reflog, G_FILE_CREATE_NONE, NULL, NULL);

	g_output_stream_close (G_OUTPUT_STREAM (stream), NULL, NULL);

	g_object_unref (stream);
	g_object_unref (reflog);

	g_free (path);

	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "update-ref",
	                                   "-m",
	                                   reason,
	                                   "refs/stash",
	                                   rref,
	                                   NULL),
	                NULL);

	g_free (rref);

	gitg_shell_run (shell,
	                gitg_command_new (repository,
	                                   "reset",
	                                   "--hard",
	                                   NULL),
	                NULL);

	ret = TRUE;

cleanup:
	g_string_free (buffer, TRUE);
	g_object_unref (shell);
	g_free (commit);
	g_free (tree);
	g_free (head);
	g_free (msg);

	if (showerror)
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to save current index state"),
		                NULL,
		                NULL);
	}

	return ret;
}

static gboolean
stash_changes (GitgWindow *window, gchar **ref, gboolean storeref)
{
	if (no_changes (gitg_window_get_repository (window)))
	{
		if (ref)
		{
			*ref = NULL;
		}

		return TRUE;
	}

	return stash_changes_real (window, ref, storeref);
}

static gboolean
checkout_local_branch_real (GitgWindow *window, GitgRef *ref)
{
	GitgRepository *repository = gitg_window_get_repository (window);

	return gitg_shell_run_sync (gitg_command_new (repository,
	                                               "checkout",
	                                               gitg_ref_get_shortname (ref),
	                                               NULL),
	                            NULL);
}

static gboolean
checkout_local_branch (GitgWindow *window,
                       GitgRef    *ref)
{
	if (!stash_changes (window, NULL, TRUE))
	{
		return FALSE;
	}

	gchar const *name = gitg_ref_get_shortname (ref);

	if (!checkout_local_branch_real (window, ref))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to checkout local branch <%s>"),
		                NULL,
		                NULL,
		                name);
		return FALSE;
	}
	else
	{
		gitg_repository_load (gitg_window_get_repository (window), 1, (gchar const **)&name, NULL);
		return TRUE;
	}
}

static gboolean
checkout_remote_branch (GitgWindow *window,
                        GitgRef    *ref)
{
	if (!stash_changes (window, NULL, TRUE))
	{
		return FALSE;
	}

	GitgRepository *repository = gitg_window_get_repository (window);
	gchar const *name = gitg_ref_get_shortname (ref);
	gchar const *local = gitg_ref_get_local_name (ref);
	gboolean ret;

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "checkout",
	                                             "--track",
	                                             "-b",
	                                             local,
	                                             name,
	                                             NULL),
	                          NULL))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to checkout remote branch <%s> to local branch <%s>"),
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

	return ret;
}

static gboolean
checkout_tag (GitgWindow *window,
              GitgRef    *ref)
{
	if (!stash_changes (window, NULL, TRUE))
	{
		return FALSE;
	}

	GitgRepository *repository = gitg_window_get_repository (window);
	gchar const *name = gitg_ref_get_shortname (ref);
	gboolean ret;

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "checkout",
	                                             "-b",
	                                             name,
	                                             name,
	                                             NULL),
	                         NULL))
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to checkout tag <%s> to local branch <%s>"),
		                NULL,
		                NULL,
		                name,
		                name);
		ret = FALSE;
	}
	else
	{
		gitg_repository_load (repository, 1, (gchar const **)&name, NULL);
		ret = TRUE;
	}

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
		case GITG_REF_TYPE_TAG:
			ret = checkout_tag (window, cp);
		break;
		default:
		break;
	}

	gitg_ref_free (cp);
	return ret;
}

typedef struct
{
	gboolean rebase;

	GitgRef *source;
	GitgRef *dest;

	gchar *stashcommit;
	GitgRef *head;
} RefInfo;

static RefInfo *
ref_info_new (GitgRef *source, GitgRef *dest)
{
	RefInfo *ret = g_slice_new0 (RefInfo);

	ret->source = gitg_ref_copy (source);
	ret->dest = gitg_ref_copy (dest);

	return ret;
}

static void
ref_info_free (RefInfo *info)
{
	gitg_ref_free (info->source);
	gitg_ref_free (info->dest);

	g_free (info->stashcommit);
	gitg_ref_free (info->head);

	g_slice_free (RefInfo, info);
}

static void
on_merge_rebase_result (GitgWindow   *window,
                        GitgProgress  progress,
                        gpointer      data)
{
	RefInfo *info = (RefInfo *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		gchar const *message;

		if (info->rebase)
		{
			message = _ ("Failed to rebase %s branch <%s> onto %s branch <%s>");
		}
		else
		{
			message = _ ("Failed to merge %s branch <%s> with %s branch <%s>");
		}

		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                message,
		                NULL,
		                NULL,
		                gitg_ref_get_ref_type (info->source) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
		                gitg_ref_get_shortname (info->source),
		                gitg_ref_get_ref_type (info->dest) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
		                gitg_ref_get_shortname (info->dest));
	}
	else if (progress == GITG_PROGRESS_SUCCESS)
	{
		GitgRepository *repository = gitg_window_get_repository (window);

		// Checkout head
		if (!checkout_local_branch_real (window, info->head))
		{
			gchar const *message = NULL;

			if (info->stashcommit)
			{
				gitg_shell_run_sync (gitg_command_new (repository,
				                                        "update-ref",
				                                        "-m",
				                                        "gitg autosave stash",
				                                        "refs/stash",
				                                        info->stashcommit,
				                                        NULL),
				                     NULL);

				message = _ ("The stashed changes have been stored to be reapplied manually");
			}

			message_dialog (window,
			                GTK_MESSAGE_ERROR,
			                _ ("Failed to checkout previously checked out branch"),
			                message,
			                NULL);
		}
		else if (info->stashcommit)
		{
			// Reapply stash
			if (!gitg_shell_run_sync (gitg_command_new (gitg_window_get_repository (window),
			                                             "stash",
			                                             "apply",
			                                             "--index",
			                                             info->stashcommit,
			                                             NULL),
			                          NULL))
			{
				gitg_shell_run_sync (gitg_command_new (repository,
				                                        "update-ref",
				                                        "-m",
				                                        "gitg autosave stash",
				                                        "refs/stash",
				                                        info->stashcommit,
				                                        NULL),
				                     NULL);

				message_dialog (window,
				                GTK_MESSAGE_ERROR,
				                _ ("Failed to reapply stash correctly"),
				                _ ("There might be unresolved conflicts in the working tree or index which you need to resolve manually"),
				                NULL);
			}
		}

		gitg_repository_reload (gitg_window_get_repository (window));
	}

	ref_info_free (info);
}

GitgShell *
gitg_branch_actions_merge (GitgWindow *window,
                           GitgRef    *source,
                           GitgRef    *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (dest != NULL, NULL);
	g_return_val_if_fail (source != NULL, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (dest) != GITG_REF_TYPE_REMOTE, NULL);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to merge %s branch <%s> onto %s branch <%s>?"),
	                                  gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                                  gitg_ref_get_shortname (source),
	                                  gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                                  gitg_ref_get_shortname (dest));

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Merge"),
	                    message,
	                    _ ("Merge")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return NULL;
	}

	g_free (message);
	GitgRepository *repository = gitg_window_get_repository (window);
	gchar *stashcommit = NULL;

	if (!stash_changes (window, &stashcommit, FALSE))
	{
		return NULL;
	}

	GitgRef *head = gitg_repository_get_current_working_ref (repository);

	// First checkout the correct branch on which to merge, e.g. dest
	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "checkout",
	                                             gitg_ref_get_shortname (dest),
	                                             NULL),
	                          NULL))
	{
		g_free (stashcommit);

		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to checkout local branch <%s>"),
		                _ ("The branch on which to merge could not be checked out"),
		                NULL,
		                gitg_ref_get_shortname (dest));
		return NULL;
	}

	message = g_strdup_printf (_ ("Merging %s branch <%s> onto %s branch <%s>"),
	                           gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                           gitg_ref_get_shortname (source),
	                           gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                           gitg_ref_get_shortname (dest));

	GitgShell *ret;
	RefInfo *info = ref_info_new (source, dest);
	info->stashcommit = stashcommit;
	info->head = gitg_ref_copy (head);
	info->rebase = FALSE;

	ret = run_progress (window,
	                    _ ("Merge"),
	                    message,
	                    on_merge_rebase_result,
	                    info,
	                    "merge",
	                    gitg_ref_get_shortname (source),
	                    NULL);

	g_free (message);

	return ret;
}

GitgShell *
gitg_branch_actions_rebase (GitgWindow *window,
                            GitgRef    *source,
                            GitgRef    *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (dest != NULL, NULL);
	g_return_val_if_fail (source != NULL, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (source) != GITG_REF_TYPE_REMOTE, NULL);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to rebase %s branch <%s> onto %s branch <%s>?"),
	                                  gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                                  gitg_ref_get_shortname (source),
	                                  gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                                  gitg_ref_get_shortname (dest));

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Rebase"),
	                    message,
	                    _ ("Rebase")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return NULL;
	}

	g_free (message);
	GitgRepository *repository = gitg_window_get_repository (window);
	gchar *stashcommit = NULL;

	if (!no_changes (repository))
	{
		// Check if destination is current HEAD
		gchar *head = gitg_repository_parse_head (repository);
		GitgHash hash;

		gitg_hash_sha1_to_hash (head, hash);
		g_free (head);

		if (gitg_hash_hash_equal (hash, gitg_ref_get_hash (dest)))
		{
			message_dialog (window,
			                GTK_MESSAGE_ERROR,
			                _ ("Unable to rebase"),
			                _ ("There are still uncommitted changes in your working tree and you are trying to rebase a branch onto the currently checked out branch. Either remove, stash or commit your changes first and try again"),
			                NULL);
			return NULL;
		}

		if (!stash_changes_real (window, &stashcommit, FALSE))
		{
			return NULL;
		}
	}

	gchar *merge_head = gitg_hash_hash_to_sha1_new (gitg_ref_get_hash (dest));

	message = g_strdup_printf (_ ("Rebasing %s branch <%s> onto %s branch <%s>"),
	                           gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                           gitg_ref_get_shortname (source),
	                           gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_BRANCH ? _ ("local") : _ ("remote"),
	                           gitg_ref_get_shortname (dest));

	GitgShell *ret;
	RefInfo *info = ref_info_new (source, dest);
	info->stashcommit = stashcommit;
	info->head = gitg_ref_copy (gitg_repository_get_current_working_ref (repository));
	info->rebase = TRUE;

	ret = run_progress (window,
	                    _ ("Rebase"),
	                    message,
	                    on_merge_rebase_result,
	                    info,
	                    "rebase",
	                    merge_head,
	                    gitg_ref_get_shortname (source),
	                    NULL);

	g_free (message);
	g_free (merge_head);

	return ret;
}

static void
on_push_result (GitgWindow   *window,
                GitgProgress  progress,
                gpointer      data)
{
	RefInfo *info = (RefInfo *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		message_dialog (window,
			            GTK_MESSAGE_ERROR,
			            _ ("Failed to push local branch <%s> to remote <%s>"),
			            _ ("This usually means that the remote branch could not be fast-forwarded. Try fetching the latest changes."),
			            NULL,
			            gitg_ref_get_shortname (info->source),
			            gitg_ref_get_shortname (info->dest));
	}
	else if (progress == GITG_PROGRESS_SUCCESS)
	{
		gitg_repository_reload (gitg_window_get_repository (window));
	}

	ref_info_free (info);
}

GitgShell *
gitg_branch_actions_push (GitgWindow *window,
                          GitgRef    *source,
                          GitgRef    *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (dest != NULL, NULL);
	g_return_val_if_fail (source != NULL, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (dest) == GITG_REF_TYPE_REMOTE, NULL);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to push <%s> to <%s>?"),
	                                  gitg_ref_get_shortname (source),
	                                  gitg_ref_get_shortname (dest));

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Push"),
	                    message,
	                    _ ("Push")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return NULL;
	}

	g_free (message);

	gchar const *prefix = gitg_ref_get_prefix (dest);
	gchar const *local = gitg_ref_get_local_name (dest);
	gchar const *name = gitg_ref_get_shortname (source);

	gchar *spec = g_strconcat (name, ":", local, NULL);
	message = g_strdup_printf (_ ("Pushing local branch <%s> to remote branch <%s>"),
	                           gitg_ref_get_shortname (source),
	                           gitg_ref_get_shortname (dest));

	GitgShell *ret;
	RefInfo *info = ref_info_new (source, dest);

	ret = run_progress (window,
	                    _ ("Push"),
	                    message,
	                    on_push_result,
	                    info,
	                    "push",
	                    prefix,
	                    spec,
	                    NULL);

	g_free (message);
	g_free (spec);

	return ret;
}

GitgShell *
gitg_branch_actions_push_remote (GitgWindow  *window,
                                 GitgRef     *source,
                                 gchar const *remote,
                                 gchar const *branch)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (remote != NULL, NULL);
	g_return_val_if_fail (source != NULL, NULL);
	g_return_val_if_fail (gitg_ref_get_ref_type (source) == GITG_REF_TYPE_BRANCH, NULL);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to push <%s> to remote <%s/%s>?"),
	                                  gitg_ref_get_shortname (source),
	                                  remote, branch);

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Push"),
	                    message,
	                    _ ("Push")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return NULL;
	}

	g_free (message);

	gchar const *name = gitg_ref_get_shortname (source);
	gchar *spec = g_strconcat (name, ":", branch, NULL);
	message = g_strdup_printf (_ ("Pushing local branch <%s> to remote branch <%s/%s>"),
	                           gitg_ref_get_shortname (source),
	                           remote, branch);

	GitgShell *ret;
	gchar *rr = g_strconcat ("refs/remotes/", remote, "/", branch, NULL);
	GitgRef *rmref = gitg_ref_new ("0000000000000000000000000000000000000000", rr);
	g_free (rr);

	RefInfo *info = ref_info_new (source, rmref);
	gitg_ref_free (rmref);

	ret = run_progress (window,
	                    _ ("Push"),
	                    message,
	                    on_push_result,
	                    info,
	                    "push",
	                    remote,
	                    spec,
	                    NULL);

	g_free (message);
	g_free (spec);

	return ret;
}

gboolean
gitg_branch_actions_apply_stash (GitgWindow *window,
                                 GitgRef    *stash,
                                 GitgRef    *branch)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	g_return_val_if_fail (gitg_ref_get_ref_type (stash) == GITG_REF_TYPE_STASH, FALSE);
	g_return_val_if_fail (gitg_ref_get_ref_type (branch) == GITG_REF_TYPE_BRANCH, FALSE);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to apply the stash item to local branch <%s>?"),
	                                  gitg_ref_get_shortname (branch));

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Apply stash"),
	                    message,
	                    _ ("Apply stash")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return FALSE;
	}

	GitgRepository *repository = gitg_window_get_repository (window);
	GitgRef *current = gitg_repository_get_current_working_ref (repository);

	if (!gitg_ref_equal (branch, current))
	{
		if (!stash_changes (window, NULL, TRUE))
		{
			return FALSE;
		}

		if (!checkout_local_branch_real (window, branch))
		{
			message_dialog (window,
				            GTK_MESSAGE_ERROR,
				            _ ("Failed to checkout local branch <%s>"),
				            NULL,
				            NULL,
				            gitg_ref_get_shortname (branch));
			return FALSE;
		}
	}

	gchar *sha1 = gitg_hash_hash_to_sha1_new (gitg_ref_get_hash (stash));
	gboolean ret;

	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "stash",
	                                             "apply",
	                                             "--index",
	                                             sha1,
	                                             NULL),
	                          NULL))
	{
		message = g_strdup_printf (_ ("The stash could not be applied to local branch <%s>"),
		                           gitg_ref_get_shortname (branch));
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to apply stash"),
		                message,
		                NULL);
		g_free (message);
		ret = FALSE;

		if (!gitg_ref_equal (current, branch)  && no_changes (repository))
		{
			checkout_local_branch_real (window, current);
		}
	}
	else
	{
		ret = TRUE;
		gitg_repository_reload (repository);
	}

	return ret;
}

gboolean
gitg_branch_actions_create (GitgWindow *window, gchar const *sha1, gchar const *name)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	g_return_val_if_fail (sha1 != NULL, FALSE);
	g_return_val_if_fail (name != NULL, FALSE);

	GitgRepository *repository;
	gboolean result = FALSE;

	repository = gitg_window_get_repository (window);

	result = gitg_shell_run_sync (gitg_command_new (repository,
	                                                 "branch",
	                                                 name,
	                                                 sha1,
	                                                 NULL),
	                              NULL);

	if (!result)
	{
		gchar const *message;

		message = _ ("The branch could not be successfully created");

		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to create a branch"),
		                message,
		                NULL);
		return FALSE;
	}
	else
	{
		gitg_repository_reload (repository);
		return TRUE;
	}
}

gboolean
gitg_branch_actions_tag (GitgWindow *window, gchar const *sha1, gchar const *name, gchar const *message, gboolean sign)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), FALSE);
	g_return_val_if_fail (sha1 != NULL, FALSE);
	g_return_val_if_fail (name != NULL, FALSE);

	GitgRepository *repository;
	gboolean result = FALSE;

	repository = gitg_window_get_repository (window);

	if (message != NULL && message[0] != '\0')
	{
		result = gitg_shell_run_sync (gitg_command_new (repository,
		                                                 "tag",
		                                                 "-m",
		                                                 message,
		                                                 sign ? "-s" : "-a",
		                                                 name,
		                                                 sha1,
		                                                 NULL),
		                              NULL);
	}
	else
	{
		result = gitg_shell_run_sync (gitg_command_new (repository,
		                                                 "tag",
		                                                 name,
		                                                 sha1,
		                                                 NULL),
		                              NULL);
	}

	if (!result)
	{
		gchar const *secondary;

		if (sign)
		{
			secondary = _ ("The tag object could not be successfully created. Please make sure you have a GPG key and the key is unlocked");
		}
		else
		{
			secondary = _ ("The tag object could not be successfully created");
		}

		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to create tag"),
		                secondary,
		                NULL);
		return FALSE;
	}
	else
	{
		gitg_repository_reload (repository);
		return TRUE;
	}
}

typedef struct
{
	GitgRevision *revision;
	GitgRef *dest;

	gchar *stashcommit;
	GitgRef *head;
} CherryPickInfo;

static CherryPickInfo *
cherry_pick_info_new (GitgRevision *revision, GitgRef *dest)
{
	CherryPickInfo *ret = g_slice_new0 (CherryPickInfo);

	ret->revision = gitg_revision_ref (revision);
	ret->dest = gitg_ref_copy (dest);

	return ret;
}

static void
cherry_pick_info_free (CherryPickInfo *info)
{
	gitg_revision_unref (info->revision);
	gitg_ref_free (info->dest);

	g_free (info->stashcommit);
	gitg_ref_free (info->head);

	g_slice_free (CherryPickInfo, info);
}

static void
on_cherry_pick_result (GitgWindow   *window,
                       GitgProgress  progress,
                       gpointer      data)
{
	CherryPickInfo *info = (CherryPickInfo *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to cherry-pick on <%s>"),
		                NULL,
		                NULL,
		                gitg_ref_get_shortname (info->dest));
	}
	else if (progress == GITG_PROGRESS_SUCCESS)
	{
		GitgRepository *repository = gitg_window_get_repository (window);

		// Checkout head
		if (!checkout_local_branch_real (window, info->head))
		{
			gchar const *message = NULL;

			if (info->stashcommit)
			{
				gitg_shell_run_sync (gitg_command_new (repository,
				                                        "update-ref",
				                                        "-m",
				                                        "gitg autosave stash",
				                                        "refs/stash",
				                                        info->stashcommit,
				                                        NULL),
				                     NULL);

				message = _ ("The stashed changes have been stored to be reapplied manually");
			}

			message_dialog (window,
				            GTK_MESSAGE_ERROR,
				            _ ("Failed to checkout previously checked out branch"),
				            message,
				            NULL);
		}
		else if (info->stashcommit)
		{
			// Reapply stash
			if (!gitg_shell_run_sync (gitg_command_new (gitg_window_get_repository (window),
			                                             "stash",
			                                             "apply",
			                                             "--index",
			                                             info->stashcommit,
			                                             NULL),
			                          NULL))
			{
				gitg_shell_run_sync (gitg_command_new (repository,
				                                        "update-ref",
				                                        "-m",
				                                        "gitg autosave stash",
				                                        "refs/stash",
				                                        info->stashcommit,
				                                        NULL),
				                     NULL);

				message_dialog (window,
				                GTK_MESSAGE_ERROR,
				                _ ("Failed to reapply stash correctly"),
				                _ ("There might be unresolved conflicts in the working tree or index which you need to resolve manually"),
				                NULL);
			}
		}

		gitg_repository_reload (gitg_window_get_repository (window));
	}

	cherry_pick_info_free (info);
}

GitgShell *
gitg_branch_actions_cherry_pick (GitgWindow   *window,
                                 GitgRevision *revision,
                                 GitgRef      *dest)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (revision != NULL, NULL);
	g_return_val_if_fail (dest != NULL, NULL);

	gchar *message = g_strdup_printf (_ ("Are you sure you want to cherry-pick that revision on <%s>?"),
	                                  gitg_ref_get_shortname (dest));

	if (message_dialog (window,
	                    GTK_MESSAGE_QUESTION,
	                    _ ("Cherry-pick"),
	                    message,
	                    _ ("Cherry-pick")) != GTK_RESPONSE_ACCEPT)
	{
		g_free (message);
		return NULL;
	}

	gchar *stashcommit;

	if (!stash_changes (window, &stashcommit, FALSE))
	{
		return NULL;
	}

	GitgRepository *repository = gitg_window_get_repository (window);
	GitgRef *head = gitg_repository_get_current_working_ref (repository);

	// First checkout the correct branch on which to cherry-pick
	if (!gitg_shell_run_sync (gitg_command_new (repository,
	                                             "checkout",
	                                             gitg_ref_get_shortname (dest),
	                                             NULL),
	                          NULL))
	{
		g_free (stashcommit);

		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to checkout local branch <%s>"),
		                _ ("The branch on which to cherry-pick could not be checked out"),
		                NULL,
		                gitg_ref_get_shortname (dest));

		return NULL;
	}

	message = g_strdup_printf (_ ("Cherry-picking on <%s>"),
	                           gitg_ref_get_shortname (dest));

	GitgShell *ret;

	CherryPickInfo *info = cherry_pick_info_new (revision, dest);

	info->stashcommit = stashcommit;
	info->head = gitg_ref_copy (head);

	gchar *sha1 = gitg_revision_get_sha1 (revision);

	ret = run_progress (window,
	                    _ ("Cherry-pick"),
	                    message,
	                    on_cherry_pick_result,
	                    info,
	                    "cherry-pick",
	                    sha1,
	                    NULL);

	g_free (message);
	g_free (sha1);

	return ret;
}

typedef struct
{
	GitgRevision *revision;
	gchar *destination;
	GOutputStream *stream;
} FormatPatchInfo;

static FormatPatchInfo *
format_patch_info_new (GitgRevision *revision, gchar const *destination, GOutputStream *stream)
{
	FormatPatchInfo *ret = g_slice_new0 (FormatPatchInfo);

	ret->revision = gitg_revision_ref (revision);
	ret->destination = g_strdup (destination);
	ret->stream = stream;

	return ret;
}

static void
format_patch_info_free (FormatPatchInfo *info)
{
	gitg_revision_unref (info->revision);
	g_free (info->destination);

	g_object_unref (info->stream);

	g_slice_free (FormatPatchInfo, info);
}

static void
on_format_patch_result (GitgWindow   *window,
                        GitgProgress  progress,
                        gpointer      data)
{
	FormatPatchInfo *info = (FormatPatchInfo *)data;

	if (progress == GITG_PROGRESS_ERROR)
	{
		message_dialog (window,
		                GTK_MESSAGE_ERROR,
		                _ ("Failed to generate format-patch"),
		                NULL,
		                NULL,
		                NULL);
	}

	format_patch_info_free (info);
}

static void
on_format_patch_update (GitgShell        *shell,
                        gchar           **lines,
                        FormatPatchInfo  *info)
{
	while (lines && *lines)
	{
		g_output_stream_write_all (info->stream, *lines, strlen (*lines), NULL, NULL, NULL);
		g_output_stream_write_all (info->stream, "\n", 1, NULL, NULL, NULL);
		++lines;
	}
}

GitgShell *
gitg_branch_actions_format_patch (GitgWindow   *window,
                                  GitgRevision *revision,
                                  gchar const  *destination)
{
	g_return_val_if_fail (GITG_IS_WINDOW (window), NULL);
	g_return_val_if_fail (revision != NULL, NULL);
	g_return_val_if_fail (destination != NULL, NULL);

	GitgShell *ret;

	GFile *file = g_file_new_for_uri (destination);
	GFileOutputStream *stream = g_file_replace (file,
	                                            NULL,
	                                            FALSE,
	                                            G_FILE_CREATE_REPLACE_DESTINATION,
	                                            NULL,
	                                            NULL);
	g_object_unref (file);

	if (!stream)
	{
		return NULL;
	}

	gchar *sha1 = gitg_revision_get_sha1 (revision);
	gchar *message;

	message = g_strdup_printf (_ ("Generating format-patch for <%s>"),
	                           gitg_revision_get_subject (revision));

	FormatPatchInfo *info = format_patch_info_new (revision,
	                                               destination,
	                                               G_OUTPUT_STREAM (stream));

	ret = run_progress (window,
	                    _ ("Format patch"),
	                    message,
	                    on_format_patch_result,
	                    info,
	                    "format-patch",
	                    "-1",
	                    "--stdout",
	                    sha1,
	                    NULL);

	if (ret)
	{
		g_signal_connect (ret, "update", G_CALLBACK (on_format_patch_update), info);
	}

	g_free (sha1);
	g_free (message);

	return ret;
}
