#ifndef __GITG_PLATFORM_SUPPORT_H__
#define __GITG_PLATFORM_SUPPORT_H__

#include <gdk/gdk.h>

gboolean gitg_platform_support_use_native_window_controls (GdkDisplay *display);

void          gitg_platform_support_http_get        (GFile                *file,
                                                     GCancellable         *cancellable,
                                                     GAsyncReadyCallback   callback,
                                                     gpointer              user_data);

GInputStream *gitg_platform_support_http_get_finish (GAsyncResult         *result,
                                                     GError              **error);

#endif /* __GITG_PLATFORM_SUPPORT_H__ */

