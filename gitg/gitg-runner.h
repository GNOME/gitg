/*
 * gitg-runner.h
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
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
 * Foundation, Inc., 59 Temple Place, Suite 330, 
 * Boston, MA 02111-1307, USA.
 */

#ifndef __GITG_RUNNER_H__
#define __GITG_RUNNER_H__

#include <glib-object.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_RUNNER			(gitg_runner_get_type ())
#define GITG_RUNNER(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RUNNER, GitgRunner))
#define GITG_RUNNER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RUNNER, GitgRunner const))
#define GITG_RUNNER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_RUNNER, GitgRunnerClass))
#define GITG_IS_RUNNER(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_RUNNER))
#define GITG_IS_RUNNER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_RUNNER))
#define GITG_RUNNER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_RUNNER, GitgRunnerClass))

#define GITG_RUNNER_ERROR			(gitg_runner_error_quark())

typedef struct _GitgRunner			GitgRunner;
typedef struct _GitgRunnerClass		GitgRunnerClass;
typedef struct _GitgRunnerPrivate	GitgRunnerPrivate;

typedef enum
{
	GITG_RUNNER_ERROR_NONE = 0,
	GITG_RUNNER_ERROR_EXIT
} GitgRunnerError;

struct _GitgRunner {
	GObject parent;
	
	GitgRunnerPrivate *priv;
};

struct _GitgRunnerClass {
	GObjectClass parent_class;
	
	/* signals */
	void (* begin_loading) (GitgRunner *runner);
	void (* update) (GitgRunner *runner, gchar **buffer);
	void (* end_loading) (GitgRunner *runner, gboolean cancelled);
};

GType gitg_runner_get_type (void) G_GNUC_CONST;
GitgRunner *gitg_runner_new(guint buffer_size);
GitgRunner *gitg_runner_new_synchronized(guint buffer_size);

guint gitg_runner_get_buffer_size(GitgRunner *runner);

gboolean gitg_runner_run_stream(GitgRunner *runner, GInputStream *stream, GError **error);

gboolean gitg_runner_run_with_arguments(GitgRunner *runner, gchar const **argv, gchar const *wd, gchar const *input, GError **error);
gboolean gitg_runner_run_working_directory(GitgRunner *runner, gchar const **argv, gchar const *wd, GError **error);
gboolean gitg_runner_run(GitgRunner *runner, gchar const **argv, GError **error);
gboolean gitg_runner_running(GitgRunner *runner);

gint gitg_runner_get_exit_status(GitgRunner *runner);
void gitg_runner_cancel(GitgRunner *runner);

GQuark gitg_runner_error_quark();

G_END_DECLS

#endif /* __GITG_RUNNER_H__ */
