#include "gitg-changed-file.h"
#include "gitg-enum-types.h"

#define GITG_CHANGED_FILE_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CHANGED_FILE, GitgChangedFilePrivate))

struct _GitgChangedFilePrivate
{
	GFile *file;
	
	GitgChangedFileStatus status;
	GitgChangedFileChanges changes;
	
	gchar *sha;
	gchar *mode;
};

/* Properties */
enum
{
	PROP_0,
	PROP_FILE,
	PROP_STATUS,
	PROP_CHANGES,
	PROP_SHA,
	PROP_MODE
};

G_DEFINE_TYPE(GitgChangedFile, gitg_changed_file, G_TYPE_OBJECT)

static void
gitg_changed_file_finalize(GObject *object)
{
	GitgChangedFile *self = GITG_CHANGED_FILE(object);

	g_free(self->priv->sha);
	g_free(self->priv->mode);
	g_object_unref(self->priv->file);

	G_OBJECT_CLASS(gitg_changed_file_parent_class)->finalize(object);
}

static void
gitg_changed_file_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgChangedFile *self = GITG_CHANGED_FILE(object);

	switch (prop_id)
	{
		case PROP_FILE:
			g_value_set_object(value, self->priv->file);
		break;
		case PROP_STATUS:
			g_value_set_enum(value, self->priv->status);
		break;
		case PROP_CHANGES:
			g_value_set_enum(value, self->priv->changes);
		break;
		case PROP_SHA:
			g_value_set_string(value, self->priv->sha);
		break;
		case PROP_MODE:
			g_value_set_string(value, self->priv->mode);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
set_sha_real(GitgChangedFile *self, gchar const *sha)
{
	g_free(self->priv->sha);
	self->priv->sha = g_strdup(sha);
}

static void
set_mode_real(GitgChangedFile *self, gchar const *mode)
{
	g_free(self->priv->mode);
	self->priv->mode = g_strdup(mode);
}

static void
gitg_changed_file_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgChangedFile *self = GITG_CHANGED_FILE(object);
	
	switch (prop_id)
	{
		case PROP_FILE:
			self->priv->file = g_value_dup_object(value);
		break;
		case PROP_STATUS:
			self->priv->status = g_value_get_enum(value);
		break;
		case PROP_CHANGES:
			self->priv->changes = g_value_get_enum(value);
		break;
		case PROP_SHA:
			set_sha_real(self, g_value_get_string(value));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_changed_file_class_init(GitgChangedFileClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	
	object_class->finalize = gitg_changed_file_finalize;
	object_class->set_property = gitg_changed_file_set_property;
	object_class->get_property = gitg_changed_file_get_property;
	
	g_object_class_install_property(object_class, PROP_FILE,
					 g_param_spec_object("file",
							      "FILE",
							      "File",
							      G_TYPE_OBJECT,
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));
	
	g_object_class_install_property(object_class, PROP_STATUS,
					 g_param_spec_enum("status",
							      "STATUS",
							      "Status",
							      GITG_TYPE_CHANGED_FILE_STATUS,
							      GITG_CHANGED_FILE_STATUS_NEW,
							      G_PARAM_READWRITE));
	
	g_object_class_install_property(object_class, PROP_CHANGES,
					 g_param_spec_enum("changes",
							      "CHANGES",
							      "Changes",
							      GITG_TYPE_CHANGED_FILE_CHANGES,
							      GITG_CHANGED_FILE_CHANGES_NONE,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_SHA,
					 g_param_spec_string("sha",
							      "SHA",
							      "Sha",
							      NULL,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_MODE,
					 g_param_spec_string("mode",
							      "MODE",
							      "Mode",
							      NULL,
							      G_PARAM_READWRITE));

	g_type_class_add_private(object_class, sizeof(GitgChangedFilePrivate));
}

static void
gitg_changed_file_init(GitgChangedFile *self)
{
	self->priv = GITG_CHANGED_FILE_GET_PRIVATE (self);
}

GitgChangedFile*
gitg_changed_file_new(GFile *file)
{
	return g_object_new(GITG_TYPE_CHANGED_FILE, "file", file, NULL);
}

GFile *
gitg_changed_file_get_file(GitgChangedFile *file)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), NULL);
	
	return g_object_ref(file->priv->file);
}

gchar const *
gitg_changed_file_get_sha(GitgChangedFile *file)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), NULL);
	
	return file->priv->sha;
}

gchar const *
gitg_changed_file_get_mode(GitgChangedFile *file)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), NULL);
	
	return file->priv->mode;
}

void
gitg_changed_file_set_sha(GitgChangedFile *file, gchar const *sha)
{
	g_return_if_fail(GITG_IS_CHANGED_FILE(file));
	
	set_sha_real(file, sha);
	g_object_notify(G_OBJECT(file), "sha");
}

void 
gitg_changed_file_set_mode(GitgChangedFile *file, gchar const *mode)
{
	g_return_if_fail(GITG_IS_CHANGED_FILE(file));
	
	set_mode_real(file, mode);
	g_object_notify(G_OBJECT(file), "mode");
}

GitgChangedFileStatus gitg_changed_file_get_status(GitgChangedFile *file)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), GITG_CHANGED_FILE_STATUS_NONE);
	
	return file->priv->status;
}

GitgChangedFileChanges gitg_changed_file_get_changes(GitgChangedFile *file)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), GITG_CHANGED_FILE_CHANGES_NONE);
	
	return file->priv->changes;
}

void gitg_changed_file_set_status(GitgChangedFile *file, GitgChangedFileStatus status)
{
	g_return_if_fail(GITG_IS_CHANGED_FILE(file));
	
	file->priv->status = status;
	g_object_notify(G_OBJECT(file), "status");
}

void
gitg_changed_file_set_changes(GitgChangedFile *file, GitgChangedFileChanges changes)
{
	g_return_if_fail(GITG_IS_CHANGED_FILE(file));
	
	file->priv->changes = changes;
	g_object_notify(G_OBJECT(file), "changes");
}

gboolean 
gitg_changed_file_equal(GitgChangedFile *file, GFile *other)
{
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), FALSE);
	
	return g_file_equal(file->priv->file, other);
}
