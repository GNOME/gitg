/*
 * gitg-io.h
 * This file is part of gitg
 *
 * Copyright (C) 2010 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

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
