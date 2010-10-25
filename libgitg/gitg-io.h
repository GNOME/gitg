#ifndef __GITG_IO_H__
#define __GITG_IO_H__

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_IO		(gitg_io_get_type ())
#define GITG_IO(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_IO, GitgIO))
#define GITG_IO_CONST(obj)	(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_IO, GitgIO const))
#define GITG_IO_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_IO, GitgIOClass))
#define GITG_IS_IO(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_IO))
#define GITG_IS_IO_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_IO))
#define GITG_IO_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_IO, GitgIOClass))

typedef struct _GitgIO		GitgIO;
typedef struct _GitgIOClass	GitgIOClass;
typedef struct _GitgIOPrivate	GitgIOPrivate;

struct _GitgIO
{
	/*< private >*/
	GObject parent;

	GitgIOPrivate *priv;

	/*< public >*/
};

struct _GitgIOClass
{
	/*< private >*/
	GObjectClass parent_class;

	/*< public >*/
	void (*cancel) (GitgIO *io);

	/* Signals */
	void (*begin) (GitgIO *io);
	void (*end) (GitgIO *io, GError *error);
};

GType gitg_io_get_type (void) G_GNUC_CONST;
GitgIO *gitg_io_new (void);

void gitg_io_begin (GitgIO *io);
void gitg_io_end (GitgIO *io, GError *error);

void gitg_io_set_input (GitgIO *io, GInputStream *stream);
void gitg_io_set_output (GitgIO *io, GOutputStream *stream);

GInputStream *gitg_io_get_input (GitgIO *io);
GOutputStream *gitg_io_get_output (GitgIO *io);

void gitg_io_close (GitgIO *io);
void gitg_io_cancel (GitgIO *io);

gboolean gitg_io_get_cancelled (GitgIO *io);
void gitg_io_set_cancelled (GitgIO *io, gboolean cancelled);

gint gitg_io_get_exit_status (GitgIO *io);
void gitg_io_set_exit_status (GitgIO *io, gint status);

gboolean gitg_io_get_running (GitgIO *io);
void gitg_io_set_running (GitgIO *io, gboolean running);

G_END_DECLS

#endif /* __GITG_IO_H__ */
