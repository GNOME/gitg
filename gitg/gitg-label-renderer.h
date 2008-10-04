#ifndef __GITG_LABEL_RENDERER_H__
#define __GITG_LABEL_RENDERER_H__

#include <gtk/gtk.h>
#include <pango/pango.h>

gint gitg_label_renderer_width(GtkWidget *widget, PangoFontDescription *description, GSList *labels);
void gitg_label_renderer_draw(GtkWidget *widget, PangoFontDescription *description, cairo_t *context, GSList *labels, GdkRectangle *area);

#endif /* __GITG_LABEL_RENDERER_H__ */

