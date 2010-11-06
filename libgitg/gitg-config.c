/*
 * gitg-config.c
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

#include "gitg-config.h"
#include "gitg-shell.h"

#define GITG_CONFIG_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CONFIG, GitgConfigPrivate))

enum
{
	PROP_0,
	PROP_REPOSITORY
};

struct _GitgConfigPrivate
{
	GitgRepository *repository;
	GitgShell *shell;

	GString *accumulated;
};

G_DEFINE_TYPE (GitgConfig, gitg_config, G_TYPE_OBJECT)

static void
gitg_config_finalize (GObject *object)
{
	GitgConfig *config = GITG_CONFIG (object);

	if (config->priv->repository)
	{
		g_object_unref(config->priv->repository);
	}

	g_string_free (config->priv->accumulated, TRUE);

	G_OBJECT_CLASS (gitg_config_parent_class)->finalize (object);
}

static void
gitg_config_set_property (GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgConfig *self = GITG_CONFIG (object);

	switch (prop_id)
	{
		case PROP_REPOSITORY:
			if (self->priv->repository)
			{
				g_object_unref(self->priv->repository);
			}

			self->priv->repository = GITG_REPOSITORY (g_value_dup_object (value));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_config_get_property (GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgConfig *self = GITG_CONFIG (object);

	switch (prop_id)
	{
		case PROP_REPOSITORY:
			g_value_set_object (value, self->priv->repository);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_config_class_init (GitgConfigClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = gitg_config_finalize;
	object_class->get_property = gitg_config_get_property;
	object_class->set_property = gitg_config_set_property;

	g_object_class_install_property(object_class, PROP_REPOSITORY,
					 g_param_spec_object("repository",
							      "REPOSITORY",
							      "The repository",
							      GITG_TYPE_REPOSITORY,
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));

	g_type_class_add_private (object_class, sizeof(GitgConfigPrivate));
}

static void
gitg_config_accumulate (GitgShell   *shell,
                        gchar      **buffer,
                        GitgConfig *config)
{
	gchar **ptr = buffer;

	while (*ptr)
	{
		g_string_append (config->priv->accumulated, *ptr);
		++ptr;
	}
}

static void
gitg_config_begin (GitgShell  *shell,
                   GitgConfig *config)
{
	g_string_erase (config->priv->accumulated, 0, -1);
}

static void
gitg_config_init (GitgConfig *self)
{
	self->priv = GITG_CONFIG_GET_PRIVATE (self);

	self->priv->shell = gitg_shell_new_synchronized (1000);

	self->priv->accumulated = g_string_new ("");

	g_signal_connect (self->priv->shell,
	                  "update",
	                  G_CALLBACK (gitg_config_accumulate),
	                  self);

	g_signal_connect (self->priv->shell,
	                  "begin",
	                  G_CALLBACK (gitg_config_begin),
	                  self);
}

GitgConfig *
gitg_config_new (GitgRepository *repository)
{
	return g_object_new (GITG_TYPE_CONFIG, "repository", repository, NULL); 
}

static gchar *
get_value_process (GitgConfig *config, gboolean ret)
{
	gchar *res;

	if (ret)
	{
		res = g_strndup (config->priv->accumulated->str,
		                 config->priv->accumulated->len);
	}
	else
	{
		res = NULL;
	}

	return res;
}

static gchar *
get_value_global (GitgConfig *config, gchar const *key)
{
	gboolean ret = gitg_shell_run (config->priv->shell,
	                               gitg_command_new (config->priv->repository,
	                                                  "config",
	                                                  "--global",
	                                                  key,
	                                                  NULL),
	                               NULL);

	return get_value_process (config, ret);
}

static gchar *
get_value_global_regex (GitgConfig *config,
                        gchar const *regex,
                        gchar const *value_regex)
{
	gboolean ret = gitg_shell_run (config->priv->shell,
	                               gitg_command_new (config->priv->repository,
	                                                  "config",
	                                                  "--global",
	                                                  "--get-regexp",
	                                                  NULL),
	                               NULL);

	return get_value_process (config, ret);
}

static gchar *
get_value_local (GitgConfig *config, gchar const *key)
{
	gboolean ret;
	GFile *git_dir;
	GFile *cfg_file;
	gchar *cfg;

	git_dir = gitg_repository_get_git_dir (config->priv->repository);

	cfg_file = g_file_get_child (git_dir, "config");
	cfg = g_file_get_path (cfg_file);

	ret = gitg_shell_run (config->priv->shell,
	                      gitg_command_new (config->priv->repository,
	                                         "config",
	                                         "--file",
	                                         cfg,
	                                         key,
	                                         NULL),
	                      NULL);

	g_free (cfg);

	g_object_unref (cfg_file);
	g_object_unref (git_dir);

	return get_value_process (config, ret);
}

static gchar *
get_value_local_regex (GitgConfig *config,
                       gchar const *regex,
                       gchar const *value_regex)
{
	gboolean ret;
	GFile *git_dir;
	GFile *cfg_file;
	gchar *cfg;

	git_dir = gitg_repository_get_git_dir (config->priv->repository);

	cfg_file = g_file_get_child (git_dir, "config");
	cfg = g_file_get_path (cfg_file);

	ret = gitg_shell_run (config->priv->shell,
	                      gitg_command_new (config->priv->repository,
	                                         "config",
	                                         "--file",
	                                         cfg,
	                                         "--get-regexp",
	                                         regex,
	                                         value_regex,
	                                         NULL),
	                      NULL);

	g_free (cfg);

	g_object_unref (cfg_file);
	g_object_unref (git_dir);

	return get_value_process (config, ret);
}

static gboolean
set_value_global (GitgConfig *config, gchar const *key, gchar const *value)
{
	return gitg_shell_run (config->priv->shell,
	                       gitg_command_new (config->priv->repository,
	                                          "config",
	                                          "--global",
	                                          value == NULL ? "--unset" : key,
	                                          value == NULL ? key : value,
	                                          NULL),
	                       NULL);
}

static gboolean
set_value_local (GitgConfig *config, gchar const *key, gchar const *value)
{
	gboolean ret;
	GFile *git_dir;
	GFile *cfg_file;
	gchar *cfg;

	git_dir = gitg_repository_get_git_dir (config->priv->repository);

	cfg_file = g_file_get_child (git_dir, "config");
	cfg = g_file_get_path (cfg_file);

	ret = gitg_shell_run (config->priv->shell,
	                      gitg_command_new (config->priv->repository,
	                                         "config",
	                                         "--file",
	                                         cfg,
	                                         value == NULL ? "--unset" : key,
	                                         value == NULL ? key : value,
	                                         NULL),
	                      NULL);

	g_free (cfg);

	g_object_unref (cfg_file);
	g_object_unref (git_dir);

	return ret;
}

static gboolean
rename_global (GitgConfig *config, gchar const *old, gchar const *nw)
{
	return gitg_shell_run (config->priv->shell,
	                       gitg_command_new (config->priv->repository,
	                                          "config",
	                                          "--global",
	                                          "--rename-section",
	                                          old,
	                                          nw,
	                                          NULL),
	                       NULL);
}

static gboolean
rename_local (GitgConfig *config, gchar const *old, gchar const *nw)
{
	gboolean ret;
	GFile *git_dir;
	GFile *cfg_file;
	gchar *cfg;

	git_dir = gitg_repository_get_git_dir (config->priv->repository);

	cfg_file = g_file_get_child (git_dir, "config");
	cfg = g_file_get_path (cfg_file);

	ret = gitg_shell_run (config->priv->shell,
	                      gitg_command_new (config->priv->repository,
	                                         "config",
	                                         "--file",
	                                         cfg,
	                                         "--rename-section",
	                                         old,
	                                         nw,
	                                         NULL),
	                      NULL);

	g_free (cfg);

	g_object_unref (cfg_file);
	g_object_unref (git_dir);

	return ret;
}

gchar *
gitg_config_get_value (GitgConfig *config, gchar const *key)
{
	g_return_val_if_fail (GITG_IS_CONFIG (config), NULL);
	g_return_val_if_fail (key != NULL, NULL);

	if (config->priv->repository != NULL)
	{
		return get_value_local (config, key);
	}
	else
	{
		return get_value_global (config, key);
	}
}

gchar *
gitg_config_get_value_regex (GitgConfig *config,
                             gchar const *regex,
                             gchar const *value_regex)
{
	g_return_val_if_fail (GITG_IS_CONFIG (config), NULL);
	g_return_val_if_fail (regex != NULL, NULL);

	if (config->priv->repository != NULL)
	{
		return get_value_local_regex (config, regex, value_regex);
	}
	else
	{
		return get_value_global_regex (config, regex, value_regex);
	}
}

gboolean
gitg_config_set_value (GitgConfig *config, gchar const *key, gchar const *value)
{
	g_return_val_if_fail (GITG_IS_CONFIG (config), FALSE);
	g_return_val_if_fail (key != NULL, FALSE);

	if (config->priv->repository != NULL)
	{
		return set_value_local (config, key, value);
	}
	else
	{
		return set_value_global (config, key, value);
	}
}

gboolean 
gitg_config_rename (GitgConfig *config, gchar const *old, gchar const *nw)
{
	g_return_val_if_fail (GITG_IS_CONFIG (config), FALSE);
	g_return_val_if_fail (old != NULL, FALSE);
	g_return_val_if_fail (nw != NULL, FALSE);

	if (config->priv->repository != NULL)
	{
		return rename_local (config, old, nw);
	}
	else
	{
		return rename_global (config, old, nw);
	}
}
