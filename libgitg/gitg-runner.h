/*
 * gitg-runner.h
 * This file is part of gitg
 *
 * Copyright (C) 2010 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, 
 * Boston, MA  02110-1301  USA
 */

#ifndef __GITG_RUNNER_H__
#define __GITG_RUNNER_H__

#include <glib-object.h>
#include <libgitg/gitg-command.h>
#include <libgitg/gitg-io.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_RUNNER		(gitg_runner_get_type ())
#define GITG_RUNNER(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RUNNER, GitgRunner))
#define GITG_RUNNER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RUNNER, GitgRunner const))
#define GITG_RUNNER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_RUNNER, GitgRunnerClass))
#define GITG_IS_RUNNER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_RUNNER))
#define GITG_IS_RUNNER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_RUNNER))
#define GITG_RUNNER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_RUNNER, GitgRunnerClass))

typedef struct _GitgRunner		GitgRunner;
typedef struct _GitgRunnerClass		GitgRunnerClass;
typedef struct _GitgRunnerPrivate	GitgRunnerPrivate;

struct _GitgRunner
{
	/*< private >*/
	GitgIO parent;

	GitgRunnerPrivate *priv;

	/*< public >*/
};

struct _GitgRunnerClass
{
	/*< private >*/
	GitgIOClass parent_class;

	/*< public >*/
};

GType gitg_runner_get_type (void) G_GNUC_CONST;
GitgRunner *gitg_runner_new (GitgCommand *command);

void gitg_runner_run (GitgRunner *runner);

GitgCommand *gitg_runner_get_command (GitgRunner *runner);
void gitg_runner_set_command (GitgRunner *runner, GitgCommand *command);

GInputStream *gitg_runner_get_stream (GitgRunner *runner);
void gitg_runner_stream_close (GitgRunner *runner, GError *error);

G_END_DECLS

#endif /* __GITG_RUNNER_H__ */
