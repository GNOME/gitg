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
	PROP_LINE_NEW,
	PROP_LABEL
};

struct _GitgDiffLineRendererPrivate
{
	gint line_old;
	gint line_new;
	gchar *label;
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
		case PROP_LABEL:
			g_free (self->priv->label);
			self->priv->label = g_value_dup_string (value);
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
		case PROP_LABEL:
			g_value_set_string (value, self->priv->label);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_line_renderer_finalize (GObject *object)
{
	GitgDiffLineRenderer *self = GITG_DIFF_LINE_RENDERER (object);

	g_free (self->priv->label);

	G_OBJECT_CLASS (gitg_diff_line_renderer_parent_class)->finalize (object);
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
darken_or_lighten (cairo_t       *ctx,
                   GdkRGBA const *color)
{
	float r, g, b;

	r = color->red;
	g = color->green;
	b = color->blue;

	if ((r + g + b) / 3 > 0.5)
	{
		cairo_set_source_rgb (ctx,
		                      r * 0.5,
		                      g * 0.5,
		                      b * 0.5);
	}
	else
	{
		cairo_set_source_rgb (ctx,
		                      r * 1.5,
		                      g * 1.5,
		                      b * 1.5);
	}
}

static void
render_label (GtkSourceGutterRenderer      *renderer,
              cairo_t                      *ctx,
              GdkRectangle                 *background_area,
              GdkRectangle                 *cell_area,
              GtkTextIter                  *start,
              GtkTextIter                  *end,
              GtkSourceGutterRendererState  renderer_state)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);
	GtkWidget *widget;
	PangoLayout *layout;
	GtkStyleContext *style_context;
	GtkStateType state;
	gint pixel_height;
	GdkRGBA fg_color, bg_color;

	widget = GTK_WIDGET (gtk_source_gutter_renderer_get_view (renderer));
	layout = lr->priv->cached_layout;

	pango_layout_set_markup (layout, lr->priv->label, -1);
	pango_layout_set_width (layout, cell_area->width);

	pango_layout_get_pixel_size (layout, NULL, &pixel_height);

	pango_layout_set_alignment (layout, PANGO_ALIGN_CENTER);

	style_context = gtk_widget_get_style_context (widget);
	state = gtk_widget_get_state (widget);

	gtk_style_context_get_color (style_context, state, &fg_color);
	gtk_style_context_get_background_color (style_context, state, &bg_color);

	gdk_cairo_set_source_rgba (ctx, &fg_color);

	gitg_utils_rounded_rectangle (ctx,
	                              cell_area->x + 0.5,
	                              cell_area->y + 0.5,
	                              cell_area->width - 1,
	                              cell_area->height - 1,
	                              5);

	cairo_fill_preserve (ctx);

	darken_or_lighten (ctx, &fg_color);

	cairo_set_line_width (ctx, 1);
	cairo_stroke (ctx);

	gdk_cairo_set_source_rgba (ctx, &bg_color);

	cairo_move_to (ctx,
	               cell_area->x + cell_area->width / 2,
	               cell_area->y + (cell_area->height - pixel_height) / 2);

	pango_cairo_show_layout (ctx, layout);
}

static void
render_lines (GtkSourceGutterRenderer      *renderer,
              cairo_t                      *ctx,
              GdkRectangle                 *background_area,
              GdkRectangle                 *cell_area,
              GtkTextIter                  *start,
              GtkTextIter                  *end,
              GtkSourceGutterRendererState  renderer_state)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);
	/* Render new/old in the cell area */
	gchar old_str[16];
	gchar new_str[16];
	PangoLayout *layout;
	GtkWidget *widget;
	GtkStyleContext *style_context;

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

	pango_layout_set_text (layout, old_str, -1);
	style_context = gtk_widget_get_style_context (widget);

	gtk_render_layout (style_context,
	                   ctx,
	                   cell_area->x + cell_area->width / 2 - 1,
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
gitg_diff_line_renderer_draw (GtkSourceGutterRenderer      *renderer,
                              cairo_t                      *ctx,
                              GdkRectangle                 *background_area,
                              GdkRectangle                 *cell_area,
                              GtkTextIter                  *start,
                              GtkTextIter                  *end,
                              GtkSourceGutterRendererState  renderer_state)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (renderer);

	/* Chain up to draw background */
	GTK_SOURCE_GUTTER_RENDERER_CLASS (
		gitg_diff_line_renderer_parent_class)->draw (renderer,
		                                             ctx,
		                                             background_area,
		                                             cell_area,
		                                             start,
		                                             end,
		                                             renderer_state);

	if (lr->priv->label)
	{
		render_label (renderer,
		              ctx,
		              background_area,
		              cell_area,
		              start,
		              end,
		              renderer_state);
	}
	else
	{
		render_lines (renderer,
		              ctx,
		              background_area,
		              cell_area,
		              start,
		              end,
		              renderer_state);
	}
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
	/* Get size of this rendering */
	gint num_digits, num;

	num_digits = 0;
	num = lr->priv->line_old;

	while (num > 0)
	{
		num /= 10;
		++num_digits;
	}

	num = lr->priv->line_new;

	while (num > 0)
	{
		num /= 10;
		++num_digits;
	}

	num_digits = MAX (num_digits, 2);

	if (num_digits != lr->priv->num_digits)
	{
		gchar *markup;
		gint size;

		lr->priv->num_digits = num_digits;

		markup = g_strdup_printf ("<b>%d   %d</b>",
		                          lr->priv->line_old,
		                          lr->priv->line_new);

		measure_text (lr, markup, NULL, &size, NULL);
		g_free (markup);

		gtk_source_gutter_renderer_set_size (GTK_SOURCE_GUTTER_RENDERER (lr),
		                                     size);
	}
}

static void
on_buffer_changed (GtkSourceBuffer      *buffer,
                   GitgDiffLineRenderer *renderer)
{
	recalculate_size (renderer);
}

static void
gitg_diff_line_renderer_change_buffer (GtkSourceGutterRenderer *renderer,
                                       GtkTextBuffer           *old_buffer)
{
	GitgDiffLineRenderer *lr;
	GtkTextView *view;

	lr = GITG_DIFF_LINE_RENDERER (renderer);

	if (old_buffer)
	{
		g_signal_handler_disconnect (old_buffer,
		                             lr->priv->changed_handler_id);
	}

	view = gtk_source_gutter_renderer_get_view (renderer);

	if (view)
	{
		GtkTextBuffer *buffer;

		buffer = gtk_text_view_get_buffer (view);

		if (buffer)
		{
			lr->priv->changed_handler_id =
				g_signal_connect (buffer,
				                  "changed",
				                  G_CALLBACK (on_buffer_changed),
				                  lr);

			recalculate_size (lr);
		}
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
	renderer_class->change_buffer = gitg_diff_line_renderer_change_buffer;

	object_class->set_property = gitg_diff_line_renderer_set_property;
	object_class->get_property = gitg_diff_line_renderer_get_property;
	object_class->finalize = gitg_diff_line_renderer_finalize;

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

	g_object_class_install_property (object_class,
	                                 PROP_LABEL,
	                                 g_param_spec_string ("label",
	                                                      "Label",
	                                                      "Label",
	                                                      NULL,
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
