/*
 * gitg-color.h
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

#ifndef __GITG_COLOR_H__
#define __GITG_COLOR_H__

#include <glib.h>
#include <cairo.h>

typedef struct _GitgColor			GitgColor;

struct _GitgColor
{
	gulong ref_count;
	gint8 index;
};

void gitg_color_reset (void);
void gitg_color_get (GitgColor *color, gdouble *r, gdouble *g, gdouble *b);
void gitg_color_set_cairo_source (GitgColor *color, cairo_t *cr);

GitgColor *gitg_color_next (void);
GitgColor *gitg_color_next_index (GitgColor *color);
GitgColor *gitg_color_ref (GitgColor *color);
GitgColor *gitg_color_copy (GitgColor *color);
GitgColor *gitg_color_unref (GitgColor *color);

#endif /* __GITG_COLOR_H__ */
