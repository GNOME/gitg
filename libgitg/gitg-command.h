/*
 * gitg-command.h
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

#ifndef __GITG_COMMAND_H__
#define __GITG_COMMAND_H__

#include <glib-object.h>
#include <libgitg/gitg-repository.h>

G_BEGIN_DECLS

#define GITG_TYPE_COMMAND		(gitg_command_get_type ())
#define GITG_COMMAND(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMAND, GitgCommand))
#define GITG_COMMAND_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMAND, GitgCommand const))
#define GITG_COMMAND_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_COMMAND, GitgCommandClass))
#define GITG_IS_COMMAND(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_COMMAND))
#define GITG_IS_COMMAND_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_COMMAND))
#define GITG_COMMAND_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_COMMAND, GitgCommandClass))

typedef struct _GitgCommand		GitgCommand;
typedef struct _GitgCommandClass	GitgCommandClass;
typedef struct _GitgCommandPrivate	GitgCommandPrivate;

struct _GitgCommand
{
	/*< private >*/
	GInitiallyUnowned parent;

	GitgCommandPrivate *priv;

	/*< public >*/
};

struct _GitgCommandClass
{
	/*< private >*/
	GInitiallyUnownedClass parent_class;

	/*< public >*/
};

GType                gitg_command_get_type              (void) G_GNUC_CONST;

GitgCommand         *gitg_command_new                   (GitgRepository      *repository,
                                                         ...) G_GNUC_NULL_TERMINATED;
GitgCommand         *gitg_command_newv                  (GitgRepository      *repository,
                                                         gchar const * const *arguments);

GitgRepository      *gitg_command_get_repository        (GitgCommand         *command);

GFile               *gitg_command_get_working_directory (GitgCommand         *command);
void                 gitg_command_set_working_directory (GitgCommand         *command,
                                                         GFile               *file);

void                 gitg_command_set_arguments         (GitgCommand         *command,
                                                         ...) G_GNUC_NULL_TERMINATED;
void                 gitg_command_set_argumentsv        (GitgCommand         *command,
                                                         gchar const * const *arguments);
void                 gitg_command_add_arguments         (GitgCommand         *command,
                                                         ...) G_GNUC_NULL_TERMINATED;
void                 gitg_command_add_argumentsv        (GitgCommand         *command,
                                                         gchar const * const *arguments);

gchar const * const *gitg_command_get_arguments         (GitgCommand         *command);

void                 gitg_command_set_environment       (GitgCommand         *command,
                                                         ...) G_GNUC_NULL_TERMINATED;
void                 gitg_command_set_environmentv      (GitgCommand         *command,
                                                         gchar const * const *environment);
void                 gitg_command_add_environment       (GitgCommand         *command,
                                                         ...) G_GNUC_NULL_TERMINATED;
void                 gitg_command_add_environmentv      (GitgCommand         *command,
                                                         gchar const * const *environment);

gchar const * const *gitg_command_get_environment       (GitgCommand         *command);

G_END_DECLS

#endif /* __GITG_COMMAND_H__ */
