/*
 * gitg-command.c
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

#include "gitg-command.h"

#define GITG_COMMAND_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_COMMAND, GitgCommandPrivate))

#define CONST_CONST(x) ((gchar const * const *)x)

struct _GitgCommandPrivate
{
	GitgRepository *repository;
	gchar **arguments;
	gchar **environment;
	GFile *working_directory;
};

G_DEFINE_TYPE (GitgCommand, gitg_command, G_TYPE_INITIALLY_UNOWNED)

enum
{
	PROP_0,
	PROP_REPOSITORY,
	PROP_ARGUMENTS,
	PROP_ENVIRONMENT,
	PROP_WORKING_DIRECTORY
};

static void
gitg_command_finalize (GObject *object)
{
	GitgCommand *command;

	command = GITG_COMMAND (object);

	g_strfreev (command->priv->arguments);
	g_strfreev (command->priv->environment);

	G_OBJECT_CLASS (gitg_command_parent_class)->finalize (object);
}

static void
gitg_command_dispose (GObject *object)
{
	GitgCommand *command;

	command = GITG_COMMAND (object);

	if (command->priv->repository != NULL)
	{
		g_object_unref (command->priv->repository);
		command->priv->repository = NULL;
	}

	G_OBJECT_CLASS (gitg_command_parent_class)->dispose (object);
}

static void
gitg_command_set_property (GObject      *object,
                           guint         prop_id,
                           const GValue *value,
                           GParamSpec   *pspec)
{
	GitgCommand *self = GITG_COMMAND (object);

	switch (prop_id)
	{
		case PROP_REPOSITORY:
			self->priv->repository = g_value_dup_object (value);
			break;
		case PROP_ARGUMENTS:
			gitg_command_set_argumentsv (self,
			                             g_value_get_boxed (value));
			break;
		case PROP_ENVIRONMENT:
			gitg_command_set_environmentv (self,
			                               g_value_get_boxed (value));
			break;
		case PROP_WORKING_DIRECTORY:
			gitg_command_set_working_directory (self,
			                                    g_value_get_object (value));
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_command_get_property (GObject    *object,
                           guint       prop_id,
                           GValue     *value,
                           GParamSpec *pspec)
{
	GitgCommand *self = GITG_COMMAND (object);

	switch (prop_id)
	{
		case PROP_REPOSITORY:
			g_value_set_object (value, self->priv->repository);
			break;
		case PROP_ARGUMENTS:
			g_value_set_boxed (value, self->priv->arguments);
			break;
		case PROP_ENVIRONMENT:
			g_value_set_boxed (value, self->priv->environment);
			break;
		case PROP_WORKING_DIRECTORY:
			g_value_take_object (value, gitg_command_get_working_directory (self));
			break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_command_class_init (GitgCommandClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gitg_command_finalize;
	object_class->dispose = gitg_command_dispose;

	object_class->get_property = gitg_command_get_property;
	object_class->set_property = gitg_command_set_property;

	g_type_class_add_private (object_class, sizeof(GitgCommandPrivate));

	g_object_class_install_property (object_class,
	                                 PROP_REPOSITORY,
	                                 g_param_spec_object ("repository",
	                                                      "Repository",
	                                                      "Repository",
	                                                      GITG_TYPE_REPOSITORY,
	                                                      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));

	g_object_class_install_property (object_class,
	                                 PROP_ARGUMENTS,
	                                 g_param_spec_boxed ("arguments",
	                                                     "Arguments",
	                                                     "Arguments",
	                                                     G_TYPE_STRV,
	                                                     G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_ENVIRONMENT,
	                                 g_param_spec_boxed ("environment",
	                                                     "Environment",
	                                                     "Environment",
	                                                     G_TYPE_STRV,
	                                                     G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_WORKING_DIRECTORY,
	                                 g_param_spec_object ("working-directory",
	                                                      "Working Directory",
	                                                      "Working directory",
	                                                      G_TYPE_FILE,
	                                                      G_PARAM_READWRITE));
}

static void
gitg_command_init (GitgCommand *self)
{
	self->priv = GITG_COMMAND_GET_PRIVATE (self);
}

static gchar **
collect_arguments (va_list ap)
{
	GPtrArray *arguments;
	gchar const *arg;

	arguments = g_ptr_array_new ();

	while ((arg = va_arg (ap, gchar const *)) != NULL)
	{
		g_ptr_array_add (arguments, g_strdup (arg));
	}

	g_ptr_array_add (arguments, NULL);

	return (gchar **)g_ptr_array_free (arguments, FALSE);
}

static gchar **
combine_environment (gchar const * const *environment)
{
	GPtrArray *ret;

	ret = g_ptr_array_new ();

	while (*environment)
	{
		gchar const *key = *environment++;
		gchar const *value = *environment++;

		gchar *combined = g_strconcat (key, "=", value, NULL);

		g_ptr_array_add (ret, combined);
	}

	g_ptr_array_add (ret, NULL);

	return (gchar **)g_ptr_array_free (ret, FALSE);
}

GitgCommand *
gitg_command_newv (GitgRepository      *repository,
                   gchar const * const *arguments)
{
	g_return_val_if_fail (repository == NULL || GITG_IS_REPOSITORY (repository), NULL);

	return g_object_new (GITG_TYPE_COMMAND,
	                     "repository", repository,
	                     "arguments", arguments,
	                     NULL);
}

GitgCommand *
gitg_command_new (GitgRepository *repository,
                  ...)
{
	va_list ap;
	GitgCommand *ret;
	gchar **arguments;

	g_return_val_if_fail (repository == NULL || GITG_IS_REPOSITORY (repository), NULL);

	va_start (ap, repository);

	arguments = collect_arguments (ap);
	ret = gitg_command_newv (repository, CONST_CONST (arguments));

	g_strfreev (arguments);
	va_end (ap);

	return ret;
}

GitgRepository *
gitg_command_get_repository (GitgCommand *command)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);

	return command->priv->repository;
}

void
gitg_command_set_argumentsv (GitgCommand         *command,
                             gchar const * const *arguments)
{
	GPtrArray *ret;

	g_return_if_fail (GITG_IS_COMMAND (command));

	ret = g_ptr_array_new ();

	if (command->priv->repository)
	{
		GFile *git_dir;
		GFile *work_tree;

		gchar *git_dir_path;
		gchar *work_tree_path;

		git_dir = gitg_repository_get_git_dir (command->priv->repository);
		work_tree = gitg_repository_get_work_tree (command->priv->repository);

		git_dir_path = g_file_get_path (git_dir);
		work_tree_path = g_file_get_path (work_tree);

		g_object_unref (git_dir);
		g_object_unref (work_tree);

		g_ptr_array_add (ret, g_strdup ("git"));
		g_ptr_array_add (ret, g_strdup ("--git-dir"));
		g_ptr_array_add (ret, git_dir_path);
		g_ptr_array_add (ret, g_strdup ("--work-tree"));
		g_ptr_array_add (ret, work_tree_path);
	}

	while (*arguments)
	{
		g_ptr_array_add (ret, g_strdup (*arguments++));
	}

	g_ptr_array_add (ret, NULL);

	g_strfreev (command->priv->arguments);
	command->priv->arguments = (gchar **)g_ptr_array_free (ret, FALSE);

	g_object_notify (G_OBJECT (command), "arguments");
}

void
gitg_command_set_arguments (GitgCommand *command,
                            ...)
{
	va_list ap;
	gchar **arguments;

	g_return_if_fail (GITG_IS_COMMAND (command));

	va_start (ap, command);
	arguments = collect_arguments (ap);
	va_end (ap);

	gitg_command_set_argumentsv (command, CONST_CONST (arguments));

	g_strfreev (arguments);
}

void
gitg_command_add_argumentsv (GitgCommand         *command,
                             gchar const * const *arguments)
{
	GPtrArray *args;
	gchar **ptr;

	g_return_if_fail (GITG_IS_COMMAND (command));

	args = g_ptr_array_new ();

	for (ptr = command->priv->arguments; *ptr; ++ptr)
	{
		g_ptr_array_add (args, *ptr);
	}

	while (*arguments)
	{
		g_ptr_array_add (args, g_strdup (*arguments++));
	}

	g_free (command->priv->arguments);

	g_ptr_array_add (args, NULL);
	command->priv->arguments = (gchar **)g_ptr_array_free (args, FALSE);

	g_object_notify (G_OBJECT (command), "arguments");
}

void
gitg_command_add_arguments (GitgCommand *command,
                            ...)
{
	va_list ap;
	gchar **arguments;

	g_return_if_fail (GITG_IS_COMMAND (command));

	va_start (ap, command);
	arguments = collect_arguments (ap);
	va_end (ap);

	gitg_command_add_argumentsv (command, CONST_CONST (arguments));

	g_strfreev (arguments);
}

gchar const * const *
gitg_command_get_arguments (GitgCommand *command)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);
	return CONST_CONST (command->priv->arguments);
}

void
gitg_command_set_environmentv (GitgCommand         *command,
                               gchar const * const *environment)
{
	g_return_if_fail (GITG_IS_COMMAND (command));

	g_strfreev (command->priv->environment);
	command->priv->environment = combine_environment (environment);

	g_object_notify (G_OBJECT (command), "environment");
}

void
gitg_command_set_environment (GitgCommand *command,
                              ...)
{
	va_list ap;
	gchar **environment;

	g_return_if_fail (GITG_IS_COMMAND (command));

	va_start (ap, command);
	environment = collect_arguments (ap);
	va_end (ap);

	gitg_command_set_environmentv (command, CONST_CONST (environment));

	g_strfreev (environment);
}

void
gitg_command_add_environmentv (GitgCommand         *command,
                               gchar const * const *environment)
{
	GPtrArray *args;
	gchar **combined;
	gchar **ptr;

	g_return_if_fail (GITG_IS_COMMAND (command));

	args = g_ptr_array_new ();

	for (ptr = command->priv->environment; *ptr; ++ptr)
	{
		g_ptr_array_add (args, *ptr);
	}

	combined = combine_environment (environment);

	for (ptr = combined; *ptr; ++ptr)
	{
		g_ptr_array_add (args, *ptr);
	}

	g_free (combined);
	g_free (command->priv->environment);

	g_ptr_array_add (args, NULL);

	command->priv->environment = (gchar **)g_ptr_array_free (args, FALSE);

	g_object_notify (G_OBJECT (command), "arguments");
}

void
gitg_command_add_environment (GitgCommand *command,
                              ...)
{
	va_list ap;
	gchar **environment;

	g_return_if_fail (GITG_IS_COMMAND (command));

	va_start (ap, command);
	environment = collect_arguments (ap);
	va_end (ap);

	gitg_command_add_environmentv (command, CONST_CONST (environment));
	g_strfreev (environment);
}

gchar const * const *
gitg_command_get_environment (GitgCommand *command)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);

	return CONST_CONST (command->priv->environment);
}

void
gitg_command_set_working_directory (GitgCommand *command,
                                    GFile       *working_directory)
{
	g_return_if_fail (GITG_IS_COMMAND (command));
	g_return_if_fail (working_directory == NULL || G_IS_FILE (working_directory));

	if (command->priv->working_directory)
	{
		g_object_unref (command->priv->working_directory);
		command->priv->working_directory = NULL;
	}

	if (working_directory)
	{
		command->priv->working_directory = g_file_dup (working_directory);
	}

	g_object_notify (G_OBJECT (command), "working-directory");
}

GFile *
gitg_command_get_working_directory (GitgCommand *command)
{
	g_return_val_if_fail (GITG_IS_COMMAND (command), NULL);

	if (command->priv->working_directory)
	{
		return g_file_dup (command->priv->working_directory);
	}
	else if (command->priv->repository)
	{
		return gitg_repository_get_work_tree (command->priv->repository);
	}

	return NULL;
}
