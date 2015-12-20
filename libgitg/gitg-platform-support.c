/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

#include "gitg-platform-support.h"

gboolean
gitg_platform_support_use_native_window_controls (GdkDisplay *display)
{
	return FALSE;
}

void
gitg_platform_support_http_get (GFile               *file,
                                GCancellable        *cancellable,
                                GAsyncReadyCallback  callback,
                                gpointer             user_data)
{
	g_file_read_async (file, G_PRIORITY_DEFAULT, cancellable, callback, user_data);
}

GInputStream *
gitg_platform_support_http_get_finish (GAsyncResult  *result,
                                       GError       **error)
{
	return G_INPUT_STREAM (g_file_read_finish (g_async_result_get_source_object (result), result, error));
}

cairo_surface_t *
gitg_platform_support_create_cursor_surface (GdkDisplay    *display,
                                             GdkCursorType  cursor_type,
                                             gint          *hot_x,
                                             gint          *hot_y,
                                             gint          *width,
                                             gint          *height)
{
	GdkCursor *cursor;
	cairo_surface_t *surface;
	gint w = 0, h = 0;

	cursor = gdk_cursor_new_for_display (display, cursor_type);
	surface = gdk_cursor_get_surface (cursor, hot_x, hot_y);

	if (surface == NULL)
	{
		return NULL;
	}

	switch (cairo_surface_get_type (surface))
	{
	case CAIRO_SURFACE_TYPE_XLIB:
		w = cairo_xlib_surface_get_width (surface);
		h = cairo_xlib_surface_get_height (surface);
		break;
	case CAIRO_SURFACE_TYPE_IMAGE:
		w = cairo_image_surface_get_width (surface);
		h = cairo_image_surface_get_height (surface);
		break;
	}

	if (width)
	{
		*width = w;
	}

	if (height)
	{
		*height = h;
	}

	return surface;
}

// ex:ts=4 noet
