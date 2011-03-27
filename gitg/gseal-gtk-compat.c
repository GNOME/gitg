#include "gseal-gtk-compat.h"

#if !GTK_CHECK_VERSION (2, 24, 0)
gint
gitg_gseal_gtk_compat_window_get_width (GdkWindow *window)
{
	gint width;

	gdk_drawable_get_size (GDK_DRAWABLE (window), &width, NULL);
	return width;
}

gint
gitg_gseal_gtk_compat_window_get_height (GdkWindow *window)
{
	gint height;

	gdk_drawable_get_size (GDK_DRAWABLE (window), NULL, &height);
	return height;
}
#endif
