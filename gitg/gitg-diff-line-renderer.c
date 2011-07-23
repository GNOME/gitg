/*
 * gitg-diff-line-renderer.h
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

#include "gitg-utils.h"
#include "gitg-diff-line-renderer.h"

#define GITG_DIFF_LINE_RENDERER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRendererPrivate))

/* Properties */
enum
{
	PROP_0,
	PROP_LINE_OLD,
	PROP_LINE_NEW
};

struct _GitgDiffLineRendererPrivate
{
	gint line_old;
	gint line_new;
	gint num_digits;

	PangoLayout *cached_layout;
	PangoAttribute *fg_attr;
	PangoAttrList *cached_attr_list;

	glong changed_handler_id;
};

G_DEFINE_TYPE (GitgDiffLineRenderer, gitg_diff_line_renderer, GTK_SOURCE_TYPE_GUTTER_RENDERER)

static void
gitg_diff_line_renderer_set_property (GObject      *object,
                                      guint         prop_id,
                                      const GValue *value,
                                      GParamSpec   *pspec)
{
	GitgDiffLineRenderer *self = GITG_DIFF_LINE_RENDERER (object);
	
	switch (prop_id)
	{
		case PROP_LINE_OLD:
			self->priv->line_old = g_value_get_int (value);
		break;
		case PROP_LINE_NEW:
			self->priv->line_new = g_value_get_int (value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_line_renderer_get_property (GObject    *object,
                                      guint       prop_id,
                                      GValue     *value,
                                      GParamSpec *pspec)
{
	GitgDiffLineRenderer *self = GITG_DIFF_LINE_RENDERER (object);
	
	switch (prop_id)
	{
		case PROP_LINE_OLD:
			g_value_set_int (value, self->priv->line_old);
		break;
		case PROP_LINE_NEW:
			g_value_set_int (value, self->priv->line_new);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
create_layout (GitgDiffLineRenderer *renderer,
               GtkWidget            *widget)
{
	PangoLayout *layout;
	PangoAttribute *attr;
	GtkStyleContext *context;
	GdkRGBA color;
	PangoAttrList *attr_list;

	layout = gtk_widget_create_pango_layout (widget, NULL);

	context = gtk_widget_get_style_context (widget);
	gtk_style_context_get_color (context, GTK_STATE_FLAG_NORMAL, &color);

	attr = pango_attr_foreground_new (color.red * 65535,
	                                  color.green * 65535,
	                                  color.blue * 65535);

	attr->start_index = 0;
	attr->end_index = G_MAXINT;

	attr_list = pango_attr_list_new ();
	pango_attr_list_insert (attr_list, attr);

	renderer->priv->fg_attr = attr;
	renderer->priv->cached_layout = layout;
	renderer->priv->cached_attr_list = attr_list;
}

static void
gitg_diff_line_renderer_begin (GtkSourceGutterRenderer      *renderer,
                               cairo_t                      *cr,
                               GdkRectangle                 *background_area,
                               GdkRectangle                 *cell_area,
                               GtkTextIter                  *start,
                               GtkTextIter                  *end)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);

	create_layout (lr, GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer)));
}

static void
gitg_diff_line_renderer_draw (GtkSourceGutterRenderer      *renderer,
                              cairo_t                      *ctx,
                              GdkRectangle                 *background_area,
                              GdkRectangle                 *cell_area,
                              GtkTextIter                  *start,
                              GtkTextIter                  *end,
                              GtkSourceGutterRendererState  renderer_state)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);
	gchar old_str[16];
	gchar new_str[16];
	PangoLayout *layout;
	GtkWidget *widget;
	GtkStyleContext *style_context;
	guint xpad = 0;

	/* Chain up to draw background */
	GTK_SOURCE_GUTTER_RENDERER_CLASS (
		gitg_diff_line_renderer_parent_class)->draw (renderer,
		                                             ctx,
		                                             background_area,
		                                             cell_area,
		                                             start,
		                                             end,
		                                             renderer_state);

	widget = GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer));
	layout = lr->priv->cached_layout;

	pango_layout_set_width (layout, cell_area->width / 2);

	pango_layout_set_alignment (layout, PANGO_ALIGN_RIGHT);

	if (lr->priv->line_old >= 0)
	{
		g_snprintf (old_str, sizeof (old_str), "%d", lr->priv->line_old);
	}
	else
	{
		*old_str = '\0';
	}

	if (lr->priv->line_new >= 0)
	{
		g_snprintf (new_str, sizeof (old_str), "%d", lr->priv->line_new);
	}
	else
	{
		*new_str = '\0';
	}

	g_object_get (renderer, "xpad", &xpad, NULL);

	pango_layout_set_text (layout, old_str, -1);
	style_context = gtk_widget_get_style_context (widget);

	gtk_render_layout (style_context,
	                   ctx,
	                   cell_area->x + cell_area->width / 2 - xpad,
	                   cell_area->y,
	                   layout);

	pango_layout_set_text (layout, new_str, -1);
	gtk_render_layout (style_context,
	                   ctx,
	                   cell_area->x + cell_area->width,
	                   cell_area->y,
	                   layout);

	gtk_render_line (style_context,
	                 ctx,
	                 background_area->x + background_area->width / 2,
	                 background_area->y - 1,
	                 background_area->x + background_area->width / 2,
	                 background_area->y + background_area->height);
}

static void
gitg_diff_line_renderer_end (GtkSourceGutterRenderer *renderer)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);

	g_object_unref (lr->priv->cached_layout);
	lr->priv->cached_layout = NULL;

	pango_attr_list_unref (lr->priv->cached_attr_list);
	lr->priv->cached_attr_list = NULL;

	lr->priv->fg_attr = NULL;
}

static void
measure_text (GitgDiffLineRenderer *lr,
              const gchar          *markup,
              const gchar          *text,
              gint                 *width,
              gint                 *height)
{
	PangoLayout *layout;
	gint w;
	gint h;
	GtkSourceGutterRenderer *r;
	GtkTextView *view;

	r = GTK_SOURCE_GUTTER_RENDERER (lr);
	view = gtk_source_gutter_renderer_get_view (r);

	layout = gtk_widget_create_pango_layout (GTK_WIDGET (view), NULL);

	if (markup)
	{
		pango_layout_set_markup (layout,
		                         markup,
		                         -1);
	}
	else
	{
		pango_layout_set_text (layout,
		                       text,
		                       -1);
	}

	pango_layout_get_size (layout, &w, &h);

	if (width)
	{
		*width = w / PANGO_SCALE;
	}

	if (height)
	{
		*height = h / PANGO_SCALE;
	}

	g_object_unref (layout);
}

static void
recalculate_size (GitgDiffLineRenderer *lr)
{
	gchar *markup;
	gint size;
	gint num = 1;
	gint i;

	for (i = 1; i < lr->priv->num_digits; ++i)
	{
		num *= 10;
	}

	markup = g_strdup_printf ("<b>%d %d</b>",
	                          num,
	                          num);

	measure_text (lr, markup, NULL, &size, NULL);
	g_free (markup);

	gtk_source_gutter_renderer_set_size (GTK_SOURCE_GUTTER_RENDERER (lr),
	                                     size);
}

static void
update_num_digits (GitgDiffLineRenderer *renderer,
                   guint                 max_line_count)
{
	/* Get size of this rendering */
	gint num_digits;

	num_digits = 0;

	while (max_line_count > 0)
	{
		max_line_count /= 10;
		++num_digits;
	}

	num_digits = MAX (num_digits, 2);

	if (num_digits != renderer->priv->num_digits)
	{
		renderer->priv->num_digits = num_digits;
		recalculate_size (renderer);
	}
}

static void
gitg_diff_line_renderer_class_init (GitgDiffLineRendererClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GtkSourceGutterRendererClass *renderer_class = GTK_SOURCE_GUTTER_RENDERER_CLASS (klass);

	renderer_class->begin = gitg_diff_line_renderer_begin;
	renderer_class->draw = gitg_diff_line_renderer_draw;
	renderer_class->end= gitg_diff_line_renderer_end;

	object_class->set_property = gitg_diff_line_renderer_set_property;
	object_class->get_property = gitg_diff_line_renderer_get_property;

	g_object_class_install_property (object_class,
	                                 PROP_LINE_OLD,
	                                 g_param_spec_int ("line-old",
	                                                   "Line Old",
	                                                   "Line Old",
	                                                   -1,
	                                                   G_MAXINT,
	                                                   -1,
	                                                   G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_LINE_NEW,
	                                 g_param_spec_int ("line-new",
	                                                   "Line New",
	                                                   "Line New",
	                                                   -1,
	                                                   G_MAXINT,
	                                                   -1,
	                                                   G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_type_class_add_private (object_class, sizeof (GitgDiffLineRendererPrivate));
}

static void
gitg_diff_line_renderer_init (GitgDiffLineRenderer *self)
{
	self->priv = GITG_DIFF_LINE_RENDERER_GET_PRIVATE (self);
}

GitgDiffLineRenderer *
gitg_diff_line_renderer_new ()
{
	return g_object_new (GITG_TYPE_DIFF_LINE_RENDERER, NULL);
}

void
gitg_diff_line_renderer_set_max_line_count (GitgDiffLineRenderer *renderer,
                                            guint                 max_line_count)
{
	g_return_if_fail (GITG_IS_DIFF_LINE_RENDERER (renderer));

	update_num_digits (renderer, max_line_count);
}
