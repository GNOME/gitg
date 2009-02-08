/*
 * gitg-color.c
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

#include "gitg-color.h"
#include <gdk/gdk.h>

static gint8 current_index = 0;

static gchar const *palette[] = {
	"#c4a000",
	"#4e9a06",
	"#ce5c00",
	"#204a87",
	"#2e3436",
	"#6c3566",
	"#a40000",

	"#8ae234",
	"#fcaf3e",
	"#729fcf",
	"#fce94f",
	"#888a85",
	"#ad7fa8",
	"#e9b96e",
	"#ef2929"
};

void
gitg_color_reset()
{
	current_index = 0;
}

void
gitg_color_get(GitgColor *color, gdouble *r, gdouble *g, gdouble *b)
{
	gchar const *spec = palette[color->index];
	GdkColor c;
	
	gdk_color_parse(spec, &c);

	*r = c.red / 65535.0;
	*g = c.green / 65535.0;
	*b = c.blue / 65535.0;
}

void
gitg_color_set_cairo_source(GitgColor *color, cairo_t *cr)
{
	gdouble r, g, b;

	gitg_color_get(color, &r, &g, &b);
	cairo_set_source_rgb(cr, r, g, b);
}

static gint8
next_index()
{
	gint8 next = current_index++;
	
	if (current_index == sizeof(palette) / sizeof(gchar const *))
		current_index = 0;

	return next;
}

GitgColor *
gitg_color_next()
{
	GitgColor *res = g_new(GitgColor, 1);
	res->ref_count = 1;
	res->index = next_index();

	return res;
}

GitgColor *
gitg_color_next_index(GitgColor *color)
{
	color->index = next_index();
	return color;
}

GitgColor *
gitg_color_copy(GitgColor *color)
{
	GitgColor *copy = g_new(GitgColor, 1);
	copy->ref_count = 1;
	copy->index = color->index;
	
	return copy;
}

GitgColor *
gitg_color_ref(GitgColor *color)
{
	if (!color)
		return NULL;

	++color->ref_count;
	return color;
}

GitgColor *
gitg_color_unref(GitgColor *color)
{
	if (!color)
		return NULL;
	
	--color->ref_count;
	
	if (color->ref_count == 0)
	{
		g_free(color);
		return NULL;
	}

	return color;
}

