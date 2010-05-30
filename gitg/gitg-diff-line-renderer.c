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

#include "gitg-diff-line-renderer.h"
#include "gitg-utils.h"

#define GITG_DIFF_LINE_RENDERER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRendererPrivate))

#ifndef MAX
#define MAX(a, b) (a > b ? a : b)
#endif

#ifndef MIN
#define MIN(a, b) (a < b ? a : b)
#endif

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
};

G_DEFINE_TYPE (GitgDiffLineRenderer, gitg_diff_line_renderer, GTK_TYPE_CELL_RENDERER)

static void
gitg_diff_line_renderer_finalize (GObject *object)
{
	G_OBJECT_CLASS (gitg_diff_line_renderer_parent_class)->finalize (object);
}

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
darken_or_lighten (cairo_t        *ctx,
                   GdkColor const *color)
{
	float r, g, b;

	r = color->red / 65535.0;
	g = color->green / 65535.0;
	b = color->blue / 65535.0;

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
render_label (GitgDiffLineRenderer *lr,
              GdkDrawable          *window,
              GtkWidget            *widget,
              GdkRectangle         *background_area,
              GdkRectangle         *cell_area,
              GdkRectangle         *expose_area,
              GtkCellRendererState  flags)
{
	PangoLayout *layout;
	GtkStyle *style;
	GtkStateType state;
	gint pixel_height;

	layout = gtk_widget_create_pango_layout (widget, "");

	pango_layout_set_markup (layout, lr->priv->label, -1);
	pango_layout_set_width (layout, cell_area->width);

	pango_layout_get_pixel_size (layout, NULL, &pixel_height);

	pango_layout_set_alignment (layout, PANGO_ALIGN_CENTER);

	style = gtk_widget_get_style (widget);
	state = gtk_widget_get_state (widget);

	cairo_t *ctx = gdk_cairo_create (window);

	gdk_cairo_rectangle (ctx, expose_area);
	cairo_clip (ctx);

	gdk_cairo_set_source_color (ctx, &(style->fg[state]));

	gitg_utils_rounded_rectangle (ctx,
	                              cell_area->x + 0.5,
	                              cell_area->y + 0.5,
	                              cell_area->width - 1,
	                              cell_area->height - 1,
	                              5);

	cairo_fill_preserve (ctx);

	darken_or_lighten (ctx, &(style->fg[state]));

	cairo_set_line_width (ctx, 1);
	cairo_stroke (ctx);

	gdk_cairo_set_source_color (ctx, &(style->base[state]));

	cairo_move_to (ctx,
	               cell_area->x + cell_area->width / 2,
	               cell_area->y + (cell_area->height - pixel_height) / 2);

	pango_cairo_show_layout (ctx, layout);

	cairo_destroy (ctx);

	/*gtk_paint_layout (style,
	                  window,
	                  state,
	                  FALSE,
	                  NULL,
	                  widget,
	                  NULL,
	                  cell_area->x + cell_area->width / 2,
	                  cell_area->y,
	                  layout);*/
}

static void
render_lines (GitgDiffLineRenderer *lr,
              GdkDrawable          *window,
              GtkWidget            *widget,
              GdkRectangle         *background_area,
              GdkRectangle         *cell_area,
              GdkRectangle         *expose_area,
              GtkCellRendererState  flags)
{
	/* Render new/old in the cell area */
	gchar old_str[16];
	gchar new_str[16];
	guint xpad;
	guint ypad;

	PangoLayout *layout = gtk_widget_create_pango_layout (widget, "");
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

	g_object_get (lr, "xpad", &xpad, "ypad", &ypad, NULL);

	pango_layout_set_text (layout, old_str, -1);
	gtk_paint_layout (widget->style,
	                  window,
	                  gtk_widget_get_state (widget),
	                  FALSE,
	                  NULL,
	                  widget,
	                  NULL,
	                  cell_area->x + cell_area->width / 2 - 1 - xpad,
	                  cell_area->y,
	                  layout);

	pango_layout_set_text (layout, new_str, -1);
	gtk_paint_layout (widget->style,
	                  window,
	                  gtk_widget_get_state (widget),
	                  FALSE,
	                  NULL,
	                  widget,
	                  NULL,
	                  cell_area->x + cell_area->width - xpad,
	                  cell_area->y,
	                  layout);

	g_object_unref (layout);

	gtk_paint_vline (widget->style,
	                 window,
	                 gtk_widget_get_state (widget),
	                 NULL,
	                 widget,
	                 NULL,
	                 background_area->y,
	                 background_area->y + background_area->height,
	                 background_area->x + background_area->width / 2);
}

static void
gitg_diff_line_renderer_render_impl (GtkCellRenderer      *cell,
                                     GdkDrawable          *window,
                                     GtkWidget            *widget,
                                     GdkRectangle         *background_area,
                                     GdkRectangle         *cell_area,
                                     GdkRectangle         *expose_area,
                                     GtkCellRendererState  flags)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (cell);

	if (lr->priv->label)
	{
		render_label (lr,
		              window,
		              widget,
		              background_area,
		              cell_area,
		              expose_area,
		              flags);
	}
	else
	{
		render_lines (lr,
		              window,
		              widget,
		              background_area,
		              cell_area,
		              expose_area,
		              flags);
	}
}

static void
gitg_diff_line_renderer_get_size_impl (GtkCellRenderer *cell,
                                       GtkWidget       *widget,
                                       GdkRectangle    *cell_area,
                                       gint            *x_offset,
                                       gint            *y_offset,
                                       gint            *width,
                                       gint            *height)
{
	GitgDiffLineRenderer *lr = GITG_DIFF_LINE_RENDERER (cell);

	/* Get size of this rendering */
	PangoLayout *layout;
	gchar str[16];
	gint pixel_width;
	gint pixel_height;
	guint xpad;
	guint ypad;

	g_snprintf(str, sizeof(str), "%d", MAX(MAX(99, lr->priv->line_old), lr->priv->line_new));
	layout = gtk_widget_create_pango_layout (widget, str);
	pango_layout_get_pixel_size(layout, &pixel_width, &pixel_height);

	g_object_get (cell, "xpad", &xpad, "ypad", &ypad, NULL);
	pixel_width += pixel_width + xpad * 2 + 3;

	if (lr->priv->label)
	{
		PangoLayout *lbl_layout;
		gint lbl_pixel_width;
		gint lbl_pixel_height;

		lbl_layout = gtk_widget_create_pango_layout (widget,
		                                             "");

		pango_layout_set_markup (lbl_layout, lr->priv->label, -1);

		pango_layout_get_pixel_size (lbl_layout,
		                             &lbl_pixel_width,
		                             &lbl_pixel_height);

		if (lbl_pixel_width > pixel_width)
		{
			pixel_width = lbl_pixel_width;
		}

		if (lbl_pixel_height > pixel_height)
		{
			pixel_height = lbl_pixel_height;
		}
	}

	pixel_width += xpad * 2;
	pixel_height += ypad * 2;

	if (width)
	{
		*width = pixel_width;
	}

	if (height)
	{
		*height = pixel_height;
	}

	if (x_offset)
	{
		*x_offset = 0;
	}

	if (y_offset)
	{
		*y_offset = 0;
	}

	g_object_unref (G_OBJECT (layout));
}

static void
gitg_diff_line_renderer_class_init (GitgDiffLineRendererClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GtkCellRendererClass *cell_renderer_class = GTK_CELL_RENDERER_CLASS (klass);

	cell_renderer_class->render = gitg_diff_line_renderer_render_impl;
	cell_renderer_class->get_size = gitg_diff_line_renderer_get_size_impl;

	object_class->finalize = gitg_diff_line_renderer_finalize;
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
