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
gitg_label_renderer_width(GtkWidget *widget, PangoFontDescription *font, GSList *labels)
{
	gint width = 0;
	GSList *item;
	
	if (labels == NULL)
		return 0;

	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, font);
	
	for (item = labels; item; item = item->next)
	{
		gint w;
		GitgRef *ref = (GitgRef *)item->data;
		gchar *smaller = g_strdup_printf("<span size='smaller'>%s</span>", 
		                                 gitg_ref_get_shortname(ref));
		pango_layout_set_markup(layout, smaller, -1);
		
		pango_layout_get_pixel_size(layout, &w, NULL);
		
		width += w + PADDING * 2 + MARGIN;
		g_free(smaller);
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
set_source_for_ref_type(cairo_t *context, GitgRefType type)
{
	switch (type)
	{
		case GITG_REF_TYPE_NONE:
			cairo_set_source_rgb(context, 1, 1, 0.8);
		break;
		case GITG_REF_TYPE_BRANCH:
			cairo_set_source_rgb(context, 0.8, 1, 0.5);
		break;
		case GITG_REF_TYPE_REMOTE:
			cairo_set_source_rgb(context, 0.5, 0.8, 1);
		break;
		case GITG_REF_TYPE_TAG:
			cairo_set_source_rgb(context, 1, 1, 0);
		break;
	}
}

void
gitg_label_renderer_draw(GtkWidget *widget, PangoFontDescription *font, cairo_t *context, GSList *labels, GdkRectangle *area)
{
	GSList *item;
	double pos = MARGIN + 0.5;

	cairo_save(context);
	cairo_set_line_width(context, 1.0);

	PangoContext *ctx = gtk_widget_get_pango_context(widget);
	PangoLayout *layout = pango_layout_new(ctx);
	pango_layout_set_font_description(layout, font);

	for (item = labels; item; item = item->next)
	{
		GitgRef *ref = (GitgRef *)item->data;
		gint w;
		gint h;
		gchar *smaller = g_strdup_printf("<span size='smaller'>%s</span>", 
		                                 gitg_ref_get_shortname(ref));
		
		pango_layout_set_markup(layout, smaller, -1);
		pango_layout_get_pixel_size(layout, &w, &h);
		
		// draw rounded rectangle
		rounded_rectangle(context, pos + 0.5, area->y + MARGIN + 0.5, w + PADDING * 2, area->height - MARGIN * 2, 5);
		
		
		set_source_for_ref_type(context, gitg_ref_get_ref_type(ref));
		cairo_fill_preserve(context);
		
		cairo_set_source_rgb(context, 0, 0, 0);
		cairo_stroke(context);
		
		cairo_save(context);
		cairo_translate(context, pos + PADDING, area->y + (area->height - h) / 2.0 + 0.5);
		pango_cairo_show_layout(context, layout);
		cairo_restore(context);
		
		pos += w + PADDING * 2 + MARGIN;
		g_free(smaller);
	}
	
	g_object_unref(layout);
	cairo_restore(context);
}
