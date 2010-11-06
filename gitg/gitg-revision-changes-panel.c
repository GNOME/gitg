#include "gitg-revision-changes-panel.h"

#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <gtksourceview/gtksourcestyleschememanager.h>
#include <string.h>
#include <libgitg/gitg-repository.h>
#include <libgitg/gitg-revision.h>
#include <libgitg/gitg-shell.h>
#include <libgitg/gitg-hash.h>
#include "gitg-diff-view.h"
#include "gitg-utils.h"
#include "gitg-preferences.h"
#include <glib/gi18n.h>


#include "gitg-revision-panel.h"
#include "gitg-activatable.h"

#define GITG_REVISION_CHANGES_PANEL_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_CHANGES_PANEL, GitgRevisionChangesPanelPrivate))

struct _GitgRevisionChangesPanelPrivate
{
	GtkWidget *panel_widget;
	GtkBuilder *builder;

	GtkSourceView *diff;
	GtkTreeView *diff_files;
	GtkListStore *list_store_diff_files;

	GitgShell *diff_shell;
	GitgShell *diff_files_shell;

	GitgRepository *repository;
	GitgRevision *revision;
	GSList *cached_headers;

	gchar *selection;
};

typedef enum
{
	DIFF_FILE_STATUS_NONE,
	DIFF_FILE_STATUS_NEW,
	DIFF_FILE_STATUS_MODIFIED,
	DIFF_FILE_STATUS_DELETED
} DiffFileStatus;

typedef struct
{
	GitgDiffIter iter;
} CachedHeader;

typedef struct
{
	gint refcount;

	gchar index_from[GITG_HASH_SHA_SIZE + 1];
	gchar index_to[GITG_HASH_SHA_SIZE + 1];
	DiffFileStatus status;
	gchar *filename;

	gboolean visible;
	GitgDiffIter iter;
} DiffFile;

static void gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface);
static void gitg_activatable_iface_init (GitgActivatableInterface *iface);

static void on_header_added (GitgDiffView *view, GitgDiffIter *iter, GitgRevisionChangesPanel *self);
static void on_diff_files_selection_changed (GtkTreeSelection *selection, GitgRevisionChangesPanel *self);

G_DEFINE_TYPE_EXTENDED (GitgRevisionChangesPanel,
                        gitg_revision_changes_panel,
                        G_TYPE_OBJECT,
                        0,
                        G_IMPLEMENT_INTERFACE (GITG_TYPE_REVISION_PANEL,
                                               gitg_revision_panel_iface_init);
                        G_IMPLEMENT_INTERFACE (GITG_TYPE_ACTIVATABLE,
                                               gitg_activatable_iface_init));

static void set_revision (GitgRevisionChangesPanel *panel,
                          GitgRepository           *repository,
                          GitgRevision             *revision);

static DiffFile *
diff_file_new (gchar const *from,
               gchar       *to,
               gchar const *status,
               gchar const *filename)
{
	DiffFile *f = g_slice_new (DiffFile);

	strncpy (f->index_from, from, GITG_HASH_SHA_SIZE);
	strncpy (f->index_to, to, GITG_HASH_SHA_SIZE);

	f->index_from[GITG_HASH_SHA_SIZE] = '\0';
	f->index_to[GITG_HASH_SHA_SIZE] = '\0';
	f->visible = FALSE;

	DiffFileStatus st;

	switch (*status)
	{
		case 'A':
			st = DIFF_FILE_STATUS_NEW;
		break;
		case 'D':
			st = DIFF_FILE_STATUS_DELETED;
		break;
		default:
			st = DIFF_FILE_STATUS_MODIFIED;
		break;
	}

	f->status = st;
	f->filename = g_strdup (filename);
	f->refcount = 1;

	return f;
}

static DiffFile *
diff_file_copy (DiffFile *f)
{
	g_atomic_int_inc (&f->refcount);
	return f;
}

static void
diff_file_unref (DiffFile *f)
{
	if (!g_atomic_int_dec_and_test (&f->refcount))
	{
		return;
	}

	g_free (f->filename);
	g_slice_free (DiffFile, f);
}

static GType
diff_file_get_type ()
{
	static GType gtype = 0;

	if (!G_UNLIKELY(gtype))
	{
		gtype = g_boxed_type_register_static ("DiffFile",
		                                      (GBoxedCopyFunc)diff_file_copy,
		                                      (GBoxedFreeFunc)diff_file_unref);
	}

	return gtype;
}

static void
revision_files_icon (GtkTreeViewColumn         *column,
                     GtkCellRenderer           *renderer,
                     GtkTreeModel              *model,
                     GtkTreeIter               *iter,
                     GitgRevisionChangesPanel  *self)
{
	DiffFile *f;
	gtk_tree_model_get (model, iter, 0, &f, -1);

	gchar const *id = NULL;

	switch (f->status)
	{
		case DIFF_FILE_STATUS_NEW:
			id = GTK_STOCK_NEW;
		break;
		case DIFF_FILE_STATUS_MODIFIED:
			id = GTK_STOCK_EDIT;
		break;
		case DIFF_FILE_STATUS_DELETED:
			id = GTK_STOCK_DELETE;
		break;
		default:
		break;
	}

	g_object_set (G_OBJECT(renderer), "stock-id", id, NULL);
	diff_file_unref (f);
}

static void
revision_files_name (GtkTreeViewColumn        *column,
                     GtkCellRenderer          *renderer,
                     GtkTreeModel             *model,
                     GtkTreeIter              *iter,
                     GitgRevisionChangesPanel *self)
{
	DiffFile *f;
	gtk_tree_model_get (model, iter, 0, &f, -1);

	g_object_set (G_OBJECT(renderer), "text", f->filename, NULL);

	diff_file_unref (f);
}

static gboolean
diff_file_visible (GtkTreeModel *model,
                   GtkTreeIter  *iter,
                   gpointer      data)
{
	DiffFile *f;
	gtk_tree_model_get (model, iter, 0, &f, -1);

	if (!f)
	{
		return FALSE;
	}

	gboolean ret = f->visible;
	diff_file_unref (f);

	return ret;
}

static gboolean
on_diff_files_button_press (GtkTreeView              *treeview,
                            GdkEventButton           *event,
                            GitgRevisionChangesPanel *view)
{
	if (event->button != 1)
	{
		return FALSE;
	}

	if (event->window != gtk_tree_view_get_bin_window (treeview))
	{
		return FALSE;
	}

	GtkTreePath *path;

	if (!gtk_tree_view_get_path_at_pos (treeview,
	                                    event->x,
	                                    event->y,
	                                    &path,
	                                    NULL,
	                                    NULL,
	                                    NULL))
	{
		return FALSE;
	}

	GtkTreeSelection *selection = gtk_tree_view_get_selection (treeview);
	gboolean ret = FALSE;

	if (gtk_tree_selection_path_is_selected (selection, path) &&
	    gtk_tree_selection_count_selected_rows (selection) == 1)
	{
		/* deselect */
		gtk_tree_selection_unselect_path (selection, path);
		ret = TRUE;
	}

	gtk_tree_path_free (path);
	return ret;
}

static void
gitg_revision_panel_update_impl (GitgRevisionPanel *panel,
                                 GitgRepository    *repository,
                                 GitgRevision      *revision)
{
	GitgRevisionChangesPanel *changes_panel;

	changes_panel = GITG_REVISION_CHANGES_PANEL (panel);

	set_revision (changes_panel, repository, revision);
}

static gchar *
gitg_revision_panel_get_label_impl (GitgRevisionPanel *panel)
{
	return g_strdup (_("Changes"));
}

static gchar *
revision_panel_get_id (void)
{
	return g_strdup ("changes");
}

static gchar *
gitg_revision_panel_get_id_impl (GitgRevisionPanel *panel)
{
	return revision_panel_get_id ();
}

static gchar *
gitg_activatable_get_id_impl (GitgActivatable *activatable)
{
	return revision_panel_get_id ();
}

static void
initialize_ui (GitgRevisionChangesPanel *changes_panel)
{
	GitgRevisionChangesPanelPrivate *priv = changes_panel->priv;

	priv->diff = GTK_SOURCE_VIEW (gtk_builder_get_object (priv->builder,
	                                                      "revision_diff"));

	priv->diff_files = GTK_TREE_VIEW (gtk_builder_get_object (priv->builder,
	                                                          "tree_view_revision_files"));

	GtkTreeSelection *selection;

	selection = gtk_tree_view_get_selection (priv->diff_files);

	gtk_tree_selection_set_mode (selection, GTK_SELECTION_MULTIPLE);

	g_signal_connect (selection,
	                  "changed",
	                  G_CALLBACK (on_diff_files_selection_changed),
	                  changes_panel);

	g_signal_connect (priv->diff_files,
	                  "button-press-event",
	                  G_CALLBACK (on_diff_files_button_press),
	                  changes_panel);

	priv->list_store_diff_files = gtk_list_store_new (1, diff_file_get_type ());

	GtkTreeModel *filter;

	filter = gtk_tree_model_filter_new (GTK_TREE_MODEL(priv->list_store_diff_files),
	                                                   NULL);
	gtk_tree_view_set_model (priv->diff_files, filter);

	gtk_tree_model_filter_set_visible_func (GTK_TREE_MODEL_FILTER (filter),
	                                        diff_file_visible,
	                                        NULL,
	                                        NULL);

	GtkTreeViewColumn *column;

	column = GTK_TREE_VIEW_COLUMN (gtk_builder_get_object (priv->builder,
	                                                       "revision_files_column_icon"));

	gtk_tree_view_column_set_cell_data_func (column,
	                                         GTK_CELL_RENDERER (gtk_builder_get_object (priv->builder,
	                                                            "revision_files_cell_renderer_icon")),
	                                         (GtkTreeCellDataFunc)revision_files_icon,
	                                         changes_panel,
	                                         NULL);

	column = GTK_TREE_VIEW_COLUMN (gtk_builder_get_object (priv->builder,
	                                                       "revision_files_column_name"));
	gtk_tree_view_column_set_cell_data_func (column,
	                                         GTK_CELL_RENDERER (gtk_builder_get_object (priv->builder,
	                                                            "revision_files_cell_renderer_name")),
	                                         (GtkTreeCellDataFunc)revision_files_name,
	                                         changes_panel,
	                                         NULL);

	GtkSourceLanguageManager *manager;
	GtkSourceLanguage *language;
	GtkSourceBuffer *buffer;

	manager = gtk_source_language_manager_get_default ();
	language = gtk_source_language_manager_get_language (manager, "gitgdiff");
	buffer = gtk_source_buffer_new_with_language (language);

	g_object_unref (language);

	GtkSourceStyleSchemeManager *scheme_manager;
	GtkSourceStyleScheme *scheme;

	scheme_manager = gtk_source_style_scheme_manager_get_default ();
	scheme = gtk_source_style_scheme_manager_get_scheme (scheme_manager,
	                                                     "gitg");
	gtk_source_buffer_set_style_scheme (buffer, scheme);

	gitg_utils_set_monospace_font (GTK_WIDGET (priv->diff));
	gtk_text_view_set_buffer (GTK_TEXT_VIEW (priv->diff),
	                          GTK_TEXT_BUFFER (buffer));

	g_signal_connect (priv->diff,
	                  "header-added",
	                  G_CALLBACK (on_header_added),
	                  changes_panel);
}

static GtkWidget *
gitg_revision_panel_get_panel_impl (GitgRevisionPanel *panel)
{
	GtkBuilder *builder;
	GtkWidget *ret;
	GitgRevisionChangesPanel *changes_panel;

	changes_panel = GITG_REVISION_CHANGES_PANEL (panel);

	if (changes_panel->priv->panel_widget)
	{
		return changes_panel->priv->panel_widget;
	}

	builder = gitg_utils_new_builder ("gitg-revision-changes-panel.ui");
	changes_panel->priv->builder = builder;

	ret = GTK_WIDGET (gtk_builder_get_object (builder, "revision_changes_page"));
	changes_panel->priv->panel_widget = ret;

	initialize_ui (changes_panel);

	return ret;
}

static gboolean
select_diff_file (GitgRevisionChangesPanel *changes_panel,
                  gchar const              *filename)
{
	GtkTreeModel *store;
	GtkTreeIter iter;

	store = gtk_tree_view_get_model (changes_panel->priv->diff_files);

	if (!gtk_tree_model_get_iter_first (store, &iter))
	{
		return FALSE;
	}

	do
	{
		DiffFile *file;

		gtk_tree_model_get (store, &iter, 0, &file, -1);

		if (g_strcmp0 (file->filename, filename) == 0)
		{
			GtkTreeSelection *selection;

			selection = gtk_tree_view_get_selection (changes_panel->priv->diff_files);

			gtk_tree_selection_unselect_all (selection);
			gtk_tree_selection_select_iter (selection, &iter);

			diff_file_unref (file);
			return TRUE;
		}

		diff_file_unref (file);
	} while (gtk_tree_model_iter_next (store, &iter));

	return FALSE;
}

static gboolean
gitg_activatable_activate_impl (GitgActivatable *activatable,
                                gchar const     *action)
{
	GitgRevisionChangesPanel *changes_panel;

	changes_panel = GITG_REVISION_CHANGES_PANEL (activatable);

	if (select_diff_file (changes_panel, action))
	{
		return TRUE;
	}

	g_free (changes_panel->priv->selection);
	changes_panel->priv->selection = g_strdup (action);

	return TRUE;
}

static void
gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface)
{
	iface->get_id = gitg_revision_panel_get_id_impl;
	iface->update = gitg_revision_panel_update_impl;
	iface->get_label = gitg_revision_panel_get_label_impl;
	iface->get_panel = gitg_revision_panel_get_panel_impl;
}

static void
gitg_activatable_iface_init (GitgActivatableInterface *iface)
{
	iface->get_id = gitg_activatable_get_id_impl;
	iface->activate = gitg_activatable_activate_impl;
}

static void
free_cached_header (gpointer header)
{
	g_slice_free (CachedHeader, header);
}

static void
free_cached_headers (GitgRevisionChangesPanel *changes_panel)
{
	g_slist_foreach (changes_panel->priv->cached_headers,
	                 (GFunc)free_cached_header,
	                 NULL);

	g_slist_free (changes_panel->priv->cached_headers);

	changes_panel->priv->cached_headers = NULL;
}


static void
gitg_revision_changes_panel_finalize (GObject *object)
{
	free_cached_headers (GITG_REVISION_CHANGES_PANEL (object));

	G_OBJECT_CLASS (gitg_revision_changes_panel_parent_class)->finalize (object);
}

static void
gitg_revision_changes_panel_dispose (GObject *object)
{
	GitgRevisionChangesPanel *changes_panel;

	changes_panel = GITG_REVISION_CHANGES_PANEL (object);

	set_revision (changes_panel, NULL, NULL);

	if (changes_panel->priv->diff_files_shell)
	{
		g_object_unref (changes_panel->priv->diff_files_shell);
		changes_panel->priv->diff_files_shell = NULL;
	}

	if (changes_panel->priv->diff_files_shell)
	{
		g_object_unref (changes_panel->priv->diff_shell);
		changes_panel->priv->diff_shell = NULL;
	}

	if (changes_panel->priv->builder)
	{
		g_object_unref (changes_panel->priv->builder);
		changes_panel->priv->builder = NULL;
	}

	if (changes_panel->priv->selection)
	{
		g_free (changes_panel->priv->selection);
		changes_panel->priv->selection = NULL;
	}

	G_OBJECT_CLASS (gitg_revision_changes_panel_parent_class)->dispose (object);
}

static void
gitg_revision_changes_panel_class_init (GitgRevisionChangesPanelClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gitg_revision_changes_panel_finalize;
	object_class->dispose = gitg_revision_changes_panel_dispose;

	g_type_class_add_private (object_class, sizeof(GitgRevisionChangesPanelPrivate));
}

static void
reload_diff (GitgRevisionChangesPanel *changes_panel)
{
	GtkTreeSelection *selection;

	// First cancel a possibly still running diff
	gitg_io_cancel (GITG_IO (changes_panel->priv->diff_shell));
	gitg_io_cancel (GITG_IO (changes_panel->priv->diff_files_shell));

	free_cached_headers (changes_panel);

	// Clear the buffer
	GtkTextBuffer *buffer;

	buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (changes_panel->priv->diff));
	gtk_text_buffer_set_text (buffer, "", 0);

	selection = gtk_tree_view_get_selection (changes_panel->priv->diff_files);
	g_signal_handlers_block_by_func (selection,
	                                 G_CALLBACK (on_diff_files_selection_changed),
	                                 changes_panel);

	gtk_list_store_clear (changes_panel->priv->list_store_diff_files);

	g_signal_handlers_unblock_by_func (selection,
	                                   G_CALLBACK (on_diff_files_selection_changed),
	                                   changes_panel);

	if (!changes_panel->priv->revision)
	{
		return;
	}

	gchar sign = gitg_revision_get_sign (changes_panel->priv->revision);
	gboolean allow_external;

	g_object_get (gitg_preferences_get_default (),
	              "diff-external",
	              &allow_external,
	              NULL);

	switch (sign)
	{
		case 't':
			gitg_shell_run (changes_panel->priv->diff_shell,
			                gitg_command_new (changes_panel->priv->repository,
			                                   "diff",
			                                   allow_external ? "--ext-diff" : "--no-ext-diff",
			                                   "--cached",
			                                   "-M",
			                                   "--pretty=format:",
			                                   "--encoding=UTF-8",
			                                   "--no-color",
			                                   NULL),
			                NULL);
		break;
		case 'u':
			gitg_shell_run (changes_panel->priv->diff_shell,
			                gitg_command_new (changes_panel->priv->repository,
			                                   "diff",
			                                   allow_external ? "--ext-diff" : "--no-ext-diff",
			                                   "-M",
			                                   "--pretty=format:",
			                                   "--encoding=UTF-8",
			                                   "--no-color",
			                                   NULL),
			                NULL);
		break;
		default:
		{
			gchar *hash = gitg_revision_get_sha1 (changes_panel->priv->revision);

			gitg_shell_run (changes_panel->priv->diff_shell,
			                gitg_command_new (changes_panel->priv->repository,
			                                   "show",
			                                   "-M",
			                                   "--pretty=format:",
			                                   "--encoding=UTF-8",
			                                   "--no-color",
			                                   hash,
			                                   NULL),
			                NULL);

			g_free (hash);
		}
		break;
	}
}

static void
set_revision (GitgRevisionChangesPanel *changes_panel,
              GitgRepository           *repository,
              GitgRevision             *revision)
{
	if (changes_panel->priv->repository == repository &&
	    changes_panel->priv->revision == revision)
	{
		return;
	}

	if (changes_panel->priv->diff_shell)
	{
		gitg_io_cancel (GITG_IO (changes_panel->priv->diff_shell));
	}

	if (changes_panel->priv->diff_files_shell)
	{
		gitg_io_cancel (GITG_IO (changes_panel->priv->diff_files_shell));
	}

	if (changes_panel->priv->repository)
	{
		g_object_unref (changes_panel->priv->repository);
	}

	if (changes_panel->priv->revision)
	{
		gitg_revision_unref (changes_panel->priv->revision);
	}

	if (repository)
	{
		changes_panel->priv->repository = g_object_ref (repository);
	}
	else
	{
		changes_panel->priv->repository = NULL;
	}

	if (revision)
	{
		changes_panel->priv->revision = gitg_revision_ref (revision);
	}
	else
	{
		changes_panel->priv->revision = NULL;
	}

	reload_diff (changes_panel);
}

static void
on_diff_files_begin_loading (GitgShell                *shell,
                             GitgRevisionChangesPanel *self)
{
	GdkCursor *cursor = gdk_cursor_new (GDK_WATCH);

	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET (self->priv->diff_files)),
	                       cursor);

	gdk_cursor_unref (cursor);
}

static void
on_diff_files_end_loading (GitgShell                *shell,
                           gboolean                  cancelled,
                           GitgRevisionChangesPanel *self)
{
	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET(self->priv->diff_files)),
	                       NULL);

	if (self->priv->selection)
	{
		select_diff_file (self, self->priv->selection);

		g_free (self->priv->selection);
		self->priv->selection = NULL;
	}
}

static gboolean
match_indices (DiffFile    *f,
               gchar const *from,
               gchar const *to)
{
	return g_str_has_prefix (f->index_from, from) &&
	       (g_str_has_prefix (f->index_to, to) ||
	        g_str_has_prefix (f->index_to, "0000000"));
}

static void
visible_from_cached_headers (GitgRevisionChangesPanel *view,
                             DiffFile                 *f)
{
	GSList *item;

	for (item = view->priv->cached_headers; item; item = g_slist_next (item))
	{
		CachedHeader *header = (CachedHeader *)item->data;
		gchar *from;
		gchar *to;

		gitg_diff_iter_get_index (&header->iter, &from, &to);

		if (gitg_diff_iter_get_index (&header->iter, &from, &to) && match_indices (f, from, to))
		{
			f->visible = TRUE;
			f->iter = header->iter;

			return;
		}
	}
}

static void
add_diff_file (GitgRevisionChangesPanel *view,
               DiffFile                 *f)
{
	GtkTreeIter iter;
	gtk_list_store_append (view->priv->list_store_diff_files, &iter);

	/* see if it is in the cached headers */
	visible_from_cached_headers (view, f);
	gtk_list_store_set (view->priv->list_store_diff_files, &iter, 0, f, -1);
}

static void
on_diff_files_update (GitgShell                 *shell,
                      gchar                    **buffer,
                      GitgRevisionChangesPanel  *self)
{
	gchar **line;

	while (*(line = buffer++))
	{
		if (**line == '\0')
		{
			continue;
		}

		// Count parents
		gint parents = 0;
		gchar *ptr = *line;

		while (*(ptr++) == ':')
		{
			++parents;
		}

		gint numparts = 3 + 2 * parents;
		gchar **parts = g_strsplit (ptr, " ", numparts);

		if (g_strv_length (parts) == numparts)
		{
			gchar **files = g_strsplit (parts[numparts - 1], "\t", -1);

			DiffFile *f = diff_file_new (parts[parents + 1], parts[numparts - 2], files[0], files[1]);

			add_diff_file (self, f);
			diff_file_unref (f);

			g_strfreev (files);
		}

		g_strfreev (parts);
	}
}

static void
on_diff_begin_loading (GitgShell                *shell,
                       GitgRevisionChangesPanel *self)
{
	GdkCursor *cursor = gdk_cursor_new (GDK_WATCH);
	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET(self->priv->diff)),
	                       cursor);
	gdk_cursor_unref (cursor);
}

static void
on_diff_end_loading (GitgShell                *shell,
                     gboolean                  cancelled,
                     GitgRevisionChangesPanel *self)
{
	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET(self->priv->diff)),
	                       NULL);

	if (cancelled)
	{
		return;
	}

	gchar sign = gitg_revision_get_sign (self->priv->revision);
	gboolean allow_external;

	g_object_get (gitg_preferences_get_default (),
	              "diff-external",
	              &allow_external,
	              NULL);

	if (sign == 't' || sign == 'u')
	{
		gchar *head = gitg_repository_parse_head (self->priv->repository);
		const gchar *cached = NULL;

		if (sign == 't')
			cached = "--cached";

		gitg_shell_run (self->priv->diff_files_shell,
		                gitg_command_new (self->priv->repository,
		                                   "diff-index",
		                                   allow_external ? "--ext-diff" : "--no-ext-diff",
		                                   "--raw",
		                                   "-M",
		                                   "--abbrev=40",
		                                   head,
		                                   cached,
		                                   NULL),
		                NULL);
		g_free (head);
	}
	else
	{
		gchar *sha = gitg_revision_get_sha1 (self->priv->revision);
		gitg_shell_run (self->priv->diff_files_shell,
		                gitg_command_new (self->priv->repository,
		                                   "show",
		                                   "--encoding=UTF-8",
		                                   "--raw",
		                                   "-M",
		                                   "--pretty=format:",
		                                   "--abbrev=40",
		                                   sha,
		                                   NULL),
		                NULL);
		g_free (sha);
	}
}

static void
on_diff_update (GitgShell                 *shell,
                gchar                    **buffer,
                GitgRevisionChangesPanel  *self)
{
	gchar *line;
	GtkTextBuffer *buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW(self->priv->diff));
	GtkTextIter iter;

	gtk_text_buffer_get_end_iter (buf, &iter);

	while ((line = *buffer++))
	{
		gtk_text_buffer_insert (buf, &iter, line, -1);
		gtk_text_buffer_insert (buf, &iter, "\n", -1);
	}
}

static void
gitg_revision_changes_panel_init (GitgRevisionChangesPanel *self)
{
	self->priv = GITG_REVISION_CHANGES_PANEL_GET_PRIVATE (self);

	self->priv->diff_shell = gitg_shell_new (2000);

	g_signal_connect (self->priv->diff_shell,
	                  "begin",
	                  G_CALLBACK (on_diff_begin_loading),
	                  self);

	g_signal_connect (self->priv->diff_shell,
	                  "update",
	                  G_CALLBACK (on_diff_update),
	                  self);

	g_signal_connect (self->priv->diff_shell,
	                  "end",
	                  G_CALLBACK (on_diff_end_loading),
	                  self);

	self->priv->diff_files_shell = gitg_shell_new (2000);

	g_signal_connect (self->priv->diff_files_shell,
	                  "begin",
	                  G_CALLBACK(on_diff_files_begin_loading),
	                  self);

	g_signal_connect (self->priv->diff_files_shell,
	                  "update",
	                  G_CALLBACK(on_diff_files_update),
	                  self);

	g_signal_connect (self->priv->diff_files_shell,
	                  "end",
	                  G_CALLBACK(on_diff_files_end_loading),
	                  self);
}

static gboolean
find_diff_file (GitgRevisionChangesPanel  *view,
                GitgDiffIter              *iter,
                GtkTreeIter               *it,
                DiffFile                 **f)
{
	gchar *from;
	gchar *to;

	if (!gitg_diff_iter_get_index (iter, &from, &to))
	{
		return FALSE;
	}

	GtkTreeModel *model = GTK_TREE_MODEL (view->priv->list_store_diff_files);

	if (!gtk_tree_model_get_iter_first (model, it))
	{
		return FALSE;
	}

	do
	{
		gtk_tree_model_get (model, it, 0, f, -1);

		if (match_indices (*f, from, to))
		{
			return TRUE;
		}

		diff_file_unref (*f);
	} while (gtk_tree_model_iter_next (model, it));

	return FALSE;
}

static void
on_header_added (GitgDiffView             *view,
                 GitgDiffIter             *iter,
                 GitgRevisionChangesPanel *self)
{
	GtkTreeIter it;
	DiffFile *f;

	if (find_diff_file (self, iter, &it, &f))
	{
		if (!f->visible)
		{
			f->visible = TRUE;
			f->iter = *iter;

			diff_file_unref (f);

			GtkTreeModel *model = GTK_TREE_MODEL (self->priv->list_store_diff_files);
			GtkTreePath *path = gtk_tree_model_get_path (model, &it);

			gtk_tree_model_row_changed (model, path, &it);
			gtk_tree_path_free (path);
		}
	}
	else
	{
		/* Insert in cached headers */
		CachedHeader *header = g_slice_new (CachedHeader);
		header->iter = *iter;

		self->priv->cached_headers = g_slist_prepend (self->priv->cached_headers, header);
	}
}

typedef struct
{
	gint numselected;
	GtkTreeSelection *selection;
} ForeachSelectionData;

static gboolean
foreach_selection_changed (GtkTreeModel         *model,
                           GtkTreePath          *path,
                           GtkTreeIter          *iter,
                           ForeachSelectionData *data)
{
	gboolean visible = data->numselected == 0 ||
	                   gtk_tree_selection_path_is_selected (data->selection,
	                                                        path);

	DiffFile *f = NULL;
	gtk_tree_model_get (model, iter, 0, &f, -1);

	if (f->visible)
	{
		gitg_diff_iter_set_visible (&f->iter, visible);
	}

	diff_file_unref (f);
	return FALSE;
}

static void
on_diff_files_selection_changed (GtkTreeSelection         *selection,
                                 GitgRevisionChangesPanel *self)
{
	ForeachSelectionData data = {
		gtk_tree_selection_count_selected_rows (selection),
		selection
	};

	gtk_tree_model_foreach (gtk_tree_view_get_model (self->priv->diff_files),
	                        (GtkTreeModelForeachFunc)foreach_selection_changed,
	                        &data);
}

