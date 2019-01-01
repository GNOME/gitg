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

#include <gdk/gdkquartz.h>
#include <gio/gunixinputstream.h>

#include <sys/types.h>
#include <pwd.h>

gboolean
gitg_platform_support_use_native_window_controls (GdkDisplay *display)
{
	if (display == NULL)
	{
		display = gdk_display_get_default ();
	}

	return GDK_IS_QUARTZ_DISPLAY (display);
}

void
gitg_platform_support_http_get (GFile               *file,
                                GCancellable        *cancellable,
                                GAsyncReadyCallback  callback,
                                gpointer             user_data)
{
	@autoreleasepool
	{
		NSString *dataUrl = [NSString stringWithUTF8String:g_file_get_uri (file)];
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:dataUrl]];
		NSOperationQueue *queue = [[NSOperationQueue alloc] init];

		GTask *task = g_task_new (file, cancellable, callback, user_data);

		[NSURLConnection sendAsynchronousRequest:request queue:queue completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
			if (g_task_return_error_if_cancelled (task))
			{
			}
			else if (error)
			{
				const gchar *message;

				message = [[error localizedDescription] UTF8String];

				g_task_return_new_error (task, G_IO_ERROR, G_IO_ERROR_FAILED, "%s", message);
			}
			else
			{
				GInputStream *stream;
				GBytes *bytes;

				bytes = g_bytes_new ([data bytes], [data length]);

				stream = g_memory_input_stream_new_from_bytes (bytes);
				g_bytes_unref (bytes);

				g_task_return_pointer (task, stream, NULL);
			}

			g_object_unref (task);
		}];
	}
}

GInputStream *
gitg_platform_support_http_get_finish (GAsyncResult  *result,
                                       GError       **error)
{
	return g_task_propagate_pointer (G_TASK (result), error);
}

cairo_surface_t *
gitg_platform_support_create_cursor_surface (GdkDisplay    *display,
                                             GdkCursorType  cursor_type,
                                             gdouble       *hot_x,
                                             gdouble       *hot_y,
                                             gdouble       *width,
                                             gdouble       *height)
{
	NSCursor *cursor;
	NSImage *image;
	NSBitmapImageRep *image_rep;
	const unsigned char *pixel_data;
	NSSize size;
	NSPoint hotspot;
	gint w, h;
	cairo_surface_t *surface, *target;
	cairo_t *ctx;

	@autoreleasepool
	{
		switch (cursor_type)
		{
		case GDK_HAND1:
			cursor = [NSCursor pointingHandCursor];
			break;
		default:
			cursor = [NSCursor arrowCursor];
			break;
		}

		image = [cursor image];

		image_rep = [[NSBitmapImageRep alloc] initWithData:[image TIFFRepresentation]];
		pixel_data = [image_rep bitmapData];

		w = [image_rep pixelsWide];
		h = [image_rep pixelsHigh];

		hotspot = [cursor hotSpot];
		size = [image size];

		if (hot_x)
		{
			*hot_x = hotspot.x;
		}

		if (hot_y)
		{
			*hot_y = hotspot.y;
		}

		if (width)
		{
			*width = size.width;
		}

		if (height)
		{
			*height = size.height;
		}

		surface = cairo_image_surface_create_for_data (pixel_data, CAIRO_FORMAT_ARGB32, w, h, [image_rep bytesPerRow]);
		target = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, size.width, size.height);

		ctx = cairo_create (target);

		cairo_scale (ctx, size.width / w, size.height / h);
		cairo_set_source_surface (ctx, surface, 0, 0);
		cairo_paint (ctx);
		cairo_destroy (ctx);

		cairo_surface_destroy (surface);

		return target;
	}
}

GInputStream *
gitg_platform_support_new_input_stream_from_fd (gint     fd,
                                                gboolean close_fd)
{
	return g_unix_input_stream_new (fd, close_fd);
}

static gchar *
get_resource_path (const gchar *fallback, ...)
{
	NSBundle *bundle;
	va_list vl;
	gchar *ret;
	GPtrArray *args;
	const gchar *arg;
	NSAutoreleasePool *pool;
	NSString *resource_path;

	@autoreleasepool
	{
		bundle = [NSBundle mainBundle];

		if (bundle == NULL || [bundle bundleIdentifier] == NULL)
		{
			return g_strdup (fallback);
		}

		resource_path = [bundle resourcePath];

		if (resource_path == NULL)
		{
			return g_strdup (fallback);
		}

		va_start (vl, fallback);
		args = g_ptr_array_new ();

		g_ptr_array_add (args, [resource_path UTF8String]);

		while ((arg = va_arg (vl, const gchar *)) != NULL)
		{
			g_ptr_array_add (args, arg);
		}

		va_end (vl);

		g_ptr_array_add (args, NULL);

		ret = g_build_filenamev (args->pdata);
		g_ptr_array_free (args, TRUE);

		return ret;
	}
}

gchar *
gitg_platform_support_get_lib_dir (void)
{
	return get_resource_path (GITG_LIBDIR, "lib", "gitg", NULL);
}

gchar *
gitg_platform_support_get_locale_dir (void)
{
	return get_resource_path (GITG_LOCALEDIR, "share", "locale", NULL);
}

gchar *
gitg_platform_support_get_data_dir (void)
{
	return get_resource_path (GITG_DATADIR, "share", "gitg", NULL);
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
