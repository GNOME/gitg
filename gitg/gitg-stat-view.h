#ifndef __GITG_STAT_VIEW_H__
#define __GITG_STAT_VIEW_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_STAT_VIEW		(gitg_stat_view_get_type ())
#define GITG_STAT_VIEW(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_STAT_VIEW, GitgStatView))
#define GITG_STAT_VIEW_CONST(obj)	(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_STAT_VIEW, GitgStatView const))
#define GITG_STAT_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_STAT_VIEW, GitgStatViewClass))
#define GITG_IS_STAT_VIEW(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_STAT_VIEW))
#define GITG_IS_STAT_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_STAT_VIEW))
#define GITG_STAT_VIEW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_STAT_VIEW, GitgStatViewClass))

typedef struct _GitgStatView		GitgStatView;
typedef struct _GitgStatViewClass	GitgStatViewClass;
typedef struct _GitgStatViewPrivate	GitgStatViewPrivate;

struct _GitgStatView {
	GtkDrawingArea parent;

	GitgStatViewPrivate *priv;
};

struct _GitgStatViewClass {
	GtkDrawingAreaClass parent_class;
};

GType gitg_stat_view_get_type (void) G_GNUC_CONST;
GtkWidget *gitg_stat_view_new (guint lines_added,
                               guint lines_removed,
                               guint max_lines);

G_END_DECLS

#endif /* __GITG_STAT_VIEW_H__ */
