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

#ifndef __GITG_PLATFORM_SUPPORT_H__
#define __GITG_PLATFORM_SUPPORT_H__

#include <gdk/gdk.h>
#include <gio/gio.h>
#include <cairo/cairo.h>

gboolean gitg_platform_support_use_native_window_controls (GdkDisplay *display);

void          gitg_platform_support_http_get        (GFile                *file,
                                                     GCancellable         *cancellable,
                                                     GAsyncReadyCallback   callback,
                                                     gpointer              user_data);

GInputStream *gitg_platform_support_http_get_finish (GAsyncResult         *result,
                                                     GError              **error);

cairo_surface_t *gitg_platform_support_create_cursor_surface (GdkDisplay    *display,
                                                              GdkCursorType  cursor_type,
                                                              gdouble       *hot_x,
                                                              gdouble       *hot_y,
                                                              gdouble       *width,
                                                              gdouble       *height);

GInputStream *gitg_platform_support_new_input_stream_from_fd (gint     fd,
                                                              gboolean close_fd);

gchar        *gitg_platform_support_get_lib_dir (void);

gchar        *gitg_platform_support_get_locale_dir (void);

gchar        *gitg_platform_support_get_data_dir (void);

gchar        *gitg_platform_support_get_user_home_dir (const gchar *name);

void          gitg_platform_support_application_support_prepare_startup (void);

#endif /* __GITG_PLATFORM_SUPPORT_H__ */

// ex:ts=4 noet
