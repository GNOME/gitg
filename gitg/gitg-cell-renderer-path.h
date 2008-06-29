#ifndef __GITG_CELL_RENDERER_PATH_H__
#define __GITG_CELL_RENDERER_PATH_H__

#include <gtk/gtkcellrenderertext.h>

G_BEGIN_DECLS

#define GITG_TYPE_CELL_RENDERER_PATH			(gitg_cell_renderer_path_get_type ())
#define GITG_CELL_RENDERER_PATH(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPath))
#define GITG_CELL_RENDERER_PATH_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPath const))
#define GITG_CELL_RENDERER_PATH_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathClass))
#define GITG_IS_CELL_RENDERER_PATH(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_CELL_RENDERER_PATH))
#define GITG_IS_CELL_RENDERER_PATH_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_CELL_RENDERER_PATH))
#define GITG_CELL_RENDERER_PATH_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathClass))

typedef struct _GitgCellRendererPath		GitgCellRendererPath;
typedef struct _GitgCellRendererPathClass	GitgCellRendererPathClass;
typedef struct _GitgCellRendererPathPrivate	GitgCellRendererPathPrivate;

struct _GitgCellRendererPath {
	GtkCellRendererText parent;
	
	GitgCellRendererPathPrivate *priv;
};

struct _GitgCellRendererPathClass {
	GtkCellRendererTextClass parent_class;
};

GType gitg_cell_renderer_path_get_type (void) G_GNUC_CONST;
GtkCellRenderer *gitg_cell_renderer_path_new(void);

G_END_DECLS

#endif /* __GITG_CELL_RENDERER_PATH_H__ */
