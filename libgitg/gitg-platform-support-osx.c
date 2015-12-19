#include "gitg-platform-support.h"

#include <gdk/gdkquartz.h>

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
	NSURLSessionDataTask *downloadTask;
	NSString *dataUrl;
	NSURL *url;
	GTask *task;

	dataUrl = [NSString stringWithUTF8String:g_file_get_uri (file)];
	url = [NSURL URLWithString:dataUrl];

	task = g_task_new (file, cancellable, callback, user_data);

	downloadTask = [[NSURLSession sharedSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
 
	[downloadTask resume];
}

GInputStream *
gitg_platform_support_http_get_finish (GAsyncResult  *result,
                                       GError       **error)
{
	return g_task_propagate_pointer (G_TASK (result), error);
}
