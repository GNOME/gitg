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

#include <gio/gwin32inputstream.h>

#define SAVE_DATADIR DATADIR
#undef DATADIR
#include <io.h>
#include <conio.h>
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0501
#endif
#include <windows.h>
#define DATADIR SAVE_DATADIR
#undef SAVE_DATADIR

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
                                             gdouble       *hot_x,
                                             gdouble       *hot_y,
                                             gdouble       *width,
                                             gdouble       *height)
{
	return NULL;
}

GInputStream *
gitg_platform_support_new_input_stream_from_fd (gint     fd,
                                                gboolean close_fd)
{
	return g_win32_input_stream_new ((void *)fd, close_fd);
}

gchar *
gitg_platform_support_get_lib_dir (void)
{
	gchar *module_dir;
	gchar *lib_dir;

	module_dir = g_win32_get_package_installation_directory_of_module (NULL);
	lib_dir = g_build_filename (module_dir, "lib", "gitg", NULL);
	g_free (module_dir);

	return lib_dir;
}

gchar *
gitg_platform_support_get_locale_dir (void)
{
	gchar *module_dir;
	gchar *locale_dir;

	module_dir = g_win32_get_package_installation_directory_of_module (NULL);
	locale_dir = g_build_filename (module_dir, "share", "locale", NULL);
	g_free (module_dir);

	return locale_dir;
}

gchar *
gitg_platform_support_get_data_dir (void)
{
	gchar *module_dir;
	gchar *data_dir;

	module_dir = g_win32_get_package_installation_directory_of_module (NULL);
	data_dir = g_build_filename (module_dir, "share", "gitg", NULL);
	g_free (module_dir);

	return data_dir;
}

gchar *
gitg_platform_support_get_user_home_dir (const gchar *name)
{
	// TODO
	return NULL;
}

void
gitg_platform_support_application_support_prepare_startup (void)
{
	/* If we open gedit from a console get the stdout printing */
	if (fileno (stdout) != -1 &&
	    _get_osfhandle (fileno (stdout)) != -1)
	{
		/* stdout is fine, presumably redirected to a file or pipe */
	}
	else
	{
		typedef BOOL (* WINAPI AttachConsole_t) (DWORD);

		AttachConsole_t p_AttachConsole =
			(AttachConsole_t) GetProcAddress (GetModuleHandle ("kernel32.dll"),
			                                  "AttachConsole");

		if (p_AttachConsole != NULL && p_AttachConsole (ATTACH_PARENT_PROCESS))
		{
			freopen ("CONOUT$", "w", stdout);
			freopen ("CONOUT$", "w", stderr);
		}
	}
}

// ex:ts=4 noet
