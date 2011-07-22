/*
 * gitg-blame-renderer.c
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2011 - Ignacio Casal Quinteiro
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

#include "gitg-blame-renderer.h"

#include <libgitg/gitg-revision.h>
#include <glib/gi18n.h>
#include <gtk/gtk.h>

#define GITG_BLAME_RENDERER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_BLAME_RENDERER, GitgBlameRendererPrivate))

/* Properties */
enum
{
	PROP_0,
	PROP_REVISION,
	PROP_SHOW,
	PROP_GROUP_START
};

struct _GitgBlameRendererPrivate
{
	GitgRevision *revision;
	gint max_line;
	gboolean group_start;
	gboolean show;

	gchar *line_number;

	PangoLayout *cached_layout;
	PangoLayout *line_layout;
};

G_DEFINE_TYPE (GitgBlameRenderer, gitg_blame_renderer, GTK_SOURCE_TYPE_GUTTER_RENDERER)

static void
gitg_blame_renderer_set_property (GObject      *object,
                                  guint         prop_id,
                                  const GValue *value,
                                  GParamSpec   *pspec)
{
	GitgBlameRenderer *self = GITG_BLAME_RENDERER (object);
	
	switch (prop_id)
	{
		case PROP_REVISION:
			self->priv->revision = g_value_get_boxed (value);
		break;
		case PROP_SHOW:
			self->priv->show = g_value_get_boolean (value);
		break;
		case PROP_GROUP_START:
			self->priv->group_start = g_value_get_boolean (value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_blame_renderer_get_property (GObject    *object,
                                  guint       prop_id,
                                  GValue     *value,
                                  GParamSpec *pspec)
{
	GitgBlameRenderer *self = GITG_BLAME_RENDERER (object);
	
	switch (prop_id)
	{
		case PROP_REVISION:
			g_value_set_boxed (value, self->priv->revision);
		break;
		case PROP_SHOW:
			g_value_set_boolean (value, self->priv->show);
		break;
		case PROP_GROUP_START:
			g_value_set_boolean (value, self->priv->group_start);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_blame_renderer_finalize (GObject *object)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (object);

	g_free (br->priv->line_number);

	G_OBJECT_CLASS (gitg_blame_renderer_parent_class)->finalize (object);
}

static void
gitg_blame_renderer_begin (GtkSourceGutterRenderer      *renderer,
                           cairo_t                      *cr,
                           GdkRectangle                 *background_area,
                           GdkRectangle                 *cell_area,
                           GtkTextIter                  *start,
                           GtkTextIter                  *end)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);

	br->priv->cached_layout = gtk_widget_create_pango_layout (GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer)),
	                                                          NULL);
	br->priv->line_layout = gtk_widget_create_pango_layout (GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer)),
	                                                        NULL);
}

static void
render_blame (GtkSourceGutterRenderer      *renderer,
              cairo_t                      *ctx,
              GdkRectangle                 *background_area,
              GdkRectangle                 *cell_area,
              GtkTextIter                  *start,
              GtkTextIter                  *end,
              GtkSourceGutterRendererState  renderer_state)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);
	gchar *text;
	PangoLayout *layout;
	GtkWidget *widget;
	GtkStyleContext *style_context;
	gchar *sha1;
	gchar short_sha1[9];

	widget = GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer));
	layout = br->priv->cached_layout;

	pango_layout_set_width (layout, -1);

	sha1 = gitg_revision_get_sha1 (br->priv->revision);
	strncpy (short_sha1, sha1, 8);
	short_sha1[8] = '\0';
	g_free (sha1);

	text = g_strdup_printf ("<b>%s</b> %s", short_sha1,
	                        gitg_revision_get_author (br->priv->revision));

	pango_layout_set_markup (layout, text, -1);
	g_free (text);
	style_context = gtk_widget_get_style_context (widget);

	if (br->priv->group_start)
	{
		GdkRGBA bg_color;

		gtk_style_context_get_background_color (style_context, GTK_STATE_INSENSITIVE, &bg_color);
		gdk_cairo_set_source_rgba (ctx, &bg_color);

		cairo_save (ctx);
		cairo_move_to (ctx, background_area->x, background_area->y);
		cairo_line_to (ctx, background_area->x + background_area->width,
		               cell_area->y);
		cairo_stroke (ctx);
		cairo_restore (ctx);
	}

	gtk_render_layout (style_context,
	                   ctx,
	                   cell_area->x,
	                   cell_area->y,
	                   layout);
}

static void
render_line (GtkSourceGutterRenderer      *renderer,
             cairo_t                      *ctx,
             GdkRectangle                 *background_area,
             GdkRectangle                 *cell_area,
             GtkTextIter                  *start,
             GtkTextIter                  *end,
             GtkSourceGutterRendererState  renderer_state)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);
	PangoLayout *layout;
	GtkWidget *widget;
	GtkStyleContext *style_context;
	gint width, height;

	widget = GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer));
	layout = br->priv->line_layout;

	pango_layout_set_markup (layout, br->priv->line_number, -1);
	pango_layout_get_size (layout, &width, &height);

	style_context = gtk_widget_get_style_context (widget);

	width /= PANGO_SCALE;

	gtk_render_layout (style_context,
	                   ctx,
	                   cell_area->x + cell_area->width - width - 5,
	                   cell_area->y,
	                   layout);
}

static void
gitg_blame_renderer_draw (GtkSourceGutterRenderer      *renderer,
                          cairo_t                      *ctx,
                          GdkRectangle                 *background_area,
                          GdkRectangle                 *cell_area,
                          GtkTextIter                  *start,
                          GtkTextIter                  *end,
                          GtkSourceGutterRendererState  renderer_state)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);

	/* Chain up to draw background */
	GTK_SOURCE_GUTTER_RENDERER_CLASS (
		gitg_blame_renderer_parent_class)->draw (renderer,
		                                         ctx,
		                                         background_area,
		                                         cell_area,
		                                         start,
		                                         end,
		                                         renderer_state);

	if (br->priv->show && br->priv->revision != NULL)
	{
		render_blame (renderer,
		              ctx,
		              background_area,
		              cell_area,
		              start,
		              end,
		              renderer_state);
	}

	render_line (renderer,
	             ctx,
	             background_area,
	             cell_area,
	             start,
	             end,
	             renderer_state);
}

static void
gitg_blame_renderer_end (GtkSourceGutterRenderer *renderer)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);

	g_object_unref (br->priv->cached_layout);
	br->priv->cached_layout = NULL;

	g_object_unref (br->priv->line_layout);
	br->priv->line_layout = NULL;
}

static void
gutter_renderer_query_data (GtkSourceGutterRenderer      *renderer,
                            GtkTextIter                  *start,
                            GtkTextIter                  *end,
                            GtkSourceGutterRendererState  state)
{
	GitgBlameRenderer *br = GITG_BLAME_RENDERER (renderer);
	gchar *text;
	gint line;
	gboolean current_line;

	line = gtk_text_iter_get_line (start) + 1;

	current_line = (state & GTK_SOURCE_GUTTER_RENDERER_STATE_CURSOR) &&
	                gtk_text_view_get_cursor_visible (gtk_source_gutter_renderer_get_view (renderer));

	if (current_line)
	{
		text = g_strdup_printf ("<b>%d</b>", line);
	}
	else
	{
		text = g_strdup_printf ("%d", line);
	}

	g_free (br->priv->line_number);
	br->priv->line_number = text;
}

static void
measure_text (GitgBlameRenderer *br,
              const gchar       *markup,
              gint              *width)
{
	PangoLayout *layout;
	gint w;
	gint h;
	GtkSourceGutterRenderer *r;
	GtkTextView *view;

	r = GTK_SOURCE_GUTTER_RENDERER (br);
	view = gtk_source_gutter_renderer_get_view (r);

	layout = gtk_widget_create_pango_layout (GTK_WIDGET (view), NULL);

	pango_layout_set_markup (layout,
	                         markup,
	                         -1);

	pango_layout_get_size (layout, &w, &h);

	if (width)
	{
		*width = w / PANGO_SCALE;
	}

	g_object_unref (layout);
}

static GtkTextBuffer *
get_buffer (GitgBlameRenderer *renderer)
{
	GtkTextView *view;

	view = gtk_source_gutter_renderer_get_view (GTK_SOURCE_GUTTER_RENDERER (renderer));

	return gtk_text_view_get_buffer (view);
}

static void
recalculate_size (GitgBlameRenderer *br)
{
	GtkTextBuffer *buffer;
	gchar *markup;
	gint size;
	gchar *text;
	gint num, num_digits, i;

	buffer = get_buffer (br);

	num = gtk_text_buffer_get_line_count (buffer);
	num_digits = 0;

	while (num > 0)
	{
		num /= 10;
		++num_digits;
	}

	num_digits = MAX (num_digits, 2);

	text = g_new (gchar, br->priv->max_line + num_digits + 1);
	for (i = 0; i < br->priv->max_line + num_digits; i++)
	{
		text[i] = '0';
	}
	text[br->priv->max_line + num_digits] = '\0';

	markup = g_strdup_printf ("<b>%s</b>", text);
	g_free (text);

	measure_text (br, markup, &size);
	g_free (markup);

	gtk_source_gutter_renderer_set_size (GTK_SOURCE_GUTTER_RENDERER (br),
	                                     size);
}

static void
update_num_digits (GitgBlameRenderer *renderer,
                   gint               max_line)
{
	max_line = MAX (max_line, 2);

	if (max_line != renderer->priv->max_line)
	{
		renderer->priv->max_line = max_line;
		recalculate_size (renderer);
	}
}

static void
gitg_blame_renderer_class_init (GitgBlameRendererClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GtkSourceGutterRendererClass *renderer_class = GTK_SOURCE_GUTTER_RENDERER_CLASS (klass);

	renderer_class->begin = gitg_blame_renderer_begin;
	renderer_class->draw = gitg_blame_renderer_draw;
	renderer_class->end= gitg_blame_renderer_end;
	renderer_class->query_data = gutter_renderer_query_data;

	object_class->set_property = gitg_blame_renderer_set_property;
	object_class->get_property = gitg_blame_renderer_get_property;
	object_class->finalize = gitg_blame_renderer_finalize;

	g_object_class_install_property (object_class,
	                                 PROP_REVISION,
	                                 g_param_spec_boxed ("revision",
	                                                     "Revision",
	                                                     "Revision",
	                                                     GITG_TYPE_REVISION,
	                                                     G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_SHOW,
	                                 g_param_spec_boolean ("show",
	                                                       "Show",
	                                                       "Show",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_GROUP_START,
	                                 g_param_spec_boolean ("group-start",
	                                                       "Group Start",
	                                                       "Group start",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_type_class_add_private (object_class, sizeof (GitgBlameRendererPrivate));
}

static void
gitg_blame_renderer_init (GitgBlameRenderer *self)
{
	self->priv = GITG_BLAME_RENDERER_GET_PRIVATE (self);
}

GitgBlameRenderer *
gitg_blame_renderer_new (void)
{
	return g_object_new (GITG_TYPE_BLAME_RENDERER, NULL);
}

void
gitg_blame_renderer_set_max_line_count (GitgBlameRenderer *renderer,
                                        gint               max_line)
{
	g_return_if_fail (GITG_IS_BLAME_RENDERER (renderer));

	update_num_digits (renderer, max_line);
}
