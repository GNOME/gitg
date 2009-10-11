#include "gitg-config.h"


#define GITG_CONFIG_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CONFIG, GitgConfigPrivate))

enum
{
	PROP_0,
	PROP_REPOSITORY
};

struct _GitgConfigPrivate
{
	GitgRepository *repository;
	GitgRunner *runner;
	
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
gitg_config_accumulate (GitgRunner *runner, gchar **buffer, GitgConfig *config)
{
	gchar **ptr = buffer;
	
	while (*ptr)
	{
		if (config->priv->accumulated->len != 0)
		{
			g_string_append_c (config->priv->accumulated, '\n');
		}
		
		g_string_append (config->priv->accumulated, *ptr);
		++ptr;
	}
}

static void
gitg_config_begin_loading (GitgRunner *runner, GitgConfig *config)
{
	g_string_erase (config->priv->accumulated, 0, -1);
}

static void
gitg_config_init (GitgConfig *self)
{
	self->priv = GITG_CONFIG_GET_PRIVATE (self);
	
	self->priv->runner = gitg_runner_new_synchronized (1000);
	
	self->priv->accumulated = g_string_new ("");
	
	g_signal_connect (self->priv->runner, 
	                  "update", 
	                  G_CALLBACK (gitg_config_accumulate),
	                  self);

	g_signal_connect (self->priv->runner, 
	                  "begin-loading", 
	                  G_CALLBACK (gitg_config_begin_loading),
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
		res = g_strndup (config->priv->accumulated->str, config->priv->accumulated->len);
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
	gchar const *argv[] = {
		"git",
		"config",
		"--global",
		key,
		NULL
	};

	gboolean ret = gitg_runner_run (config->priv->runner, argv, NULL);
	return get_value_process (config, ret);
}

static gchar *
get_value_global_regex (GitgConfig *config, gchar const *regex)
{
	gchar const *argv[] = {
		"git",
		"config",
		"--global",
		"--get-regexp",
		regex,
		NULL
	};

	gboolean ret = gitg_runner_run (config->priv->runner, argv, NULL);
	return get_value_process (config, ret);
}

static gchar *
get_value_local (GitgConfig *config, gchar const *key)
{
	gboolean ret;
	gchar const *path = gitg_repository_get_path (config->priv->repository);
	gchar *cfg = g_build_filename (path, ".git", "config", NULL);

	ret = gitg_repository_run_commandv (config->priv->repository, 
	                                    config->priv->runner,
	                                    NULL,
	                                    "config",
	                                    "--file",
	                                    cfg,
	                                    key,
	                                    NULL);
	g_free (cfg);
	
	return get_value_process (config, ret);
}

static gchar *
get_value_local_regex (GitgConfig *config, gchar const *regex)
{
	gboolean ret;
	gchar const *path = gitg_repository_get_path (config->priv->repository);
	gchar *cfg = g_build_filename (path, ".git", "config", NULL);

	ret = gitg_repository_run_commandv (config->priv->repository, 
	                                    config->priv->runner,
	                                    NULL,
	                                    "config",
	                                    "--file",
	                                    cfg,
	                                    "--get-regexp",
	                                    regex,
	                                    NULL);
	g_free (cfg);
	
	return get_value_process (config, ret);
}

static gboolean
set_value_global (GitgConfig *config, gchar const *key, gchar const *value)
{
	gchar const *argv[] = {
		"git",
		"config",
		"--global",
		value == NULL ? "--unset" : key,
		value == NULL ? key : value,
		NULL
	};

	return gitg_runner_run (config->priv->runner, argv, NULL);
}

static gboolean
set_value_local (GitgConfig *config, gchar const *key, gchar const *value)
{
	gchar const *path = gitg_repository_get_path (config->priv->repository);
	gchar *cfg = g_build_filename (path, ".git", "config", NULL);

	return gitg_repository_run_commandv (config->priv->repository, 
	                                     config->priv->runner,
	                                     NULL,
	                                     "config",
	                                     "--file",
	                                     cfg,
	                                     value == NULL ? "--unset" : key,
	                                     value == NULL ? key : value,
	                                     NULL);
}

static gboolean
rename_global (GitgConfig *config, gchar const *old, gchar const *nw)
{
	gchar const *argv[] = {
		"git",
		"config",
		"--global",
		"--rename-section",
		old,
		nw,
		NULL
	};

	return gitg_runner_run (config->priv->runner, argv, NULL);
}

static gboolean
rename_local (GitgConfig *config, gchar const *old, gchar const *nw)
{
	gchar const *path = gitg_repository_get_path (config->priv->repository);
	gchar *cfg = g_build_filename (path, ".git", "config", NULL);

	return gitg_repository_run_commandv (config->priv->repository, 
	                                     config->priv->runner,
	                                     NULL,
	                                     "config",
	                                     "--file",
	                                     cfg,
	                                     "--rename-section",
	                                     old,
	                                     nw,
	                                     NULL);
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
gitg_config_get_value_regex (GitgConfig *config, gchar const *regex)
{
	g_return_val_if_fail (GITG_IS_CONFIG (config), NULL);
	g_return_val_if_fail (regex != NULL, NULL);
	
	if (config->priv->repository != NULL)
	{
		return get_value_local_regex (config, regex);
	}
	else
	{
		return get_value_global_regex (config, regex);
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
