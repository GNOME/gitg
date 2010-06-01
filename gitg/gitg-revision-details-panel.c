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

#include <glib/gi18n.h>

#define GITG_REVISION_DETAILS_PANEL_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsPanelPrivate))

struct _GitgRevisionDetailsPanelPrivate
{
	GtkLabel *sha;
	GtkLabel *author;
	GtkLabel *date;
	GtkLabel *subject;
	GtkTable *parents;

	GtkWidget *panel_widget;
	GtkBuilder *builder;

	GitgRepository *repository;
	GitgRevision *revision;
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
	priv->date = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_date"));
	priv->subject = GTK_LABEL (gtk_builder_get_object (priv->builder, "label_subject"));
	priv->parents = GTK_TABLE (gtk_builder_get_object (priv->builder, "table_parents"));

	gchar const *lbls[] = {
		"label_subject_lbl",
		"label_author_lbl",
		"label_sha_lbl",
		"label_date_lbl",
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
gitg_revision_panel_iface_init (GitgRevisionPanelInterface *iface)
{
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
gitg_revision_details_panel_init (GitgRevisionDetailsPanel *self)
{
	self->priv = GITG_REVISION_DETAILS_PANEL_GET_PRIVATE(self);

}

#define HASH_KEY "GitgRevisionDetailsPanelHashKey"

static gboolean
on_parent_clicked (GtkWidget      *ev,
                   GdkEventButton *event,
                   gpointer        userdata)
{
	if (event->button != 1)
	{
		return FALSE;
	}

	//GitgRevisionDetailsPanel *panel = GITG_REVISION_DETAILS_PANEL (userdata);
	//gchar *hash = (gchar *)g_object_get_data (G_OBJECT(ev), HASH_KEY);

	// TODO: do something

	return FALSE;
}

static GtkWidget *
make_parent_label (GitgRevisionDetailsPanel *self,
                   gchar const              *hash)
{
	GtkWidget *ev = gtk_event_box_new ();
	GtkWidget *lbl = gtk_label_new (NULL);

	gchar *markup = g_strconcat ("<span underline='single' foreground='#00f'>",
	                             hash,
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
	                        (gpointer)gitg_hash_sha1_to_hash_new (hash),
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
reload (GitgRevisionDetailsPanel *panel)
{
	GtkClipboard *cb;

	// Update labels
	if (panel->priv->revision)
	{
		gtk_label_set_text (panel->priv->author,
		                    gitg_revision_get_author (panel->priv->revision));

		gchar *subject;

		subject = g_markup_printf_escaped ("<b>%s</b>",
		                                   gitg_revision_get_subject (panel->priv->revision));

		gtk_label_set_markup (panel->priv->subject, subject);
		g_free (subject);

		gchar *date = gitg_revision_get_timestamp_for_display (panel->priv->revision);
		gtk_label_set_text (panel->priv->date, date);
		g_free (date);

		gchar *sha = gitg_revision_get_sha1 (panel->priv->revision);
		gtk_label_set_text (panel->priv->sha, sha);

		cb = gtk_clipboard_get (GDK_SELECTION_PRIMARY);
		gtk_clipboard_set_text (cb, sha, -1);

		g_free (sha);
	}
	else
	{
		gtk_label_set_text (panel->priv->author, "");
		gtk_label_set_text (panel->priv->subject, "");
		gtk_label_set_text (panel->priv->date, "");
		gtk_label_set_text (panel->priv->sha, "");
	}

	// Update parents
	update_parents (panel);
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
