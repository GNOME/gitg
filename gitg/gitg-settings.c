#include "gitg-settings.h"

#define KEY_GROUP "gitg"

#define GITG_SETTINGS_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_SETTINGS, GitgSettingsPrivate))

struct _GitgSettingsPrivate
{
	GKeyFile *file;
	gchar *filename;
};

G_DEFINE_TYPE(GitgSettings, gitg_settings, G_TYPE_OBJECT)

static void
gitg_settings_finalize(GObject *object)
{
	GitgSettings *settings = GITG_SETTINGS(object);
	
	gitg_settings_save(settings);
	
	g_free(settings->priv->filename);
	g_key_file_free(settings->priv->file);

	G_OBJECT_CLASS(gitg_settings_parent_class)->finalize(object);
}

static void
gitg_settings_class_init(GitgSettingsClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_settings_finalize;

	g_type_class_add_private(object_class, sizeof(GitgSettingsPrivate));
}

static void
gitg_settings_init(GitgSettings *self)
{
	self->priv = GITG_SETTINGS_GET_PRIVATE(self);
	
	self->priv->file = g_key_file_new();
	self->priv->filename = g_build_filename(g_get_user_config_dir(), "gitg", "settings", NULL);
	
	g_key_file_load_from_file(self->priv->file, self->priv->filename, G_KEY_FILE_KEEP_COMMENTS | G_KEY_FILE_KEEP_TRANSLATIONS, NULL);
}

GitgSettings*
gitg_settings_get_default()
{
	static GitgSettings *instance = NULL;
	
	if (G_UNLIKELY(instance == NULL))
		instance = GITG_SETTINGS(g_object_new(GITG_TYPE_SETTINGS, NULL));
	
	return instance;
}

void
gitg_settings_save(GitgSettings *settings)
{
	g_return_if_fail(GITG_IS_SETTINGS(settings));
	
	gchar *d = g_path_get_dirname(settings->priv->filename);
	g_mkdir_with_parents(d, 0755);
	g_free(d);
	
	gssize length;
	gchar *data = g_key_file_to_data(settings->priv->file, &length, NULL);
	
	if (data)
	{
		g_file_set_contents(settings->priv->filename, data, length, NULL);
		g_free(data);
	}
}

gint 
gitg_settings_get_integer(GitgSettings *settings, gchar const *key, gint def)
{
	g_return_val_if_fail(GITG_IS_SETTINGS(settings), def);

	GError *error = NULL;
	
	gint ret = g_key_file_get_integer(settings->priv->file, KEY_GROUP, key, &error);
	
	if (error)
	{
		ret = def;
		g_error_free(error);
	}
	
	return ret;
}

gdouble 
gitg_settings_get_double(GitgSettings *settings, gchar const *key, gdouble def)
{
	g_return_val_if_fail(GITG_IS_SETTINGS(settings), def);

	GError *error = NULL;
	
	gdouble ret = g_key_file_get_double(settings->priv->file, KEY_GROUP, key, &error);
	
	if (error)
	{
		ret = def;
		g_error_free(error);
	}
	
	return ret;

}

gchar *
gitg_settings_get_string(GitgSettings *settings, gchar const *key, gchar const *def)
{
	g_return_val_if_fail(GITG_IS_SETTINGS(settings), g_strdup(def));

	GError *error = NULL;
	
	gchar *ret = g_key_file_get_string(settings->priv->file, KEY_GROUP, key, &error);
	
	if (error)
	{
		ret = g_strdup(def);
		g_error_free(error);
	}
	
	return ret;
}

void 
gitg_settings_set_integer(GitgSettings *settings, gchar const *key, gint value)
{
	g_return_if_fail(GITG_IS_SETTINGS(settings));

	g_key_file_set_integer(settings->priv->file, KEY_GROUP, key, value);
}

void
gitg_settings_set_double(GitgSettings *settings, gchar const *key, gdouble value)
{
	g_return_if_fail(GITG_IS_SETTINGS(settings));
	
	g_key_file_set_double(settings->priv->file, KEY_GROUP, key, value);
}

void 
gitg_settings_set_string(GitgSettings *settings, gchar const *key, gchar const *value)
{
	g_return_if_fail(GITG_IS_SETTINGS(settings));
	
	g_key_file_set_string(settings->priv->file, KEY_GROUP, key, value);
}

