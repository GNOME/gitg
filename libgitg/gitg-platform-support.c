#include "gitg-platform-support.h"

#ifdef GDK_WINDOWING_QUARTZ
#include <gdk/gdkquartz.h>
#endif

gboolean
gitg_platform_support_use_native_window_controls (GdkDisplay *display)
{
#ifdef GDK_WINDOWING_QUARTZ
	if (display == NULL)
	{
		display = gdk_display_get_default ();
	}

	return GDK_IS_QUARTZ_DISPLAY (display);
#else
	return FALSE;
#endif
}
