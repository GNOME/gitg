#include <glib/gi18n.h>

#include <stdlib.h>

#include "gitg-repository-dialog.h"
#include "gitg-utils.h"
#include "gitg-config.h"
#include "gitg-spinner.h"

#define GITG_REPOSITORY_DIALOG_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REPOSITORY_DIALOG, GitgRepositoryDialogPrivate))

static GitgRepositoryDialog *repository_dialog = NULL;

enum
{
	COLUMN_NAME,
	COLUMN_URL,
	COLUMN_FETCH
};

struct _GitgRepositoryDialogPrivate
{
	GitgRepository *repository;
	GitgConfig *config;
	
	GtkEntry *entry_repository_user_name;
	GtkEntry *entry_repository_user_email;
	
	GtkTreeView *tree_view_remotes;
	GtkListStore *list_store_remotes;
	
	GtkButton *button_remove_remote;
	GtkButton *button_fetch_remote;
	GtkImage *image_fetch_remote;
	
	GList *fetchers;
	gboolean show_fetch;
};

G_DEFINE_TYPE (GitgRepositoryDialog, gitg_repository_dialog, GTK_TYPE_DIALOG)

typedef struct
{
	GitgRepositoryDialog *dialog;
	GitgRunner *runner;
	GtkTreeRowReference *reference;
	GitgSpinner *spinner;
} FetchInfo;

static void
fetch_cleanup (FetchInfo *info)
{
	if (info->spinner)
	{
		g_object_unref (info->spinner);
	}
	
	info->dialog->priv->fetchers = g_list_remove (info->dialog->priv->fetchers, info);
	
	if (gtk_tree_row_reference_valid (info->reference))
	{
		GtkTreeIter iter;
		GtkTreePath *path = gtk_tree_row_reference_get_path (info->reference);
		
		gtk_tree_model_get_iter (GTK_TREE_MODEL (info->dialog->priv->list_store_remotes),
		                         &iter,
		                         path);

		gtk_list_store_set (info->dialog->priv->list_store_remotes,
		                    &iter,
		                    COLUMN_FETCH, NULL,
		                    -1);

		gtk_tree_path_free (path);
	}
	
	gtk_tree_row_reference_free (info->reference);
	g_object_unref (info->runner);
	
	g_slice_free (FetchInfo, info);	
}

static void
gitg_repository_dialog_finalize (GObject *object)
{
	GitgRepositoryDialog *dialog = GITG_REPOSITORY_DIALOG (object);
	
	if (dialog->priv->repository)
	{
		g_object_unref (dialog->priv->repository);
	}
	
	if (dialog->priv->config)
	{
		g_object_unref (dialog->priv->config);
	}
	
	GList *copy = g_list_copy (dialog->priv->fetchers);
	GList *item;
	
	for (item = copy; item; item = g_list_next (item))
	{
		gitg_runner_cancel (((FetchInfo *)item->data)->runner);
	}
	
	g_list_free (copy);
	g_list_foreach (dialog->priv->fetchers, (GFunc)fetch_cleanup, NULL);
	
	G_OBJECT_CLASS (gitg_repository_dialog_parent_class)->finalize (object);
}

static void
gitg_repository_dialog_class_init (GitgRepositoryDialogClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	
	object_class->finalize = gitg_repository_dialog_finalize;

	g_type_class_add_private (object_class, sizeof(GitgRepositoryDialogPrivate));
}

static void
gitg_repository_dialog_init (GitgRepositoryDialog *self)
{
	self->priv = GITG_REPOSITORY_DIALOG_GET_PRIVATE (self);
}

static void
on_response(GtkWidget *dialog, gint response, gpointer data)
{
	gtk_widget_destroy(dialog);
}

static void
update_fetch (GitgRepositoryDialog *dialog)
{
	GtkTreeSelection *selection = gtk_tree_view_get_selection (dialog->priv->tree_view_remotes);
	GList *rows;
	GtkTreeModel *model;
	
	rows = gtk_tree_selection_get_selected_rows (selection, &model);
	
	GList *item;
	gboolean show_fetch = FALSE;

	for (item = rows; item; item = g_list_next (item))
	{
		GtkTreePath *path = (GtkTreePath *)item->data;
		GtkTreeIter iter;
		GdkPixbuf *fetch;
		
		gtk_tree_model_get_iter (model, &iter, path);
		gtk_tree_model_get (model, &iter, COLUMN_FETCH, &fetch, -1);
		
		if (!fetch)
		{
			show_fetch = TRUE;
		}
		else
		{
			g_object_unref (fetch);
		}
	}
	
	if (!rows)
	{
		show_fetch = TRUE;
	}

	if (show_fetch)
	{
		gtk_image_set_from_stock (dialog->priv->image_fetch_remote, GTK_STOCK_REFRESH, GTK_ICON_SIZE_BUTTON);
		gtk_button_set_label (dialog->priv->button_fetch_remote, _("Fetch"));
	}
	else
	{
		gtk_image_set_from_stock (dialog->priv->image_fetch_remote, GTK_STOCK_CANCEL, GTK_ICON_SIZE_BUTTON);
		gtk_button_set_label (dialog->priv->button_fetch_remote, _("Cancel"));
	}

	dialog->priv->show_fetch = show_fetch;
	
	g_list_foreach (rows, (GFunc)gtk_tree_path_free, NULL);
	g_list_free (rows);
}

static void
update_sensitivity (GitgRepositoryDialog *dialog)
{
	GtkTreeSelection *selection = gtk_tree_view_get_selection (dialog->priv->tree_view_remotes);
	GList *rows;
	GtkTreeModel *model;
	
	rows = gtk_tree_selection_get_selected_rows (selection, &model);

	gtk_widget_set_sensitive (GTK_WIDGET (dialog->priv->button_remove_remote), rows != NULL);
	gtk_widget_set_sensitive (GTK_WIDGET (dialog->priv->button_fetch_remote), rows != NULL);
	
	update_fetch (dialog);
	
	g_list_foreach (rows, (GFunc)gtk_tree_path_free, NULL);
	g_list_free (rows);
}

static void
add_remote (GitgRepositoryDialog *dialog, gchar const *name, gchar const *url, GtkTreeIter *iter)
{
	GtkTreeIter it;
	
	gtk_list_store_append (dialog->priv->list_store_remotes, iter ? iter : &it);
	gtk_list_store_set (dialog->priv->list_store_remotes, 
	                    iter ? iter : &it,
	                    COLUMN_NAME, name,
	                    COLUMN_URL, url,
	                    COLUMN_FETCH, NULL,
	                    -1);
}

static void
on_spinner_frame (GitgSpinner *spinner, GdkPixbuf *pixbuf, FetchInfo *info)
{
	GtkTreeIter iter;
	GtkTreePath *path = gtk_tree_row_reference_get_path (info->reference);
	
	gtk_tree_model_get_iter (GTK_TREE_MODEL (info->dialog->priv->list_store_remotes),
	                         &iter,
	                         path);

	gtk_list_store_set (info->dialog->priv->list_store_remotes,
	                    &iter,
	                    COLUMN_FETCH, pixbuf,
	                    -1);

	gtk_tree_path_free (path);
}

static void
on_fetch_begin_loading (GitgRunner *runner, FetchInfo *info)
{
	info->spinner = gitg_spinner_new (GTK_ICON_SIZE_MENU);
	gitg_spinner_set_screen (info->spinner, gtk_widget_get_screen (GTK_WIDGET (info->dialog)));
	
	g_signal_connect (info->spinner, "frame", G_CALLBACK (on_spinner_frame), info);
	gitg_spinner_start (info->spinner);
	
	update_fetch (info->dialog);
}

static void
on_fetch_end_loading (GitgRunner *runner, gboolean cancelled, FetchInfo *info)
{
	if (cancelled || !gtk_tree_row_reference_valid (info->reference))
	{
		fetch_cleanup (info);
		return;
	}

	GitgRepositoryDialog *dialog = info->dialog;

	fetch_cleanup (info);

	update_fetch (dialog);
	gitg_repository_reload (dialog->priv->repository);
}

static void
fetch_remote (GitgRepositoryDialog *dialog, GtkTreeIter *iter)
{
	GitgRunner *runner = gitg_runner_new (1000);
	FetchInfo *info = g_slice_new0 (FetchInfo);
	GtkTreeModel *model = GTK_TREE_MODEL (dialog->priv->list_store_remotes);
	
	GtkTreePath *path = gtk_tree_model_get_path (model, iter);
	
	info->dialog = dialog;
	info->reference = gtk_tree_row_reference_new (model, path);
	info->runner = runner;

	gtk_tree_path_free (path); 
	
	g_signal_connect (runner, 
	                  "begin-loading", 
	                  G_CALLBACK (on_fetch_begin_loading),
	                  info);

	g_signal_connect (runner,
	                  "end-loading",
	                  G_CALLBACK (on_fetch_end_loading),
	                  info);

	dialog->priv->fetchers = g_list_prepend (dialog->priv->fetchers, info);
	
	gchar *name;
	gtk_tree_model_get (model, iter, COLUMN_NAME, &name, -1);
	
	gitg_repository_run_commandv (dialog->priv->repository,
	                              runner,
	                              NULL,
	                              "fetch",
	                              name,
	                              NULL);

	g_free (name);
}

static void
on_selection_changed (GtkTreeSelection *selection, GitgRepositoryDialog *dialog)
{
	update_sensitivity (dialog);
}

static void
init_remotes(GitgRepositoryDialog *dialog)
{
	gchar *ret = gitg_config_get_value_regex (dialog->priv->config, "remote\\..*\\.url");
	
	if (!ret)
	{
		update_sensitivity (dialog);
		return;
	}
	
	gchar **lines = g_strsplit(ret, "\n", -1);
	gchar **ptr = lines;
	
	GRegex *regex = g_regex_new ("remote\\.(.+?)\\.url\\s+(.*)", 0, 0, NULL);
	
	while (*ptr)
	{
		GMatchInfo *info = NULL;
		
		if (g_regex_match (regex, *ptr, 0, &info))
		{
			gchar *name = g_match_info_fetch (info, 1);
			gchar *url = g_match_info_fetch (info, 2);
			
			add_remote (dialog, name, url, NULL);
			
			g_free (name);
			g_free (url);
		}
		
		g_match_info_free (info);
		++ptr;
	}
	
	g_regex_unref (regex);
	g_strfreev (lines);
	g_free (ret);
	
	GtkTreeSelection *selection;
	selection = gtk_tree_view_get_selection (dialog->priv->tree_view_remotes);
	
	gtk_tree_selection_set_mode (selection, GTK_SELECTION_MULTIPLE);
	g_signal_connect (selection, "changed", G_CALLBACK (on_selection_changed), dialog);
	
	update_sensitivity (dialog);
}

static void
init_properties(GitgRepositoryDialog *dialog)
{
	gchar *val;
	
	val = gitg_config_get_value (dialog->priv->config, "user.name");
	gtk_entry_set_text (dialog->priv->entry_repository_user_name, val ? val : "");
	g_free (val);
	
	val = gitg_config_get_value (dialog->priv->config, "user.email");
	gtk_entry_set_text (dialog->priv->entry_repository_user_email, val ? val : "");
	g_free (val);
	
	init_remotes(dialog);
}

static void
fetch_data_cb (GtkTreeViewColumn    *column,
               GtkCellRenderer      *cell,
               GtkTreeModel         *model,
               GtkTreeIter          *iter,
               GitgRepositoryDialog *dialog)
{
	GdkPixbuf *fetch;
	
	gtk_tree_model_get (model, iter, COLUMN_FETCH, &fetch, -1);
	
	if (fetch)
	{
		g_object_set (cell, "pixbuf", fetch, NULL);
		g_object_unref (fetch);
	}
	else
	{
		g_object_set (cell, 
		              "stock-id", GTK_STOCK_NETWORK, 
		              NULL);
	}
}

static void
create_repository_dialog (GitgWindow *window)
{
	GitgRepository *repository = gitg_window_get_repository (window);
	
	if (!repository)
	{
		return;
	}
	
	GtkBuilder *b = gitg_utils_new_builder("gitg-repository.ui");
	
	repository_dialog = GITG_REPOSITORY_DIALOG(gtk_builder_get_object(b, "dialog_repository"));
	g_object_add_weak_pointer(G_OBJECT(repository_dialog), (gpointer *)&repository_dialog);
	
	repository_dialog->priv->repository = g_object_ref (repository);
	repository_dialog->priv->config = gitg_config_new (repository);

	repository_dialog->priv->entry_repository_user_name = GTK_ENTRY(gtk_builder_get_object(b, "entry_repository_user_name"));
	repository_dialog->priv->entry_repository_user_email = GTK_ENTRY(gtk_builder_get_object(b, "entry_repository_user_email"));
	
	repository_dialog->priv->tree_view_remotes = GTK_TREE_VIEW(gtk_builder_get_object(b, "tree_view_remotes"));
	repository_dialog->priv->list_store_remotes = GTK_LIST_STORE(gtk_builder_get_object(b, "list_store_remotes"));
	
	repository_dialog->priv->button_remove_remote = GTK_BUTTON(gtk_builder_get_object(b, "button_remove_remote"));
	repository_dialog->priv->button_fetch_remote = GTK_BUTTON(gtk_builder_get_object(b, "button_fetch_remote"));
	repository_dialog->priv->image_fetch_remote = GTK_IMAGE(gtk_builder_get_object(b, "image_fetch_remote"));

	GObject *renderer = gtk_builder_get_object(b, "tree_view_remotes_renderer_icon");
	GObject *column = gtk_builder_get_object(b, "tree_view_remotes_column_icon");
	
	gtk_tree_view_column_set_cell_data_func (GTK_TREE_VIEW_COLUMN (column),
	                                         GTK_CELL_RENDERER (renderer),
	                                         (GtkTreeCellDataFunc)fetch_data_cb,
	                                         repository_dialog,
	                                         NULL);

	gtk_builder_connect_signals(b, repository_dialog);
	g_object_unref (b);
	
	gchar *basename = g_path_get_basename(gitg_repository_get_path(repository));
	gchar *title = g_strdup_printf("%s - %s", _("Properties"), basename);

	gtk_window_set_title(GTK_WINDOW(repository_dialog), title);
	g_free (title);
	g_free (basename);
	
	g_signal_connect(repository_dialog, "response", G_CALLBACK(on_response), NULL);
	
	init_properties(repository_dialog);
}

GitgRepositoryDialog *
gitg_repository_dialog_present(GitgWindow *window)
{
	if (!repository_dialog)
		create_repository_dialog(window);

	gtk_window_set_transient_for(GTK_WINDOW(repository_dialog), GTK_WINDOW (window));
	gtk_window_present(GTK_WINDOW(repository_dialog));

	return repository_dialog;
}

void
gitg_repository_dialog_close ()
{
	if (repository_dialog)
	{
		gtk_widget_destroy (GTK_WIDGET (repository_dialog));
	}
}

static void
fetch_remote_cancel (GitgRepositoryDialog *dialog, GtkTreeIter *iter)
{
	GList *item;
	GtkTreePath *orig;
	GtkTreeModel *model = GTK_TREE_MODEL (dialog->priv->list_store_remotes);
	
	orig = gtk_tree_model_get_path (model, iter);
	
	for (item = dialog->priv->fetchers; item; item = g_list_next (item))
	{
		FetchInfo *info = (FetchInfo *)item->data;
		GtkTreePath *ref = gtk_tree_row_reference_get_path (info->reference);
		gboolean equal = gtk_tree_path_compare (orig, ref) == 0;
		
		gtk_tree_path_free (ref);
		
		if (equal)
		{
			gitg_runner_cancel (info->runner);
			break;
		}
	}
	
	gtk_tree_path_free (orig);
}

void
on_button_fetch_remote_clicked (GtkButton *button, GitgRepositoryDialog *dialog)
{
	GtkTreeSelection *selection;
	GtkTreeModel *model;

	selection = gtk_tree_view_get_selection (dialog->priv->tree_view_remotes);

	GList *rows = gtk_tree_selection_get_selected_rows (selection, &model);
	GList *item;
	
	for (item = rows; item; item = g_list_next (item))
	{
		GtkTreePath *path = (GtkTreePath *)item->data;
		GtkTreeIter iter;
		GdkPixbuf *fetch;
		
		gtk_tree_model_get_iter (model, &iter, path);
		gtk_tree_model_get (model, &iter, COLUMN_FETCH, &fetch, -1);
		
		if (!fetch && dialog->priv->show_fetch)
		{
			fetch_remote (dialog, &iter);
		}
		else if (fetch && !dialog->priv->show_fetch)
		{
			fetch_remote_cancel (dialog, &iter);
		}
		
		if (fetch)
		{
			g_object_unref (fetch);
		}
		
		gtk_tree_path_free (path);
	}
	
	if (rows)
	{
		update_fetch (dialog);
	}
	
	g_list_free (rows);
}

static gboolean
remove_remote (GitgRepositoryDialog *dialog, gchar const *name)
{
	return gitg_repository_commandv (dialog->priv->repository,
	                                 NULL,
	                                 "remote",
	                                 "rm",
	                                 name,
	                                 NULL);
}

void
on_button_remove_remote_clicked (GtkButton *button, GitgRepositoryDialog *dialog)
{
	GtkTreeSelection *selection;
	GtkTreeModel *model;
		
	selection = gtk_tree_view_get_selection (dialog->priv->tree_view_remotes);

	GList *rows = gtk_tree_selection_get_selected_rows (selection, &model);
	GList *refs = NULL;
	GList *item;
	
	for (item = rows; item; item = g_list_next (item))
	{
		GtkTreeRowReference *ref;
		GtkTreePath *path = (GtkTreePath *)item->data;
		
		ref = gtk_tree_row_reference_new (model, path);
		refs = g_list_prepend (refs, ref);
		
		gtk_tree_path_free (path);
	}
	
	refs = g_list_reverse (refs);
	g_list_free (rows);
	
	for (item = refs; item; item = g_list_next (item))
	{
		GtkTreeRowReference *ref = (GtkTreeRowReference *)item->data;
		GtkTreePath *path = gtk_tree_row_reference_get_path (ref);
		GtkTreeIter iter;
		gchar *name;
		
		gtk_tree_model_get_iter (model, &iter, path);		
		gtk_tree_model_get (model, &iter, COLUMN_NAME, &name, -1);
		
		gboolean ret = remove_remote (dialog, name);

		if (ret)
		{
			gtk_list_store_remove (dialog->priv->list_store_remotes, &iter);
		}
		
		gtk_tree_row_reference_free (ref);
		gtk_tree_path_free (path);
	}
	
	g_list_free (refs);
}

void
on_button_add_remote_clicked (GtkButton *button, GitgRepositoryDialog *dialog)
{
	GtkTreeModel *model = GTK_TREE_MODEL (dialog->priv->list_store_remotes);
	GtkTreeIter iter;
	
	gint num = 0;
	
	if (gtk_tree_model_get_iter_first (model, &iter))
	{
		do
		{
			gchar *name;
			gtk_tree_model_get (model, &iter, COLUMN_NAME, &name, -1);
			
			if (g_str_has_prefix (name, "remote"))
			{
				gint n = atoi (name + 6);
				
				if (n > num)
				{
					num = n;
				}
			}
			
			g_free (name);
		} while (gtk_tree_model_iter_next (model, &iter));
	}
	
	gchar *name = g_strdup_printf ("remote%d", num + 1);
	gchar const url[] = "git://example.com/repository.git";

	if (gitg_repository_commandv (dialog->priv->repository, NULL, "remote", "add", name, url, NULL))
	{
		GtkTreeIter iter;
		GtkTreePath *path;

		add_remote (dialog, name, url, &iter);
		
		path = gtk_tree_model_get_path (GTK_TREE_MODEL (dialog->priv->list_store_remotes), &iter);
		
		gtk_tree_view_set_cursor_on_cell (dialog->priv->tree_view_remotes,
		                                  path,
		                                  gtk_tree_view_get_column (dialog->priv->tree_view_remotes, 0),
		                                  NULL,
		                                  TRUE);

		gtk_tree_path_free (path);
	}
	
	g_free (name);
}

gboolean
on_entry_repository_user_name_focus_out_event (GtkEntry *entry, GdkEventFocus *focus, GitgRepositoryDialog *dialog)
{
	gchar const *text;
	
	text = gtk_entry_get_text (entry);
	gitg_config_set_value (dialog->priv->config, "user.name", *text ? text : NULL);

	return FALSE;
}

gboolean
on_entry_repository_user_email_focus_out_event (GtkEntry *entry, GdkEventFocus *focus, GitgRepositoryDialog *dialog)
{
	gchar const *text;
	
	text = gtk_entry_get_text (entry);
	gitg_config_set_value (dialog->priv->config, "user.email", *text ? text : NULL);

	return FALSE;
}

void
on_remote_name_edited(GtkCellRendererText *renderer, gchar *path, gchar *new_text, GitgRepositoryDialog *dialog)
{
	if (!*new_text)
	{
		return;
	}
	
	GtkTreePath *tp = gtk_tree_path_new_from_string (path);
	GtkTreeIter iter;

	gtk_tree_model_get_iter (GTK_TREE_MODEL (dialog->priv->list_store_remotes),
		                     &iter,
		                     tp);

	gchar *oldname;
	gchar *url;
	
	gtk_tree_model_get (GTK_TREE_MODEL (dialog->priv->list_store_remotes), 
	                    &iter,
	                    COLUMN_NAME, &oldname, 
	                    COLUMN_URL, &url,
	                    -1);
	
	if (gitg_repository_commandv (dialog->priv->repository, NULL, "remote", "add", new_text, url, NULL))
	{
		remove_remote (dialog, oldname);

		gtk_list_store_set (dialog->priv->list_store_remotes,
		                    &iter,
		                    COLUMN_NAME, new_text,
		                    -1);

		fetch_remote (dialog, &iter);
	}
	
	g_free (oldname);
	g_free (url);

	gtk_tree_path_free (tp);
}

void
on_remote_url_edited(GtkCellRendererText *renderer, gchar *path, gchar *new_text, GitgRepositoryDialog *dialog)
{
	if (!*new_text)
	{
		return;
	}
	
	GtkTreePath *tp = gtk_tree_path_new_from_string (path);
	GtkTreeIter iter;
	
	gtk_tree_model_get_iter (GTK_TREE_MODEL (dialog->priv->list_store_remotes),
	                         &iter,
	                         tp);
	
	gchar *name;
	gchar *url;
	
	gtk_tree_model_get (GTK_TREE_MODEL (dialog->priv->list_store_remotes),
	                    &iter,
	                    COLUMN_NAME, &name,
	                    COLUMN_URL, &url,
	                    -1);

	if (g_strcmp0 (url, new_text) == 0)
	{
		g_free (name);
		g_free (url);

		gtk_tree_path_free (tp);

		return;		
	}

	g_free (url);

	gchar *key = g_strconcat ("remote.", name, ".url", NULL);
	g_free (name);
	
	if (gitg_config_set_value (dialog->priv->config, key, new_text))
	{
		gtk_list_store_set (dialog->priv->list_store_remotes,
		                    &iter,
		                    COLUMN_URL, new_text,
		                    -1);

		fetch_remote (dialog, &iter);
	}
	
	g_free (key);	
	gtk_tree_path_free (tp);
}
