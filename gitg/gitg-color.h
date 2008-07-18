#ifndef __GITG_COLOR_H__
#define __GITG_COLOR_H__

#include <glib.h>
#include <cairo.h>

typedef struct _GitgColor			GitgColor;

struct _GitgColor
{
	gulong ref_count;
	gint8 index;
};

void gitg_color_reset();
void gitg_color_get(GitgColor *color, gdouble *r, gdouble *g, gdouble *b);
void gitg_color_set_cairo_source(GitgColor *color, cairo_t *cr);

GitgColor *gitg_color_next();
GitgColor *gitg_color_next_index(GitgColor *color);
GitgColor *gitg_color_ref(GitgColor *color);
GitgColor *gitg_color_copy(GitgColor *color);
GitgColor *gitg_color_unref(GitgColor *color);

#endif /* __GITG_COLOR_H__ */
