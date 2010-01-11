#ifndef __GITG_DIFF_LINE_RENDERER_H__
#define __GITG_DIFF_LINE_RENDERER_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_DIFF_LINE_RENDERER			(gitg_diff_line_renderer_get_type ())
#define GITG_DIFF_LINE_RENDERER(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRenderer))
#define GITG_DIFF_LINE_RENDERER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRenderer const))
#define GITG_DIFF_LINE_RENDERER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRendererClass))
#define GITG_IS_DIFF_LINE_RENDERER(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_DIFF_LINE_RENDERER))
#define GITG_IS_DIFF_LINE_RENDERER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_DIFF_LINE_RENDERER))
#define GITG_DIFF_LINE_RENDERER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_DIFF_LINE_RENDERER, GitgDiffLineRendererClass))

typedef struct _GitgDiffLineRenderer		GitgDiffLineRenderer;
typedef struct _GitgDiffLineRendererClass	GitgDiffLineRendererClass;
typedef struct _GitgDiffLineRendererPrivate	GitgDiffLineRendererPrivate;

struct _GitgDiffLineRenderer {
	GtkCellRenderer parent;
	
	GitgDiffLineRendererPrivate *priv;
};

struct _GitgDiffLineRendererClass {
	GtkCellRendererClass parent_class;
};

GType gitg_diff_line_renderer_get_type (void) G_GNUC_CONST;
GitgDiffLineRenderer *gitg_diff_line_renderer_new (void);


G_END_DECLS

#endif /* __GITG_DIFF_LINE_RENDERER_H__ */
