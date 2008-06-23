#include "gitg-loader.h"

#define GITG_LOADER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_LOADER, GitgLoaderPrivate))

static void impl_update(GitgRunner *runner, gchar **buffer);

/* Signals */
enum
{
	REVISIONS_ADDED,
	LAST_SIGNAL
};

static guint loader_signals[LAST_SIGNAL] = { 0 };

struct _GitgLoaderPrivate
{
	GitgRevision **buffer;
	GitgRvModel *store;
};

G_DEFINE_TYPE(GitgLoader, gitg_loader, GITG_TYPE_RUNNER)

static void
gitg_loader_finalize(GObject *object)
{
	GitgLoader *loader = GITG_LOADER(object);
	guint size = gitg_runner_get_buffer_size(GITG_RUNNER(loader));

	g_slice_free1(sizeof(GitgRevision *) * (size + 1), loader->priv->buffer);
	G_OBJECT_CLASS(gitg_loader_parent_class)->finalize(object);
}

static GObject *
gitg_loader_constructor(GType type, guint n_construct_properties,
		GObjectConstructParam *construct_properties)
{
	GObject *object;
	
	{
		object = G_OBJECT_CLASS(gitg_loader_parent_class)->constructor(type, n_construct_properties, construct_properties);
	}
	
	GitgLoader *loader = GITG_LOADER(object);

	guint bs = gitg_runner_get_buffer_size(GITG_RUNNER(loader));
	loader->priv->buffer = g_slice_alloc(sizeof(GitgRevision *) * (bs + 1));
	loader->priv->buffer[0] = NULL;
	
	return object;
}

static void
gitg_loader_class_init(GitgLoaderClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GitgRunnerClass *runner_class = GITG_RUNNER_CLASS(klass);
	
	object_class->finalize = gitg_loader_finalize;
	object_class->constructor = gitg_loader_constructor;
	
	runner_class->update = impl_update;

	loader_signals[REVISIONS_ADDED] =
   		g_signal_new ("revisions-added",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgLoaderClass, revisions_added),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__POINTER,
			      G_TYPE_NONE,
			      1,
			      G_TYPE_POINTER);

	g_type_class_add_private(object_class, sizeof(GitgLoaderPrivate));
}

static void
gitg_loader_init(GitgLoader *self)
{
	self->priv = GITG_LOADER_GET_PRIVATE(self);
}

static void
impl_update(GitgRunner *runner, gchar **buffer)
{
	GitgLoader *loader = GITG_LOADER(runner);
	gchar *line;
	GitgRevision **ptr = loader->priv->buffer;

	while ((line = *buffer++))
	{
		// New line is read
		gchar **components = g_strsplit(line, "\01", 0);
		
		if (g_strv_length(components) < 5)
		{
			g_strfreev(components);
			continue;
		}
		
		// components -> [hash, author, subject, parents ([1 2 3]), timestamp]
		gint64 timestamp = g_ascii_strtoll(components[4], NULL, 0);
	
		*ptr++ = gitg_revision_new(components[0], components[1], components[2], components[3], timestamp);

		g_strfreev(components);
	}
	
	*ptr = NULL;
	g_signal_emit(loader, loader_signals[REVISIONS_ADDED], 0, loader->priv->buffer);
	
	/* Make sure to unref all the revision objects */
	GitgRevision *rv;
	ptr = loader->priv->buffer;

	while ((rv = *ptr++))
		g_object_unref(rv);
	
	loader->priv->buffer[0] = NULL;
}

GitgLoader*
gitg_loader_new()
{
	return GITG_LOADER(g_object_new(GITG_TYPE_LOADER, "buffer_size", 3000, NULL));
}

gboolean
gitg_loader_load(GitgLoader *loader, gchar const *path, GError **error)
{
	g_return_val_if_fail(GITG_IS_LOADER(loader), FALSE);
	g_return_val_if_fail(loader->priv != NULL, FALSE);
	g_return_val_if_fail(path != NULL, FALSE);
	
	gchar *argv[] = {
		"git",
		"--git-dir",
		(gchar *)path,
		"log",
		"--topo-order",
		"--pretty=format:%H\01%an\01%s\01%P\01%at",
		"HEAD",
		NULL
	};
	
	return gitg_runner_run(GITG_RUNNER(loader), argv, error);
}
