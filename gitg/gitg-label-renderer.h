/*
 * gitg-label-renderer.h
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

#ifndef __GITG_LABEL_RENDERER_H__
#define __GITG_LABEL_RENDERER_H__

#include <gtk/gtk.h>
#include <pango/pango.h>
#include "gitg-ref.h"

gint gitg_label_renderer_width(GtkWidget *widget, PangoFontDescription *description, GSList *labels);
void gitg_label_renderer_draw(GtkWidget *widget, PangoFontDescription *description, cairo_t *context, GSList *labels, GdkRectangle *area);

GitgRef *gitg_label_renderer_get_ref_at_pos (GtkWidget *widget, PangoFontDescription *description, GSList *labels, gint x, gint *hot_x);

GdkPixbuf *gitg_label_renderer_render_ref (GtkWidget *widget, PangoFontDescription *description, GitgRef *ref, gint height, gint minwidth);

#endif /* __GITG_LABEL_RENDERER_H__ */

