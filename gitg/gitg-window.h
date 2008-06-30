#ifndef __GITG_WINDOW_H__
#define __GITG_WINDOW_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_WINDOW			(gitg_window_get_type ())
#define GITG_WINDOW(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_WINDOW, GitgWindow))
#define GITG_WINDOW_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_WINDOW, GitgWindow const))
#define GITG_WINDOW_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_WINDOW, GitgWindowClass))
#define GITG_IS_WINDOW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_WINDOW))
#define GITG_IS_WINDOW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_WINDOW))
#define GITG_WINDOW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_WINDOW, GitgWindowClass))

typedef struct _GitgWindow		GitgWindow;
typedef struct _GitgWindowClass		GitgWindowClass;
typedef struct _GitgWindowPrivate	GitgWindowPrivate;

struct _GitgWindow {
	GtkWindow parent;
	
	GitgWindowPrivate *priv;
};

struct _GitgWindowClass {
	GtkWindowClass parent_class;
};

GType gitg_window_get_type (void) G_GNUC_CONST;

void gitg_window_load_repository(GitgWindow *window, gchar const *path, gint argc, gchar const **argv);


G_END_DECLS

#endif /* __GITG_WINDOW_H__ */
