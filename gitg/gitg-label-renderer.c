/*
 * gitg-label-renderer.c
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

#include "gitg-label-renderer.h"
#include "gitg-ref.h"
#include <math.h>

#define PADDING 4
#define MARGIN 3

gint
get_label_width (PangoLayout *layout, GitgRef *ref)
{
	gint w;
	gchar *smaller = g_strdup_printf("<span size='smaller'>%s</span>", 
	                                 gitg_ref_get_shortname(ref));

	pango_layout_set_markup(layout, smaller, -1);
	
	pango_layout_get_pixel_size(layout, &w, NULL);
	g_free(smaller);

	return w + PADDING * 2;
}

gint
gitg_label_renderer_width(GtkWidget *widget, PangoFontDescription *description, GSList *labels)
{
	gint width = 0;
	GSList *item;
	
	if (labels == NULL)
		return 0;

	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, description);
	
	for (item = labels; item; item = item->next)
	{
		width += get_label_width (layout, GITG_REF (item->data)) + MARGIN;
	}
	
	g_object_unref(layout);
	//g_object_unref(ctx);
	
	return width + MARGIN;
}

static void
rounded_rectangle(cairo_t *ctx, float x, float y, float width, float height, float radius)
{
	cairo_move_to(ctx, x + radius, y);
	cairo_rel_line_to(ctx, width - 2 * radius, 0);
	cairo_arc(ctx, x + width - radius, y + radius, radius, 1.5 * M_PI, 0.0);
	
	cairo_rel_line_to(ctx, 0, height - 2 * radius);
	cairo_arc(ctx, x + width - radius, y + height - radius, radius, 0.0, 0.5 * M_PI);
	
	cairo_rel_line_to(ctx, -(width - radius * 2), 0);
	cairo_arc(ctx, x + radius, y + height - radius, radius, 0.5 * M_PI, M_PI);
	
	cairo_rel_line_to(ctx, 0, -(height - radius * 2));
	cairo_arc(ctx, x + radius, y + radius, radius, M_PI, 1.5 * M_PI);
}

static void
get_type_color (GitgRefType type, gdouble *r, gdouble *g, gdouble *b)
{
	switch (type)
	{
		case GITG_REF_TYPE_NONE:
			*r = 1;
			*g = 1;
			*b = 0.8;
		break;
		case GITG_REF_TYPE_BRANCH:
			*r = 0.8;
			*g = 1;
			*b = 0.5;
		break;
		case GITG_REF_TYPE_REMOTE:
			*r = 0.5;
			*g = 0.8;
			*b = 1;
		break;
		case GITG_REF_TYPE_TAG:
			*r = 1;
			*g = 1;
			*b = 0;
		break;
		case GITG_REF_TYPE_STASH:
			*r = 1;
			*g = 0.8;
			*b = 0.5;
		break;
		default:
			*r = 1;
			*g = 1;
			*b = 1;
		break;
	}
}

static void
set_source_for_ref_type(cairo_t *context, GitgRef *ref, gboolean use_state)
{
	if (use_state)
	{
		GitgRefState state = gitg_ref_get_state (ref);
		
		if (state == GITG_REF_STATE_SELECTED)
		{
			cairo_set_source_rgb(context, 1, 1, 1);
			return;
		}
		else if (state == GITG_REF_STATE_PRELIGHT)
		{
			gdouble r, g, b;
			get_type_color (gitg_ref_get_ref_type (ref), &r, &g, &b);
	
			cairo_set_source_rgba(context, r, g, b, 0.3);
			return;
		}
	}
	
	gdouble r, g, b;
	get_type_color (gitg_ref_get_ref_type (ref), &r, &g, &b);
	
	cairo_set_source_rgb (context, r, g, b);
}

static gint
render_label (cairo_t *context, PangoLayout *layout, GitgRef *ref, gint x, gint y, gint height, gboolean use_state)
{
	gint w;
	gint h;
	gchar *smaller = g_strdup_printf("<span size='smaller'>%s</span>", 
	                                 gitg_ref_get_shortname(ref));
	
	pango_layout_set_markup(layout, smaller, -1);
	pango_layout_get_pixel_size(layout, &w, &h);
	
	// draw rounded rectangle
	rounded_rectangle(context, x + 0.5, y + MARGIN + 0.5, w + PADDING * 2, height - MARGIN * 2, 5);
	
	set_source_for_ref_type(context, ref, use_state);
	cairo_fill_preserve(context);
	
	cairo_set_source_rgb(context, 0, 0, 0);
	cairo_stroke(context);
	
	cairo_save(context);
	cairo_translate(context, x + PADDING, y + (height - h) / 2.0 + 0.5);
	pango_cairo_show_layout(context, layout);
	cairo_restore(context);

	g_free(smaller);
	return w;
}

void
gitg_label_renderer_draw(GtkWidget *widget, PangoFontDescription *description, cairo_t *context, GSList *labels, GdkRectangle *area)
{
	GSList *item;
	double pos = MARGIN + 0.5;

	cairo_save(context);
	cairo_set_line_width(context, 1.0);

	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, description);

	for (item = labels; item; item = item->next)
	{
		gint w = render_label (context, layout, GITG_REF (item->data), pos, area->y, area->height, TRUE);
		pos += w + PADDING * 2 + MARGIN;		
	}
	
	g_object_unref(layout);
	cairo_restore(context);
}


GitgRef *
gitg_label_renderer_get_ref_at_pos (GtkWidget *widget, PangoFontDescription *font, GSList *labels, gint x, gint *hot_x)
{
	if (!labels)
	{
		return NULL;
	}
	
	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, font);

	gint start = MARGIN;
	GitgRef *ret = NULL;
	GSList *item;
	
	for (item = labels; item; item = item->next)
	{
		gint width = get_label_width (layout, GITG_REF (item->data));
		
		if (x >= start && x <= start + width)
		{
			ret = GITG_REF (item->data);
			
			if (hot_x)
			{
				*hot_x = x - start;
			}
			
			break;
		}
		
		start += width + MARGIN;
	}
	
	g_object_unref(layout);
	return ret;
}

inline guint8
convert_color_channel (guint8 src,
                       guint8 alpha)
{
	return alpha ? src / (alpha / 255.0) : 0;
}

void
convert_bgra_to_rgba (guint8 const  *src,
                      guint8        *dst,
                      gint           width,
                      gint           height)
{
	guint8 const *src_pixel = src;
	guint8 * dst_pixel = dst;
	int y;

	for (y = 0; y < height; y++)
	{
		int x;

		for (x = 0; x < width; x++)
		{
			dst_pixel[0] = convert_color_channel (src_pixel[2],
							                      src_pixel[3]);
			dst_pixel[1] = convert_color_channel (src_pixel[1],
							                      src_pixel[3]);
			dst_pixel[2] = convert_color_channel (src_pixel[0],
							                      src_pixel[3]);
			dst_pixel[3] = src_pixel[3];

			dst_pixel += 4;
			src_pixel += 4;
		}
	}
}

GdkPixbuf *
gitg_label_renderer_render_ref (GtkWidget *widget, PangoFontDescription *description, GitgRef *ref, gint height, gint minwidth)
{
	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, description);
	
	gint width = MAX(get_label_width (layout, ref), minwidth);
	
	cairo_surface_t *surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width + 2, height + 2);
	cairo_t *context = cairo_create (surface);
	
	cairo_set_line_width (context, 1);
	
	render_label (context, layout, ref, 1, 1, height, FALSE);
	
	guint8 *data = cairo_image_surface_get_data (surface);
	GdkPixbuf *ret = gdk_pixbuf_new (GDK_COLORSPACE_RGB, TRUE, 8, width + 2, height + 2);
	guint8 *pixdata = gdk_pixbuf_get_pixels (ret);
	
	convert_bgra_to_rgba (data, pixdata, width + 2, height + 2);
	
	cairo_destroy (context);
	cairo_surface_destroy (surface);

	g_object_unref (layout);
	
	return ret;
}
