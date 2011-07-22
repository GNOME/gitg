/*
 * gitg-revision-files-panel.c
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

#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <string.h>
#include <glib/gi18n.h>
#include <gio/gio.h>
#include <stdlib.h>
#include <libgitg/gitg-revision.h>
#include <libgitg/gitg-shell.h>

#include "gitg-revision-files-panel.h"
#include "gitg-utils.h"
#include "gitg-revision-panel.h"
#include "gitg-dirs.h"
#include "gitg-blame-renderer.h"

#define GITG_REVISION_FILES_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_FILES_VIEW, GitgRevisionFilesViewPrivate))

#define GITG_REVISION_FILES_PANEL_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_FILES_PANEL, GitgRevisionFilesPanelPrivate))

#define BLAME_DATA "GitgRevisionFilesPanelBlame"

enum
{
	ICON_COLUMN,
	NAME_COLUMN,
	CONTENT_TYPE_COLUMN,
	N_COLUMNS
};

typedef struct _GitgRevisionFilesView GitgRevisionFilesView;
typedef struct _GitgRevisionFilesViewClass GitgRevisionFilesViewClass;
typedef struct _GitgRevisionFilesViewPrivate GitgRevisionFilesViewPrivate;

struct _GitgRevisionFilesViewPrivate
{
	GtkNotebook *notebook_files;

	GtkTreeView *tree_view;

	GtkSourceView *contents;
	GitgShell *content_shell;
	GtkTreeStore *store;

	GtkSourceView *blame_view;
	GitgShell *blame_shell;
	GHashTable *blames; /* hash : tag */
	GitgBlameRenderer *blame_renderer;
	gint blame_offset;
	GtkTextTag *active_tag;
	gboolean blame_active;

	glong query_data_id;
	glong query_tooltip_id;

	GtkWidget *active_view;

	gchar *drag_dir;
	gchar **drag_files;

	GitgRepository *repository;
	GitgRevision *revision;
	GitgShell *loader;
	GtkTreePath *load_path;

	gboolean skipped_blank_line;
};

struct _GitgRevisionFilesView
{
	GtkHPaned parent;

	GitgRevisionFilesViewPrivate *priv;
};

struct _GitgRevisionFilesViewClass
{
	GtkHPanedClass parent_class;
};

struct _GitgRevisionFilesPanelPrivate
{
	GitgRevisionFilesView *panel;
};

#define GITG_TYPE_REVISION_FILES_VIEW		(gitg_revision_files_view_get_type ())
#define GITG_REVISION_FILES_VIEW(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_FILES_VIEW, GitgRevisionFilesView))

static void gitg_revision_files_view_buildable_iface_init (GtkBuildableIface *iface);
static void gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface);

static void load_node (GitgRevisionFilesView *view, GtkTreeIter *parent);
static gchar *node_identity (GitgRevisionFilesView *view, GtkTreeIter *iter);

G_DEFINE_TYPE_EXTENDED (GitgRevisionFilesPanel,
                        gitg_revision_files_panel,
                        G_TYPE_OBJECT,
                        0,
                        G_IMPLEMENT_INTERFACE (GITG_TYPE_REVISION_PANEL,
                                               gitg_revision_panel_iface_init));

G_DEFINE_TYPE_EXTENDED (GitgRevisionFilesView,
                        gitg_revision_files_view,
                        GTK_TYPE_HPANED,
                        0,
                        G_IMPLEMENT_INTERFACE (GTK_TYPE_BUILDABLE,
                                               gitg_revision_files_view_buildable_iface_init));

static GtkBuildableIface parent_iface;

static void
gitg_revision_files_view_finalize (GObject *object)
{
	GitgRevisionFilesView *self = GITG_REVISION_FILES_VIEW (object);

	if (self->priv->load_path)
	{
		gtk_tree_path_free (self->priv->load_path);
	}

	g_free (self->priv->drag_dir);

	if (self->priv->drag_files)
	{
		g_strfreev (self->priv->drag_files);
	}

	gitg_io_cancel (GITG_IO (self->priv->loader));
	g_object_unref (self->priv->loader);

	gitg_io_cancel (GITG_IO (self->priv->content_shell));
	g_object_unref (self->priv->content_shell);

	g_hash_table_unref (self->priv->blames);

	gitg_io_cancel (GITG_IO (self->priv->blame_shell));
	g_object_unref (self->priv->blame_shell);

	G_OBJECT_CLASS (gitg_revision_files_view_parent_class)->finalize (object);
}

static void
load_tree (GitgRevisionFilesView *files_view)
{
	load_node (files_view, NULL);
}

static void
set_revision (GitgRevisionFilesView *files_view,
              GitgRepository       *repository,
              GitgRevision         *revision)
{
	if (files_view->priv->repository == repository &&
	    files_view->priv->revision == revision)
	{
		return;
	}

	gitg_io_cancel (GITG_IO (files_view->priv->loader));
	gtk_tree_store_clear (files_view->priv->store);

	if (files_view->priv->repository)
	{
		g_object_unref (files_view->priv->repository);
	}

	if (files_view->priv->revision)
	{
		gitg_revision_unref (files_view->priv->revision);
	}

	if (repository)
	{
		files_view->priv->repository = g_object_ref (repository);
	}
	else
	{
		files_view->priv->repository = NULL;
	}

	if (revision)
	{
		files_view->priv->revision = gitg_revision_ref (revision);
	}
	else
	{
		files_view->priv->revision = NULL;
	}

	if (files_view->priv->repository && files_view->priv->revision)
	{
		load_tree (files_view);
	}
}

static GtkTextTag *
get_blame_tag_from_iter (GitgRevisionFilesView *files_view,
                         GtkTextIter           *iter)
{
	GtkTextTag *tag = NULL;
	GSList *tags, *l;

	tags = gtk_text_iter_get_tags (iter);

	for (l = tags; l != NULL; l = g_slist_next (l))
	{
		if (g_object_get_data (l->data, BLAME_DATA) != NULL)
		{
			tag = l->data;
			break;
		}
	}

	g_slist_free (tags);

	return tag;
}

static void
blame_renderer_query_data_cb (GtkSourceGutterRenderer      *renderer,
                              GtkTextIter                  *start,
                              GtkTextIter                  *end,
                              GtkSourceGutterRendererState  state,
                              GitgRevisionFilesView        *files_view)
{
	GtkTextTag *tag;
	GitgRevision *rev;
	GtkTextIter iter;

	iter = *start;
	gtk_text_iter_set_line_offset (&iter, 0);

	tag = get_blame_tag_from_iter (files_view, &iter);

	if (tag == NULL)
		return;

	rev = g_object_get_data (G_OBJECT (tag), BLAME_DATA);

	if (gtk_text_iter_begins_tag (&iter, tag))
	{
		gboolean group_start = FALSE;

		if (!gtk_text_iter_is_start (&iter))
		{
			group_start = TRUE;
		}

		g_object_set (renderer,
		              "revision", rev,
		              "show", TRUE,
		              "group-start", group_start,
		              NULL);
	}
	else
	{
		g_object_set (renderer,
		              "revision", rev,
		              "show", FALSE,
		              "group-start", FALSE,
		              NULL);
	}
}

static gboolean
blame_renderer_query_tooltip_cb (GtkSourceGutterRenderer *renderer,
                                 GtkTextIter             *iter,
                                 GdkRectangle            *area,
                                 gint                     x,
                                 gint                     y,
                                 GtkTooltip              *tooltip,
                                 GitgRevisionFilesView   *tree)
{
	GtkTextTag *tag;
	GitgRevision *rev;
	const gchar *author;
	const gchar *committer;
	const gchar *subject;
	gchar *text;
	gchar *sha1;
	gchar *author_date;
	gchar *committer_date;

	tag = get_blame_tag_from_iter (tree, iter);

	if (tag == NULL)
		return FALSE;

	rev = g_object_get_data (G_OBJECT (tag), BLAME_DATA);

	if (rev == NULL)
		return FALSE;

	sha1 = gitg_revision_get_sha1 (rev);
	author_date = gitg_revision_get_author_date_for_display (rev);
	committer_date = gitg_revision_get_committer_date_for_display (rev);

	author = _("Author");
	committer = _("Committer");
	subject = _("Subject");

	text = g_markup_printf_escaped ("<b>SHA:</b> %s\n"
	                                "<b>%s:</b> %s &lt;%s&gt; (%s)\n"
	                                "<b>%s:</b> %s &lt;%s&gt; (%s)\n"
	                                "<b>%s:</b> <i>%s</i>",
	                                sha1,
	                                author, gitg_revision_get_author (rev),
	                                gitg_revision_get_author_email (rev),
	                                author_date,
	                                committer, gitg_revision_get_committer (rev),
	                                gitg_revision_get_committer_email (rev),
	                                committer_date,
	                                subject, gitg_revision_get_subject (rev));

	g_free (sha1);
	g_free (author_date);
	g_free (committer_date);
	gtk_tooltip_set_markup (tooltip, text);
	g_free (text);

	return TRUE;
}

static void
remove_blames (GitgRevisionFilesView *tree)
{
	GtkTextBuffer *buffer;
	GList *tags, *tag;
	GtkTextTagTable *table;

	tree->priv->blame_active = FALSE;

	buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (tree->priv->blame_view));
	table = gtk_text_buffer_get_tag_table (buffer);

	if (tree->priv->query_data_id != 0)
	{
		g_signal_handler_disconnect (tree->priv->blame_renderer,
		                             tree->priv->query_data_id);
		tree->priv->query_data_id = 0;
	}

	if (tree->priv->query_tooltip_id != 0)
	{
		g_signal_handler_disconnect (tree->priv->blame_renderer,
		                             tree->priv->query_tooltip_id);
		tree->priv->query_tooltip_id = 0;
	}

	tags = g_hash_table_get_values (tree->priv->blames);

	for (tag = tags; tag != NULL; tag = g_list_next (tag))
	{
		g_object_set_data (tag->data, BLAME_DATA, NULL);
		gtk_text_tag_table_remove (table, tag->data);
	}

	g_hash_table_remove_all (tree->priv->blames);

	g_list_free (tags);

	tree->priv->blame_offset = 0;
	tree->priv->active_tag = NULL;

	g_object_set (tree->priv->blame_renderer,
	              "revision", NULL,
	              "show", FALSE,
	              "group-start", FALSE,
	              NULL);

	gitg_blame_renderer_set_max_line_count (tree->priv->blame_renderer, 0);
}

static void
gitg_revision_files_view_dispose (GObject *object)
{
	GitgRevisionFilesView* files_view = GITG_REVISION_FILES_VIEW (object);

	set_revision (files_view, NULL, NULL);

	if (files_view->priv->blame_active)
	{
		remove_blames (files_view);
	}

	G_OBJECT_CLASS (gitg_revision_files_view_parent_class)->dispose (object);
}

static gboolean
loaded (GitgRevisionFilesView *view,
        GtkTreeIter          *iter)
{
	gint num;

	num = gtk_tree_model_iter_n_children (GTK_TREE_MODEL(view->priv->store),
	                                      iter);

	if (num != 1)
	{
		return TRUE;
	}

	gchar *content_type = NULL;
	GtkTreeIter child;

	if (!gtk_tree_model_iter_children (GTK_TREE_MODEL(view->priv->store),
	                                   &child,
	                                   iter))
	{
		return FALSE;
	}

	gtk_tree_model_get (GTK_TREE_MODEL(view->priv->store),
	                    &child,
	                    CONTENT_TYPE_COLUMN,
	                    &content_type,
	                    -1);

	gboolean ret = content_type != NULL;
	g_free (content_type);

	return ret;
}

static void
on_row_expanded (GtkTreeView          *files_view,
                 GtkTreeIter          *iter,
                 GtkTreePath          *path,
                 GitgRevisionFilesView *view)
{
	if (loaded (view, iter))
	{
		return;
	}

	load_node (view, iter);
}

static void
show_binary_information (GitgRevisionFilesView *tree,
                         GtkTextBuffer         *buffer)
{
	gtk_text_buffer_set_text (buffer,
	                          _("Cannot display file content as text"),
	                          -1);

	gtk_source_buffer_set_language (GTK_SOURCE_BUFFER (buffer), NULL);
}

static void
on_selection_changed (GtkTreeSelection      *selection,
                      GitgRevisionFilesView *tree)
{
	GtkTextBuffer *buffer;
	gboolean blame_mode;
	GtkTreeModel *model;
	GtkTreeIter iter;
	GtkTreePath *path = NULL;
	GList *rows;
	gchar *name;
	gchar *content_type;

	if (tree->priv->active_view == GTK_WIDGET (tree->priv->contents))
	{
		buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (tree->priv->contents));
		gitg_io_cancel (GITG_IO (tree->priv->content_shell));
		blame_mode = FALSE;
	}
	else
	{
		buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (tree->priv->blame_view));
		blame_mode = TRUE;
		gitg_io_cancel (GITG_IO (tree->priv->blame_shell));

		remove_blames (tree);
	}

	gtk_text_buffer_set_text (buffer, "", -1);

	if (!tree->priv->revision)
	{
		return;
	}

	rows = gtk_tree_selection_get_selected_rows (selection, &model);

	if (g_list_length (rows) == 1)
	{
		path = gtk_tree_path_copy ((GtkTreePath *)rows->data);
	}

	g_list_free_full (rows, (GDestroyNotify)gtk_tree_path_free);

	if (!path)
	{
		return;
	}

	gtk_tree_model_get_iter (model, &iter, path);
	gtk_tree_path_free (path);
	gtk_tree_model_get (model,
	                    &iter,
	                    NAME_COLUMN,
	                    &name,
	                    CONTENT_TYPE_COLUMN,
	                    &content_type,
	                    -1);

	if (!content_type)
	{
		g_free (name);
		return;
	}

	if (!gitg_utils_can_display_content_type (content_type))
	{
		show_binary_information (tree, buffer);
	}
	else
	{
		GtkSourceLanguage *language;
		gchar *id;

		language = gitg_utils_get_language (name, content_type);
		gtk_source_buffer_set_language (GTK_SOURCE_BUFFER(buffer),
		                                language);

		id = node_identity (tree, &iter);

		if (!blame_mode)
		{
			gitg_shell_run (tree->priv->content_shell,
			                gitg_command_new (tree->priv->repository,
			                                  "show",
			                                  "--encoding=UTF-8",
			                                  id,
			                                  NULL),
			                NULL);
		}
		else
		{
			gchar **hash_name;

			gitg_blame_renderer_set_max_line_count (tree->priv->blame_renderer, 0);
			tree->priv->blame_active = TRUE;

			hash_name = g_strsplit (id, ":", 2);
			gitg_shell_run (tree->priv->blame_shell,
			                gitg_command_new (tree->priv->repository,
			                                  "blame",
			                                  "--encoding=UTF-8",
			                                  "--root",
			                                  "-l",
			                                  hash_name[0],
			                                  "--",
			                                  hash_name[1],
			                                  NULL),
			                NULL);

			g_strfreev (hash_name);
		}

		g_free (id);
	}

	g_free (name);
	g_free (content_type);
}

static gchar *
node_path (GtkTreeModel *model,
           GtkTreeIter  *parent)
{
	if (!parent)
	{
		return NULL;
	}

	gchar *name;
	gtk_tree_model_get (model,
	                    parent,
	                    NAME_COLUMN,
	                    &name,
	                    -1);

	GtkTreeIter parent_iter;
	gchar *ret;

	if (gtk_tree_model_iter_parent (model, &parent_iter, parent))
	{
		gchar *path = node_path (model, &parent_iter);
		ret = g_build_filename (path, name, NULL);
		g_free (path);
		g_free (name);
	}
	else
	{
		ret = name;
	}

	return ret;
}

static void
export_drag_files (GitgRevisionFilesView *files_view)
{
	GtkTreeSelection *selection;
	GtkTreeModel *model;

	selection = gtk_tree_view_get_selection (files_view->priv->tree_view);

	GList *rows = gtk_tree_selection_get_selected_rows (selection, &model);
	gint num = g_list_length (rows);
	
	if (num == 0)
	{
		g_list_free (rows);
		return;
	}

	GList *item;

	files_view->priv->drag_files = g_new (gchar *, num + 1);
	gchar **ptr = files_view->priv->drag_files;

	for (item = rows; item; item = item->next)
	{
		GtkTreePath *path = (GtkTreePath *)item->data;
		GtkTreeIter iter;
		gtk_tree_model_get_iter (model, &iter, path);

		*ptr++ = node_path (model, &iter);
		gtk_tree_path_free (path);
	}

	*ptr = NULL;
	g_list_free (rows);

	// Prepend temporary directory in uri list
	g_free (files_view->priv->drag_dir);
	gchar const *tmp = g_get_tmp_dir ();
	files_view->priv->drag_dir = g_build_filename (tmp,
	                                              "gitg-export-XXXXXX",
	                                              NULL);

	if (!mkdtemp (files_view->priv->drag_dir))
	{
		g_warning ("Could not create temporary directory for export");
		return;
	}

	// Do the export
	gitg_utils_export_files (files_view->priv->repository,
	                         files_view->priv->revision,
	                         files_view->priv->drag_dir,
	                         files_view->priv->drag_files);

	ptr = files_view->priv->drag_files;

	while (*ptr)
	{
		gchar *tmp = g_build_filename (files_view->priv->drag_dir, *ptr, NULL);
		g_free (*ptr);

		GFile *file = g_file_new_for_path (tmp);
		*ptr++ = g_file_get_uri (file);

		g_free (tmp);
	}
}

static void
on_drag_data_get (GtkWidget            *widget,
                  GdkDragContext       *context,
                  GtkSelectionData     *selection,
                  guint                 info,
                  guint                 time,
                  GitgRevisionFilesView *files_view)
{
	if (!files_view->priv->drag_files)
	{
		export_drag_files (files_view);
	}

	gtk_selection_data_set_uris (selection, files_view->priv->drag_files);
}

static gboolean
test_selection (GtkTreeSelection *selection,
                GtkTreeModel     *model,
                GtkTreePath      *path,
                gboolean          path_currently_selected,
                gpointer          data)
{
	if (path_currently_selected)
	{
		return TRUE;
	}

	// Test for (Empty)
	GtkTreeIter iter;

	if (!gtk_tree_model_get_iter (model, &iter, path))
	{
		return FALSE;
	}

	gchar *content_type;
	gtk_tree_model_get (model,
	                    &iter,
	                    CONTENT_TYPE_COLUMN,
	                    &content_type,
	                    -1);

	if (!content_type)
	{
		return FALSE;
	}

	g_free (content_type);
	return TRUE;
}

static void
on_drag_end (GtkWidget            *widget,
             GdkDragContext       *context,
             GitgRevisionFilesView *files_view)
{
	if (files_view->priv->drag_files != NULL)
	{
		g_strfreev (files_view->priv->drag_files);
		files_view->priv->drag_files = NULL;

		g_free (files_view->priv->drag_dir);
		files_view->priv->drag_dir = NULL;
	}
}

static void
on_notebook_files_switch_page (GtkNotebook           *notebook,
                               GtkWidget             *page,
                               guint                  page_num,
                               GitgRevisionFilesView *files_view)
{
	GtkTreeSelection *selection;

	files_view->priv->active_view = gtk_bin_get_child (GTK_BIN (page));

	selection = gtk_tree_view_get_selection (files_view->priv->tree_view);
	on_selection_changed (selection, files_view);
}

static void
gitg_revision_files_view_parser_finished (GtkBuildable *buildable,
                                          GtkBuilder   *builder)
{
	GtkSourceGutter *gutter;

	if (parent_iface.parser_finished)
	{
		parent_iface.parser_finished (buildable, builder);
	}

	// Store widgets
	GitgRevisionFilesView *files_view = GITG_REVISION_FILES_VIEW(buildable);
	files_view->priv->tree_view = GTK_TREE_VIEW (gtk_builder_get_object (builder,
	                                            "revision_files"));
	files_view->priv->notebook_files = GTK_NOTEBOOK (gtk_builder_get_object (builder,
	                                                 "notebook_files"));
	files_view->priv->contents = GTK_SOURCE_VIEW (gtk_builder_get_object (builder,
	                                             "revision_files_contents"));
	files_view->priv->blame_view = GTK_SOURCE_VIEW (gtk_builder_get_object (builder,
	                                                "revision_blame_view"));
	files_view->priv->blame_renderer = gitg_blame_renderer_new ();

	gutter = gtk_source_view_get_gutter (GTK_SOURCE_VIEW (files_view->priv->blame_view),
	                                     GTK_TEXT_WINDOW_LEFT);

	gtk_source_gutter_insert (gutter,
	                          GTK_SOURCE_GUTTER_RENDERER (files_view->priv->blame_renderer),
	                          0);

	/* set the active view */
	files_view->priv->active_view = GTK_WIDGET (files_view->priv->contents);

	gitg_utils_set_monospace_font (GTK_WIDGET(files_view->priv->contents));
	gitg_utils_set_monospace_font (GTK_WIDGET(files_view->priv->blame_view));
	gtk_tree_view_set_model (files_view->priv->tree_view,
	                         GTK_TREE_MODEL(files_view->priv->store));

	GtkTreeSelection *selection;

	selection = gtk_tree_view_get_selection (files_view->priv->tree_view);
	gtk_tree_selection_set_mode (selection, GTK_SELECTION_MULTIPLE);
	gtk_tree_selection_set_select_function (selection,
	                                        test_selection,
	                                        NULL,
	                                        NULL);

	// Setup drag source
	GtkTargetEntry targets[] = {
		{"text/uri-list", GTK_TARGET_OTHER_APP, 0}
	};

	// Set tree view as a drag source
	gtk_drag_source_set (GTK_WIDGET(files_view->priv->tree_view),
	                     GDK_BUTTON1_MASK,
	                     targets,
	                     1,
	                     GDK_ACTION_DEFAULT | GDK_ACTION_COPY);

	// Connect signals
	g_signal_connect_after (files_view->priv->tree_view,
	                        "row-expanded",
	                        G_CALLBACK(on_row_expanded),
	                        files_view);

	g_signal_connect (files_view->priv->tree_view,
	                  "drag-data-get",
	                  G_CALLBACK(on_drag_data_get),
	                  files_view);

	g_signal_connect (files_view->priv->tree_view,
	                  "drag-end",
	                  G_CALLBACK(on_drag_end),
	                  files_view);

	g_signal_connect (selection,
	                  "changed",
	                  G_CALLBACK(on_selection_changed),
	                  files_view);

	g_signal_connect (files_view->priv->notebook_files,
	                  "switch-page",
	                  G_CALLBACK (on_notebook_files_switch_page),
	                  files_view);
}

static void
gitg_revision_panel_update_impl (GitgRevisionPanel *panel,
                                 GitgRepository    *repository,
                                 GitgRevision      *revision)
{
	GitgRevisionFilesPanel *files_view_panel;

	files_view_panel = GITG_REVISION_FILES_PANEL (panel);

	set_revision (files_view_panel->priv->panel, repository, revision);
}

static gchar *
gitg_revision_panel_get_id_impl (GitgRevisionPanel *panel)
{
	return g_strdup ("files");
}

static gchar *
gitg_revision_panel_get_label_impl (GitgRevisionPanel *panel)
{
	return g_strdup (_("Files"));
}

static GtkWidget *
gitg_revision_panel_get_panel_impl (GitgRevisionPanel *panel)
{
	GtkBuilder *builder;
	GtkWidget *ret;
	GitgRevisionFilesPanel *files_view_panel;

	files_view_panel = GITG_REVISION_FILES_PANEL (panel);

	if (files_view_panel->priv->panel)
	{
		return GTK_WIDGET (files_view_panel->priv->panel);
	}

	builder = gitg_utils_new_builder ("gitg-revision-files-panel.ui");
	ret = GTK_WIDGET (gtk_builder_get_object (builder, "revision_files_view"));
	files_view_panel->priv->panel = g_object_ref (ret);

	g_object_unref (builder);

	return ret;
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
gitg_revision_files_view_buildable_iface_init (GtkBuildableIface *iface)
{
	parent_iface = *iface;

	iface->parser_finished = gitg_revision_files_view_parser_finished;
}

static void
gitg_revision_files_view_class_init (GitgRevisionFilesViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);

	object_class->finalize = gitg_revision_files_view_finalize;
	object_class->dispose = gitg_revision_files_view_dispose;

	g_type_class_add_private (object_class, sizeof (GitgRevisionFilesViewPrivate));
}

static void
gitg_revision_files_panel_dispose (GObject *object)
{
	GitgRevisionFilesPanel *panel;

	panel = GITG_REVISION_FILES_PANEL (object);

	if (panel->priv->panel)
	{
		g_object_unref (panel->priv->panel);
		panel->priv->panel = NULL;
	}

	G_OBJECT_CLASS (gitg_revision_files_panel_parent_class)->dispose (object);
}

static void
gitg_revision_files_panel_class_init (GitgRevisionFilesPanelClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->dispose = gitg_revision_files_panel_dispose;

	g_type_class_add_private (object_class, sizeof (GitgRevisionFilesPanelPrivate));
}

static gchar *
get_content_type (gchar    *name,
                  gboolean  dir)
{
	if (dir)
	{
		return g_strdup ("inode/directory");
	}
	else
	{
		return g_content_type_guess (name, NULL, 0, NULL);
	}
}

static void
remove_dummy (GitgRevisionFilesView *tree)
{
	if (!tree->priv->load_path)
	{
		return;
	}

	GtkTreeIter parent;
	GtkTreeModel *model = GTK_TREE_MODEL(tree->priv->store);
	gtk_tree_model_get_iter (model, &parent, tree->priv->load_path);

	if (gtk_tree_model_iter_n_children (model, &parent) != 2)
	{
		return;
	}

	GtkTreeIter child;
	gtk_tree_model_iter_children (model, &child, &parent);

	do
	{
		gchar *content_type;
		gtk_tree_model_get (model,
		                    &child,
		                    CONTENT_TYPE_COLUMN,
		                    &content_type,
		                    -1);

		if (!content_type)
		{
			gtk_tree_store_remove (tree->priv->store, &child);
			break;
		}
		g_free (content_type);
	} while (gtk_tree_model_iter_next (model, &child));
}

static void
append_node (GitgRevisionFilesView *tree,
             gchar                *line)
{
	GtkTreeIter parent;
	GtkTreeIter iter;

	if (tree->priv->load_path)
	{
		gtk_tree_model_get_iter (GTK_TREE_MODEL(tree->priv->store),
		                         &parent,
		                         tree->priv->load_path);
		gtk_tree_store_append (tree->priv->store, &iter, &parent);
	}
	else
	{
		gtk_tree_store_append (tree->priv->store, &iter, NULL);
	}

	int len = strlen (line);
	gboolean isdir = FALSE;

	if (line[len - 1] == '/')
	{
		isdir = TRUE;
		line[len - 1] = '\0';
	}

	GIcon *icon;

	if (isdir)
	{
		GtkTreeIter empty;
		gtk_tree_store_append (tree->priv->store, &empty, &iter);
		gtk_tree_store_set (tree->priv->store,
		                    &empty,
		                    NAME_COLUMN,
		                    _ ("(Empty)"),
		                    -1);

		gchar *content_type = get_content_type (line, TRUE);
		gtk_tree_store_set (tree->priv->store,
		                    &iter,
		                    CONTENT_TYPE_COLUMN,
		                    content_type,
		                    -1);
		icon = g_content_type_get_icon (content_type);
		g_free (content_type);

		if (icon && G_IS_THEMED_ICON(icon))
		{
			g_themed_icon_append_name (G_THEMED_ICON(icon), "folder");
		}
	}
	else
	{
		gchar *content_type = get_content_type (line, FALSE);
		icon = g_content_type_get_icon (content_type);
		gtk_tree_store_set (tree->priv->store,
		                    &iter,
		                    CONTENT_TYPE_COLUMN,
		                    content_type,
		                    -1);
		g_free (content_type);

		if (icon && G_IS_THEMED_ICON(icon))
		{
			g_themed_icon_append_name (G_THEMED_ICON(icon),
			                           "text-x-generic");
		}
	}

	if (G_IS_THEMED_ICON(icon))
	{
		GtkIconTheme *theme = gtk_icon_theme_get_default ();

		gchar **names;
		g_object_get (icon, "names", &names, NULL);

		GtkIconInfo *info;

		info = gtk_icon_theme_choose_icon (theme,
		                                   (gchar const **)names,
		                                   16,
		                                   0);

		if (info)
		{
			GError *error = NULL;
			GdkPixbuf *pixbuf = gtk_icon_info_load_icon (info, &error);

			if (!pixbuf)
			{
				g_warning ("Error loading icon: %s", error->message);
				g_error_free (error);
			}

			gtk_tree_store_set (tree->priv->store,
			                    &iter,
			                    ICON_COLUMN,
			                    pixbuf,
			                    -1);

			if (pixbuf)
			{
				g_object_unref (pixbuf);
			}

			gtk_icon_info_free (info);
		}

		g_strfreev (names);
	}

	if (icon)
	{
		g_object_unref (icon);
	}

	gtk_tree_store_set (tree->priv->store,
	                    &iter,
	                    NAME_COLUMN,
	                    line,
	                    -1);
	remove_dummy (tree);
}

static void
on_update (GitgShell              *shell,
           gchar                 **buffer,
           GitgRevisionFilesView  *tree)
{
	gchar *line;

	while ((line = *buffer++))
	{
		if (!tree->priv->skipped_blank_line)
		{
			if (*line == '\0')
			{
				tree->priv->skipped_blank_line = TRUE;
			}

			continue;
		}

		append_node (tree, line);
	}
}

static gint
compare_func (GtkTreeModel *model,
              GtkTreeIter *a,
              GtkTreeIter *b,
              GitgRevisionFilesView *self)
{
	// First sort directories before files
	gboolean da = gtk_tree_model_iter_has_child (model, a) != 0;
	gboolean db = gtk_tree_model_iter_has_child (model, b) != 0;

	if (da != db)
	{
		return da ? -1 : 1;
	}

	// Then sort on name
	gchar *s1;
	gchar *s2;

	gtk_tree_model_get (model,
	                    a,
	                    NAME_COLUMN,
	                    &s1,
	                    -1);

	gtk_tree_model_get (model,
	                    b,
	                    NAME_COLUMN,
	                    &s2,
	                    -1);

	int ret = gitg_utils_sort_names (s1, s2);

	g_free (s1);
	g_free (s2);

	return ret;
}

static void
on_contents_update (GitgShell              *shell,
                    gchar                 **buffer,
                    GitgRevisionFilesView  *tree)
{
	gchar *line;
	GtkTextBuffer *buf;
	GtkTextIter iter;

	buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW(tree->priv->contents));

	gtk_text_buffer_get_end_iter (buf, &iter);

	while ((line = *buffer++))
	{
		gtk_text_buffer_insert (buf, &iter, line, -1);
		gtk_text_buffer_insert (buf, &iter, "\n", -1);
	}

	if (gtk_source_buffer_get_language (GTK_SOURCE_BUFFER(buf)) == NULL)
	{
		gchar *content_type = gitg_utils_guess_content_type (buf);

		if (content_type && !gitg_utils_can_display_content_type (content_type))
		{
			gitg_io_cancel (GITG_IO (shell));
			show_binary_information (tree, buf);
		}
		else
		{
			GtkSourceLanguage *language;

			language = gitg_utils_get_language (NULL, content_type);
			gtk_source_buffer_set_language (GTK_SOURCE_BUFFER(buf),
			                                language);
		}

		g_free (content_type);
	}
}

/**
 * parse_blame:
 * @line: the line to be parsed
 * @real_line: the real connect to be inserted in the text buffer
 * @sha: the sha get from @line
 * @size: the size for the gutter
 */
static void
parse_blame (const gchar  *line,
             const gchar **real_line,
             gchar       **sha,
             gint         *size)
{
	gunichar c;
	const gchar *name_end;

	*sha = g_strndup (line, GITG_HASH_SHA_SIZE);
	line += GITG_HASH_SHA_SIZE;
	*real_line = strstr (line, ") ");
	*real_line += 2;

	line = strstr (line, " (");
	line += 2;
	name_end = line;
	c = g_utf8_get_char (name_end);

	while (!g_unichar_isdigit (c))
	{
		name_end = g_utf8_next_char (name_end);
		c = g_utf8_get_char (name_end);
	}
	name_end--;

	*size = name_end - line + 15; /* hash name + extra space */
}

static GtkTextTag *
get_tag_for_sha (GitgRevisionFilesView  *tree,
                 GtkTextBuffer          *buffer,
                 const gchar            *sha)
{
	GtkTextTag *tag;

	tag = g_hash_table_lookup (tree->priv->blames, sha);

	if (tag == NULL)
	{
		GitgHash hash;
		GitgRevision *revision;

		tag = gtk_text_buffer_create_tag (buffer, NULL, NULL);

		gitg_hash_sha1_to_hash (sha, hash);
		revision = gitg_repository_lookup (tree->priv->repository,
		                                   hash);
		g_object_set_data (G_OBJECT (tag), BLAME_DATA, revision);

		g_hash_table_insert (tree->priv->blames, g_strdup (sha),
		                     g_object_ref (tag));
	}

	return tag;
}

static void
apply_active_blame_tag (GitgRevisionFilesView *tree,
                        GtkTextBuffer         *buffer,
                        GtkTextIter           *end)
{
	GtkTextIter start;

	gtk_text_buffer_get_iter_at_offset (buffer, &start,
	                                    tree->priv->blame_offset);
	gtk_text_buffer_apply_tag (buffer, tree->priv->active_tag,
	                           &start, end);

	tree->priv->blame_offset = gtk_text_iter_get_offset (end);
}

static void
insert_blame_line (GitgRevisionFilesView  *tree,
                   GtkTextBuffer          *buffer,
                   const gchar            *line,
                   GtkTextIter            *iter)
{
	GtkTextTag *tag;
	const gchar *real_line;
	gint size;
	gchar *sha;

	parse_blame (line, &real_line, &sha, &size);
	gitg_blame_renderer_set_max_line_count (tree->priv->blame_renderer, size);

	tag = get_tag_for_sha (tree, buffer, sha);

	if (tag != tree->priv->active_tag)
	{
		if (tree->priv->active_tag != NULL)
		{
			apply_active_blame_tag (tree, buffer, iter);
		}

		tree->priv->active_tag = tag;
	}

	g_free (sha);

	gtk_text_buffer_insert (buffer, iter, real_line, -1);
	gtk_text_buffer_insert (buffer, iter, "\n", -1);
}

static void
on_blame_update (GitgShell              *shell,
                 gchar                 **buffer,
                 GitgRevisionFilesView  *tree)
{
	GtkTextBuffer *buf;
	GtkTextIter end;
	gchar *line;

	buf = gtk_text_view_get_buffer (GTK_TEXT_VIEW (tree->priv->blame_view));
	gtk_text_buffer_get_end_iter (buf, &end);

	while ((line = *buffer++))
	{
		insert_blame_line (tree, buf, line, &end);
	}

	if (tree->priv->active_tag != NULL)
	{
		apply_active_blame_tag (tree, buf, &end);
	}

	if (gtk_source_buffer_get_language (GTK_SOURCE_BUFFER (buf)) == NULL)
	{
		gchar *content_type = gitg_utils_guess_content_type (buf);

		if (content_type && !gitg_utils_can_display_content_type (content_type))
		{
			gitg_io_cancel (GITG_IO (shell));
			show_binary_information (tree, buf);
		}
		else
		{
			GtkSourceLanguage *language;

			language = gitg_utils_get_language (NULL, content_type);
			gtk_source_buffer_set_language (GTK_SOURCE_BUFFER (buf),
			                                language);
		}

		g_free (content_type);
	}
}

static void
on_blame_end (GitgShell              *shell,
              GError                 *error,
              GitgRevisionFilesView  *tree)
{
	GtkSourceGutter *gutter;

	tree->priv->query_data_id =
		g_signal_connect (tree->priv->blame_renderer,
		                  "query-data",
		                  G_CALLBACK (blame_renderer_query_data_cb),
		                  tree);

	tree->priv->query_tooltip_id =
		g_signal_connect (tree->priv->blame_renderer,
		                  "query-tooltip",
		                  G_CALLBACK (blame_renderer_query_tooltip_cb),
		                  tree);

	gutter = gtk_source_view_get_gutter (GTK_SOURCE_VIEW (tree->priv->blame_view),
	                                     GTK_TEXT_WINDOW_LEFT);
	gtk_source_gutter_queue_draw (gutter);
}

static void
gitg_revision_files_view_init (GitgRevisionFilesView *self)
{
	self->priv = GITG_REVISION_FILES_VIEW_GET_PRIVATE (self);
	self->priv->store = gtk_tree_store_new (N_COLUMNS,
	                                        GDK_TYPE_PIXBUF,
	                                        G_TYPE_STRING,
	                                        G_TYPE_STRING);

	gtk_tree_sortable_set_sort_func (GTK_TREE_SORTABLE (self->priv->store),
	                                 1,
	                                 (GtkTreeIterCompareFunc)compare_func,
	                                 self,
	                                 NULL);

	gtk_tree_sortable_set_sort_column_id (GTK_TREE_SORTABLE (self->priv->store),
	                                      NAME_COLUMN,
	                                      GTK_SORT_ASCENDING);

	self->priv->loader = gitg_shell_new (1000);
	g_signal_connect (self->priv->loader,
	                  "update",
	                  G_CALLBACK (on_update),
	                  self);

	self->priv->content_shell = gitg_shell_new (5000);
	g_signal_connect (self->priv->content_shell,
	                  "update",
	                  G_CALLBACK (on_contents_update),
	                  self);

	self->priv->blames = g_hash_table_new_full (g_str_hash,
	                                            g_str_equal,
	                                            g_free,
	                                            NULL);

	self->priv->blame_shell = gitg_shell_new (5000);
	g_signal_connect (self->priv->blame_shell,
	                  "update",
	                  G_CALLBACK (on_blame_update),
	                  self);
	g_signal_connect (self->priv->blame_shell,
	                  "end",
	                  G_CALLBACK (on_blame_end),
	                  self);
}

static void
gitg_revision_files_panel_init (GitgRevisionFilesPanel *self)
{
	self->priv = GITG_REVISION_FILES_PANEL_GET_PRIVATE (self);
}

static gchar *
node_identity (GitgRevisionFilesView *tree,
               GtkTreeIter          *parent)
{
	gchar *sha = gitg_revision_get_sha1 (tree->priv->revision);

	// Path consists of the SHA1 of the revision and the actual file path
	// from parent
	gchar *par = node_path (GTK_TREE_MODEL (tree->priv->store), parent);
	gchar *path = g_strconcat (sha, ":", par, NULL);
	g_free (sha);
	g_free (par);

	return path;
}

static void
load_node (GitgRevisionFilesView *tree,
           GtkTreeIter          *parent)
{
	if (gitg_io_get_running (GITG_IO (tree->priv->loader)))
	{
		return;
	}

	if (tree->priv->load_path)
	{
		gtk_tree_path_free (tree->priv->load_path);
	}

	gchar *id = node_identity (tree, parent);

	if (parent)
	{
		tree->priv->load_path =
			gtk_tree_model_get_path (GTK_TREE_MODEL (tree->priv->store),
			                         parent);
	}
	else
	{
		tree->priv->load_path = NULL;
	}

	tree->priv->skipped_blank_line = FALSE;
	gitg_shell_run (tree->priv->loader,
	                gitg_command_new (tree->priv->repository,
	                                   "show",
	                                   "--encoding=UTF-8",
	                                   id,
	                                   NULL),
	                NULL);
	g_free (id);
}
