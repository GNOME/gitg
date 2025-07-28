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

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "gitg-platform-support.h"

#include <gio/gunixinputstream.h>

#include <sys/types.h>
#include <pwd.h>

#include <cairo.h>
#include <cairo/cairo-xlib.h>

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
	return G_INPUT_STREAM (g_file_read_finish (G_FILE (g_async_result_get_source_object (result)), result, error));
}

cairo_surface_t *
gitg_platform_support_create_cursor_surface (GdkDisplay    *display,
                                             GdkCursorType  cursor_type,
                                             gdouble       *hot_x,
                                             gdouble       *hot_y,
                                             gdouble       *width,
                                             gdouble       *height)
{
	GdkCursor *cursor;
	cairo_surface_t *surface;
	gdouble w = 0, h = 0;

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
	default: /* silence compiler warning */
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

GInputStream *
gitg_platform_support_new_input_stream_from_fd (gint     fd,
                                                gboolean close_fd)
{
	return g_unix_input_stream_new (fd, close_fd);
}

gchar *
gitg_platform_support_get_lib_dir (void)
{
	return g_strdup (GITG_LIBDIR);
}

gchar *
gitg_platform_support_get_locale_dir (void)
{
	return g_strdup (GITG_LOCALEDIR);
}

gchar *
gitg_platform_support_get_data_dir (void)
{
	return g_strdup (GITG_DATADIR);
}

gchar *
gitg_platform_support_get_user_home_dir (const gchar *name)
{
	struct passwd *pwd;

	if (name == NULL)
	{
		name = g_get_user_name ();
	}

	if (name == NULL)
	{
		return NULL;
	}

	pwd = getpwnam (name);

	if (pwd == NULL)
	{
		return NULL;
	}

	return g_strdup (pwd->pw_dir);
}

void
gitg_platform_support_application_support_prepare_startup (void)
{
}

// ex:ts=4 noet
