/*
 * gitg-revision-details-panel.c
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


#include "gitg-revision-details-panel.h"
#include "gitg-utils.h"
#include "gitg-revision-panel.h"
#include "gitg-stat-view.h"

#include <glib/gi18n.h>
#include <stdlib.h>

#define GITG_REVISION_DETAILS_PANEL_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsPanelPrivate))

typedef struct
{
	gchar *file;
	guint added;
	guint removed;
} StatInfo;

struct _GitgRevisionDetailsPanelPrivate
{
	GtkLabel *sha;
	GtkLabel *author;
	GtkLabel *committer;
	GtkLabel *subject;
	GtkTable *parents;

	GtkWidget *panel_widget;
	GtkTextView *text_view;

	GtkBuilder *builder;

	GitgRepository *repository;
	GitgRevision *revision;

	GitgShell *shell;
	gboolean in_stat;

	GSList *stats;
	GitgWindow *window;
};

static void gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface);

static void set_revision (GitgRevisionDetailsPanel *panel,
                          GitgRepository           *repository,
                          GitgRevision             *revision);

G_DEFINE_TYPE_EXTENDED (GitgRevisionDetailsPanel,
                        gitg_revision_details_panel,
                        G_TYPE_OBJECT,
                        0,
                        G_IMPLEMENT_INTERFACE (GITG_TYPE_REVISION_PANEL,
                                               gitg_revision_panel_iface_init));

static void
update_markup (GObject *object)
{
	GtkLabel *label = GTK_LABEL(object);
	gchar const *text = gtk_label_get_text (label);

	gchar *newtext = g_strconcat ("<span weight='bold' foreground='#777'>",
	                              text,
	                              "</span>",
	                              NULL);

	gtk_label_set_markup (label, newtext);
	g_free (newtext);
}

static void
gitg_revision_panel_update_impl (GitgRevisionPanel *panel,
                                 GitgRepository    *repository,
                                 GitgRevision      *revision)
{
	GitgRevisionDetailsPanel *details_panel;

	details_panel = GITG_REVISION_DETAILS_PANEL (panel);

	set_revision (details_panel, repository, revision);
}

static gchar *
gitg_revision_panel_get_id_impl (GitgRevisionPanel *panel)
{
	return g_strdup ("details");
}

static gchar *
gitg_revision_panel_get_label_impl (GitgRevisionPanel *panel)
{
	return g_strdup (_("Details"));
}

static void
initialize_ui (GitgRevisionDetailsPanel *panel)
{
	GitgRevisionDetailsPanelPrivate *priv = panel->priv;

	priv->sha = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_sha"));
	priv->author = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_author"));
	priv->committer = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_committer"));
	priv->subject = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_subject"));
	priv->parents = GTK_TABLE (gtk_builder_get_object (priv->builder, "table_parents"));
	priv->text_view = GTK_TEXT_VIEW (gtk_builder_get_object (priv->builder, "text_view_details"));

	gchar const *lbls[] = {
		"label_subject_lbl",
		"label_author_lbl",
		"label_committer_lbl",
		"label_sha_lbl",
		"label_parent_lbl"
	};

	gint i;

	for (i = 0; i < sizeof (lbls) / sizeof (gchar *); ++i)
	{
		update_markup (gtk_builder_get_object (priv->builder, lbls[i]));
	}
}

static GtkWidget *
gitg_revision_panel_get_panel_impl (GitgRevisionPanel *panel)
{
	GtkBuilder *builder;
	GtkWidget *ret;
	GitgRevisionDetailsPanel *details_panel;

	details_panel = GITG_REVISION_DETAILS_PANEL (panel);

	if (details_panel->priv->panel_widget)
	{
		return details_panel->priv->panel_widget;
	}

	builder = gitg_utils_new_builder ("gitg-revision-details-panel.ui");
	details_panel->priv->builder = builder;

	ret = GTK_WIDGET (gtk_builder_get_object (builder, "revision_details_page"));
	details_panel->priv->panel_widget = ret;

	initialize_ui (details_panel);

	return ret;
}

static void
gitg_revision_panel_initialize_impl (GitgRevisionPanel *panel,
                                     GitgWindow        *window)
{
	GITG_REVISION_DETAILS_PANEL (panel)->priv->window = window;
}

static void
gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface)
{
	iface->initialize = gitg_revision_panel_initialize_impl;
	iface->get_id = gitg_revision_panel_get_id_impl;
	iface->update = gitg_revision_panel_update_impl;
	iface->get_label = gitg_revision_panel_get_label_impl;
	iface->get_panel = gitg_revision_panel_get_panel_impl;
}

static void
gitg_revision_details_panel_finalize (GObject *object)
{
	G_OBJECT_CLASS (gitg_revision_details_panel_parent_class)->finalize (object);
}

static void
gitg_revision_details_panel_dispose (GObject *object)
{
	GitgRevisionDetailsPanel *panel = GITG_REVISION_DETAILS_PANEL (object);

	set_revision (panel, NULL, NULL);

	if (panel->priv->builder)
	{
		g_object_unref (panel->priv->builder);
		panel->priv->builder = NULL;
	}

	if (panel->priv->shell)
	{
		gitg_io_cancel (GITG_IO (panel->priv->shell));
		g_object_unref (panel->priv->shell);

		panel->priv->shell = NULL;
	}

	G_OBJECT_CLASS (gitg_revision_details_panel_parent_class)->dispose (object);
}
static void
gitg_revision_details_panel_class_init (GitgRevisionDetailsPanelClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);

	object_class->finalize = gitg_revision_details_panel_finalize;
	object_class->dispose = gitg_revision_details_panel_dispose;

	g_type_class_add_private (object_class, sizeof (GitgRevisionDetailsPanelPrivate));
}

static void
on_shell_begin (GitgShell                *shell,
                GitgRevisionDetailsPanel *panel)
{
	GdkCursor *cursor;

	cursor = gdk_cursor_new (GDK_WATCH);
	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET (panel->priv->text_view)),
	                       cursor);

	panel->priv->in_stat = FALSE;

	gdk_cursor_unref (cursor);
}

static void
make_stats_table (GitgRevisionDetailsPanel *panel)
{
	guint num;
	GtkTable *table;
	GSList *item;
	guint i;
	guint max_lines = 0;
	GtkTextChildAnchor *anchor;
	GtkTextBuffer *buffer;
	GtkTextIter iter;
	gchar *path;
	gchar *repo_uri;
	gchar *sha1;
	GFile *work_tree;

	if (!panel->priv->stats)
	{
		return;
	}

	num = g_slist_length (panel->priv->stats);
	table = GTK_TABLE (gtk_table_new (num, 3, FALSE));
	gtk_table_set_row_spacings (table, 3);
	gtk_table_set_col_spacings (table, 6);

	for (item = panel->priv->stats; item; item = g_slist_next (item))
	{
		StatInfo *info = item->data;
		guint total = info->added + info->removed;

		if (total > max_lines)
		{
			max_lines = total;
		}
	}

	item = panel->priv->stats;
	work_tree = gitg_repository_get_work_tree (panel->priv->repository);
	path = g_file_get_path (work_tree);
	sha1 = gitg_revision_get_sha1 (panel->priv->revision);

	g_object_unref (work_tree);

	repo_uri = g_strdup_printf ("gitg://%s:%s", path, sha1);

	g_free (sha1);
	g_free (path);

	for (i = 0; i < num; ++i)
	{
		StatInfo *info = item->data;
		GtkWidget *view;
		GtkWidget *file;
		GtkWidget *total;
		GtkWidget *align;
		gchar *total_str;
		gchar *uri;

		view = gitg_stat_view_new (info->added,
		                           info->removed,
		                           max_lines);

		align = gtk_alignment_new (0, 0.5, 1, 0);
		gtk_widget_set_size_request (view, 300, 18);

		gtk_container_add (GTK_CONTAINER (align), view);

		uri = g_strdup_printf ("%s/changes/%s", repo_uri, info->file);

		file = gtk_link_button_new_with_label (uri,
		                                       info->file);

		g_free (uri);

		gtk_button_set_alignment (GTK_BUTTON (file),
		                          0,
		                          0.5);

		total_str = g_strdup_printf ("%d", info->added + info->removed);
		total = gtk_label_new (total_str);
		g_free (total_str);

		g_free (info->file);
		g_slice_free (StatInfo, info);

		gtk_table_attach (table, file,
		                  0, 1, i, i + 1,
		                  GTK_SHRINK | GTK_FILL, GTK_SHRINK | GTK_FILL,
		                  0, 0);

		gtk_table_attach (table, align,
		                  1, 2, i, i + 1,
		                  GTK_EXPAND | GTK_FILL, GTK_SHRINK | GTK_FILL,
		                  0, 0);

		gtk_table_attach (table, total,
		                  2, 3, i, i + 1,
		                  GTK_SHRINK | GTK_FILL, GTK_SHRINK | GTK_FILL,
		                  0, 0);

		gtk_widget_show (view);
		gtk_widget_show (file);
		gtk_widget_show (total);
		gtk_widget_show (align);

		item = g_slist_next (item);
	}

	gtk_widget_show (GTK_WIDGET (table));

	buffer = gtk_text_view_get_buffer (panel->priv->text_view);

	gtk_text_buffer_get_end_iter (buffer, &iter);
	gtk_text_buffer_insert (buffer, &iter, "\n\n", 2);

	anchor = gtk_text_buffer_create_child_anchor (buffer,
	                                              &iter);

	gtk_text_view_add_child_at_anchor (panel->priv->text_view,
	                                   GTK_WIDGET (table),
	                                   anchor);
}

static void
on_shell_end (GitgShell                *shell,
              gboolean                  cancelled,
              GitgRevisionDetailsPanel *panel)
{
	gdk_window_set_cursor (gtk_widget_get_window (GTK_WIDGET (panel->priv->text_view)),
	                       NULL);

	panel->priv->stats = g_slist_reverse (panel->priv->stats);

	make_stats_table (panel);

	g_slist_free (panel->priv->stats);
	panel->priv->stats = NULL;
}

static void
strip_trailing_newlines (GtkTextBuffer *buffer)
{
	GtkTextIter iter;
	GtkTextIter end;

	gtk_text_buffer_get_end_iter (buffer, &iter);

	if (!gtk_text_iter_starts_line (&iter))
	{
		return;
	}

	while (!gtk_text_iter_is_start (&iter) &&
	        gtk_text_iter_ends_line (&iter))
	{
		if (!gtk_text_iter_backward_line (&iter))
		{
			break;
		}
	}

	gtk_text_iter_forward_to_line_end (&iter);

	gtk_text_buffer_get_end_iter (buffer, &end);
	gtk_text_buffer_delete (buffer, &iter, &end);
}

static void
add_stat (GitgRevisionDetailsPanel *panel,
          gchar const              *line)
{
	gchar **parts;

	parts = g_strsplit_set (line, "\t ", -1);

	if (g_strv_length (parts) == 3)
	{
		StatInfo *stat;

		stat = g_slice_new (StatInfo);

		stat->added = (guint)atoi (parts[0]);
		stat->removed = (guint)atoi (parts[1]);
		stat->file = g_strdup (parts[2]);

		panel->priv->stats = g_slist_prepend (panel->priv->stats,
		                                      stat);
	}

	g_strfreev (parts);
}

static void
on_shell_update (GitgShell                 *shell,
                 gchar                    **lines,
                 GitgRevisionDetailsPanel  *panel)
{
	GtkTextBuffer *buffer;
	GtkTextIter end;

	buffer = gtk_text_view_get_buffer (panel->priv->text_view);
	gtk_text_buffer_get_end_iter (buffer, &end);

	while (lines && *lines)
	{
		gchar const *line = *lines;
		++lines;

		if (panel->priv->in_stat)
		{
			add_stat (panel, line);
		}
		else
		{
			if (!gtk_text_iter_is_start (&end))
			{
				gtk_text_buffer_insert (buffer, &end, "\n", 1);
			}

			if (line[0] == '\x01' && !line[1])
			{
				panel->priv->in_stat = TRUE;
				strip_trailing_newlines (buffer);
			}
			else
			{
				gtk_text_buffer_insert (buffer, &end, line, -1);
			}
		}
	}
}

static void
gitg_revision_details_panel_init (GitgRevisionDetailsPanel *self)
{
	self->priv = GITG_REVISION_DETAILS_PANEL_GET_PRIVATE(self);

	self->priv->shell = gitg_shell_new (1000);

	g_signal_connect (self->priv->shell,
	                  "begin",
	                  G_CALLBACK (on_shell_begin),
	                  self);

	g_signal_connect (self->priv->shell,
	                  "end",
	                  G_CALLBACK (on_shell_end),
	                  self);

	g_signal_connect (self->priv->shell,
	                  "update",
	                  G_CALLBACK (on_shell_update),
	                  self);
}

#define HASH_KEY "GitgRevisionDetailsPanelHashKey"

static gboolean
on_parent_clicked (GtkWidget      *ev,
                   GdkEventButton *event,
                   gpointer        userdata)
{
	GitgRevisionDetailsPanel *panel;
	gchar *hash;

	if (event->button != 1)
	{
		return FALSE;
	}

	panel = GITG_REVISION_DETAILS_PANEL (userdata);
	hash = (gchar *)g_object_get_data (G_OBJECT (ev), HASH_KEY);

	gitg_window_select (panel->priv->window, hash);
	return FALSE;
}

static GtkWidget *
make_parent_label (GitgRevisionDetailsPanel *self,
                   gchar const              *sha1)
{
	GtkWidget *ev = gtk_event_box_new ();
	GtkWidget *lbl = gtk_label_new (NULL);

	gchar *markup = g_strconcat ("<span underline='single' foreground='#00f'>",
	                             sha1,
	                             "</span>",
	                             NULL);

	gtk_label_set_markup (GTK_LABEL(lbl), markup);
	g_free (markup);

	gtk_misc_set_alignment (GTK_MISC(lbl), 0.0, 0.5);
	gtk_container_add (GTK_CONTAINER(ev), lbl);

	gtk_widget_show (ev);
	gtk_widget_show (lbl);

	g_object_set_data_full (G_OBJECT(ev),
	                        HASH_KEY,
	                        g_strdup (sha1),
	                        (GDestroyNotify)g_free);

	g_signal_connect (ev,
	                  "button-release-event",
	                  G_CALLBACK(on_parent_clicked),
	                  self);

	return ev;
}

static void
update_parents (GitgRevisionDetailsPanel *self)
{
	GList *children;
	GList *item;

	children = gtk_container_get_children (GTK_CONTAINER (self->priv->parents));

	for (item = children; item; item = g_list_next (item))
	{
		gtk_container_remove (GTK_CONTAINER (self->priv->parents),
		                      GTK_WIDGET (item->data));
	}

	g_list_free (children);

	if (!self->priv->revision)
	{
		return;
	}

	gchar **parents = gitg_revision_get_parents (self->priv->revision);
	gint num = g_strv_length (parents);
	gint i;

	gtk_table_resize (self->priv->parents, num ? num : num + 1, 2);
	GdkCursor *cursor = gdk_cursor_new (GDK_HAND1);
	GitgHash hash;

	for (i = 0; i < num; ++i)
	{
		GtkWidget *widget = make_parent_label (self, parents[i]);
		gtk_table_attach (self->priv->parents,
		                  widget,
		                  0,
		                  1,
		                  i,
		                  i + 1,
		                  GTK_FILL | GTK_SHRINK,
		                  GTK_FILL | GTK_SHRINK,
		                  0,
		                  0);

		gtk_widget_realize (widget);
		gdk_window_set_cursor (gtk_widget_get_window (widget), cursor);

		/* find subject */
		gitg_hash_sha1_to_hash (parents[i], hash);

		GitgRevision *revision;

		revision = gitg_repository_lookup (self->priv->repository, hash);

		if (revision)
		{
			GtkWidget *subject = gtk_label_new (NULL);

			gchar *text;

			text = g_markup_printf_escaped (": <i>%s</i>",
			                                gitg_revision_get_subject (revision));

			gtk_label_set_markup (GTK_LABEL(subject), text);

			g_free (text);

			gtk_widget_show (subject);

			gtk_misc_set_alignment (GTK_MISC(subject), 0.0, 0.5);
			gtk_label_set_ellipsize (GTK_LABEL(subject), PANGO_ELLIPSIZE_END);
			gtk_label_set_single_line_mode (GTK_LABEL(subject), TRUE);

			gtk_table_attach (self->priv->parents,
			                  subject,
			                  1,
			                  2,
			                  i,
			                  i + 1,
			                  GTK_FILL | GTK_EXPAND,
			                  GTK_FILL | GTK_SHRINK,
			                  0,
			                  0);
		}
	}

	gdk_cursor_unref (cursor);
	g_strfreev (parents);
}

static void
update_details (GitgRevisionDetailsPanel *panel)
{
	gchar *sha1;

	gitg_io_cancel (GITG_IO (panel->priv->shell));

	gtk_text_buffer_set_text (gtk_text_view_get_buffer (panel->priv->text_view),
	                          "",
	                          0);

	if (!panel->priv->revision)
	{
		return;
	}

	sha1 = gitg_revision_get_sha1 (panel->priv->revision);

	gitg_shell_run (panel->priv->shell,
	                gitg_command_new (panel->priv->repository,
	                                   "show",
	                                   "--numstat",
	                                   "--pretty=format:%s%n%n%b%n\x01",
	                                   sha1,
	                                   NULL),
	                NULL);

	g_free (sha1);
}

static void
reload (GitgRevisionDetailsPanel *panel)
{
	GtkClipboard *cb;

	// Update labels
	if (panel->priv->revision)
	{
		gchar *tmp;
		gchar *date;

		date = gitg_revision_get_author_date_for_display (panel->priv->revision);
		tmp = g_markup_printf_escaped ("<a href='mailto:%s'>%s &lt;%s&gt;</a> (%s)",
		                               gitg_revision_get_author_email (panel->priv->revision),
		                               gitg_revision_get_author (panel->priv->revision),
		                               gitg_revision_get_author_email (panel->priv->revision),
		                               date);

		gtk_label_set_markup (panel->priv->author, tmp);

		g_free (tmp);
		g_free (date);

		date = gitg_revision_get_committer_date_for_display (panel->priv->revision);
		tmp = g_markup_printf_escaped ("<a href='mailto:%s'>%s &lt;%s&gt;</a> (%s)",
		                               gitg_revision_get_committer_email (panel->priv->revision),
		                               gitg_revision_get_committer (panel->priv->revision),
		                               gitg_revision_get_committer_email (panel->priv->revision),
		                               date);

		gtk_label_set_markup (panel->priv->committer, tmp);

		g_free (tmp);
		g_free (date);

		gchar *subject;

		subject = g_markup_printf_escaped ("<b>%s</b>",
		                                   gitg_revision_get_subject (panel->priv->revision));

		gtk_label_set_markup (panel->priv->subject, subject);
		g_free (subject);

		gchar *sha = gitg_revision_get_sha1 (panel->priv->revision);
		gtk_label_set_text (panel->priv->sha, sha);

		cb = gtk_clipboard_get (GDK_SELECTION_PRIMARY);
		gtk_clipboard_set_text (cb, sha, -1);

		g_free (sha);
	}
	else
	{
		gtk_label_set_text (panel->priv->author, "");
		gtk_label_set_text (panel->priv->committer, "");
		gtk_label_set_text (panel->priv->subject, "");
		gtk_label_set_text (panel->priv->sha, "");
	}

	// Update parents
	update_parents (panel);
	update_details (panel);
}

static void
set_revision (GitgRevisionDetailsPanel *panel,
              GitgRepository           *repository,
              GitgRevision             *revision)
{
	if (panel->priv->repository == repository &&
	    panel->priv->revision == revision)
	{
		return;
	}

	if (panel->priv->repository)
	{
		g_object_unref (panel->priv->repository);
	}

	if (panel->priv->revision)
	{
		gitg_revision_unref (panel->priv->revision);
	}

	if (repository)
	{
		panel->priv->repository = g_object_ref (repository);
	}
	else
	{
		panel->priv->repository = NULL;
	}

	if (revision)
	{
		panel->priv->revision = gitg_revision_ref (revision);
	}
	else
	{
		panel->priv->revision = NULL;
	}

	reload (panel);
}
