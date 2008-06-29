#include "gitg-repository.h"
#include "gitg-utils.h"
#include <glib/gi18n.h>
#include <time.h>

#define GITG_REPOSITORY_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE ((object), GITG_TYPE_REPOSITORY, GitgRepositoryPrivate))

static void gitg_repository_tree_model_iface_init(GtkTreeModelIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgRepository, gitg_repository, G_TYPE_OBJECT, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_TREE_MODEL, gitg_repository_tree_model_iface_init));

/* Properties */
enum {
	PROP_0,
	
	PROP_PATH,
	PROP_LOADER
};

enum
{
	OBJECT_COLUMN,
	SUBJECT_COLUMN,
	AUTHOR_COLUMN,
	DATE_COLUMN,
	N_COLUMNS
};

struct _GitgRepositoryPrivate
{
	gchar *path;
	GitgRunner *loader;
	GHashTable *hashtable;
	gint stamp;
	GType column_types[N_COLUMNS];
	
	GitgRevision **storage;
	gulong size;
	gulong allocated;
	gint grow_size;
};

inline static gint
gitg_repository_error_quark()
{
	static GQuark quark = 0;
	
	if (G_UNLIKELY(quark == 0))
		quark = g_quark_from_static_string("GitgRepositoryErrorQuark");
	
	return quark;
}

/* GtkTreeModel implementations */
static GtkTreeModelFlags 
tree_model_get_flags(GtkTreeModel *tree_model)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), 0);
	return GTK_TREE_MODEL_ITERS_PERSIST | GTK_TREE_MODEL_LIST_ONLY;
}

static gint 
tree_model_get_n_columns(GtkTreeModel *tree_model)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), 0);
	return N_COLUMNS;
}

static GType 
tree_model_get_column_type(GtkTreeModel *tree_model, gint index)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), G_TYPE_INVALID);
	g_return_val_if_fail(index < N_COLUMNS && index >= 0, G_TYPE_INVALID);
	
	return GITG_REPOSITORY(tree_model)->priv->column_types[index];
}

static gboolean
tree_model_get_iter(GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreePath *path)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);
	
	gint *indices;
	gint depth;

	indices = gtk_tree_path_get_indices(path);
	depth = gtk_tree_path_get_depth(path);
	
	GitgRepository *rp = GITG_REPOSITORY(tree_model);

	g_return_val_if_fail(depth == 1, FALSE);
	
	if (indices[0] < 0 || indices[0] >= rp->priv->size)
		return FALSE;
		
	iter->stamp = rp->priv->stamp;
	iter->user_data = GINT_TO_POINTER(indices[0]);
	iter->user_data2 = NULL;
	iter->user_data3 = NULL;
	
	return TRUE;
}

static GtkTreePath *
tree_model_get_path(GtkTreeModel *tree_model, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), NULL);
	
	GitgRepository *rp = GITG_REPOSITORY(tree_model);
	g_return_val_if_fail(iter->stamp == rp->priv->stamp, NULL);
	
	return gtk_tree_path_new_from_indices(GPOINTER_TO_INT(iter->user_data), -1);
}

static gchar *
timestamp_to_str(guint64 timestamp)
{
	struct tm *tms = localtime((time_t *)&timestamp);
	char buf[255];
	
	strftime(buf, 255, "%c", tms);
	return g_strdup(buf);
}

static void 
tree_model_get_value(GtkTreeModel *tree_model, GtkTreeIter *iter, gint column, GValue *value)
{
	g_return_if_fail(GITG_IS_REPOSITORY(tree_model));
	g_return_if_fail(column >= 0 && column < N_COLUMNS);
	
	GitgRepository *rp = GITG_REPOSITORY(tree_model);
	g_return_if_fail(iter->stamp == rp->priv->stamp);

	gint index = GPOINTER_TO_INT(iter->user_data);
	
	g_return_if_fail(index >= 0 && index < rp->priv->size);
	GitgRevision *rv = rp->priv->storage[index];
	
	g_value_init(value, rp->priv->column_types[column]);

	switch (column)
	{
		case OBJECT_COLUMN:
			g_value_set_object(value, rv);
		break;
		case SUBJECT_COLUMN:
			g_value_set_string(value, gitg_revision_get_subject(rv));
		break;
		case AUTHOR_COLUMN:
			g_value_set_string(value, gitg_revision_get_author(rv));
		break;
		case DATE_COLUMN:
			g_value_take_string(value, timestamp_to_str(gitg_revision_get_timestamp(rv)));
		break;
		default:
			g_assert_not_reached();
		break;
	}
}

static gboolean
tree_model_iter_next(GtkTreeModel *tree_model, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);

	GitgRepository *rp = GITG_REPOSITORY(tree_model);
	g_return_val_if_fail(iter->stamp == rp->priv->stamp, FALSE);
	
	gint next = GPOINTER_TO_INT(iter->user_data) + 1;
	
	if (next >= rp->priv->size)
		return FALSE;
	
	iter->user_data = GINT_TO_POINTER(next);
	return TRUE;
}

static gboolean
tree_model_iter_children(GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *parent)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);

	// Only root has children, because it's a flat list
	if (parent != NULL)
		return FALSE;
	
	GitgRepository *rp = GITG_REPOSITORY(tree_model);
	iter->stamp = rp->priv->stamp;
	iter->user_data = GINT_TO_POINTER(0);
	iter->user_data2 = NULL;
	iter->user_data3 = NULL;
	
	return TRUE;
}

static gboolean
tree_model_iter_has_child(GtkTreeModel *tree_model, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);
	
	// Only root (NULL) has children
	return iter == NULL;
}

static gint
tree_model_iter_n_children(GtkTreeModel *tree_model, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), 0);
	GitgRepository *rp = GITG_REPOSITORY(tree_model);
	
	return iter ? 0 : rp->priv->size;
}

static gboolean
tree_model_iter_nth_child(GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *parent, gint n)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);
	g_return_val_if_fail(n >= 0, FALSE);

	if (parent)
		return FALSE;

	GitgRepository *rp = GITG_REPOSITORY(tree_model);	
	g_return_val_if_fail(n < rp->priv->size, FALSE);
	
	iter->stamp = rp->priv->stamp;
	iter->user_data = GINT_TO_POINTER(n);
	iter->user_data2 = NULL;
	iter->user_data3 = NULL;
	
	return TRUE;
}

static gboolean 
tree_model_iter_parent(GtkTreeModel *tree_model, GtkTreeIter *iter, GtkTreeIter *child)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(tree_model), FALSE);
	return FALSE;
}

static GType
gitg_repository_get_column_type(GtkTreeModel *self, int column)
{
	/* validate our parameters */
	g_return_val_if_fail(GITG_IS_REPOSITORY(self), G_TYPE_INVALID);
	g_return_val_if_fail(column >= 0 && column < N_COLUMNS, G_TYPE_INVALID);

	return GITG_REPOSITORY(self)->priv->column_types[column];
}

static void
gitg_repository_tree_model_iface_init(GtkTreeModelIface *iface)
{
	iface->get_flags = tree_model_get_flags;
	iface->get_n_columns = tree_model_get_n_columns;
	iface->get_column_type = tree_model_get_column_type;
	iface->get_iter = tree_model_get_iter;
	iface->get_path = tree_model_get_path;
	iface->get_value = tree_model_get_value;
	iface->iter_next = tree_model_iter_next;
	iface->iter_children = tree_model_iter_children;
	iface->iter_has_child = tree_model_iter_has_child;
	iface->iter_n_children = tree_model_iter_n_children;
	iface->iter_nth_child = tree_model_iter_nth_child;
	iface->iter_parent = tree_model_iter_parent;
}

static void
do_clear(GitgRepository *repository, gboolean emit)
{
	int i;
	GtkTreePath *path = gtk_tree_path_new_from_indices(repository->priv->size - 1, -1);
	
	for (i = repository->priv->size - 1; i >= 0; --i)
	{
		if (emit)
		{
			GtkTreePath *dup = gtk_tree_path_copy(path);
			gtk_tree_model_row_deleted(GTK_TREE_MODEL(repository), dup);
			gtk_tree_path_free(dup);
		}
		
		gtk_tree_path_prev(path);
		g_object_unref(repository->priv->storage[i]);
	}
	
	gtk_tree_path_free(path);
	
	if (repository->priv->storage)
		g_slice_free1(sizeof(GitgRevision *) * repository->priv->size, repository->priv->storage);
	
	repository->priv->storage = NULL;
	repository->priv->size = 0;
	repository->priv->allocated = 0;
}

static void
gitg_repository_finalize(GObject *object)
{
	GitgRepository *rp = GITG_REPOSITORY(object);
	
	// Make sure to cancel the loader
	gitg_runner_cancel(rp->priv->loader);
	g_object_unref(rp->priv->loader);
	
	// Clear the model to remove all revision objects
	do_clear(rp, FALSE);
	
	// Free the path
	g_free(rp->priv->path);
	
	// Free the hash
	g_hash_table_destroy(rp->priv->hashtable);

	G_OBJECT_CLASS (gitg_repository_parent_class)->finalize(object);
}

static void
gitg_repository_set_property(GObject *object, guint prop_id, GValue const *value, GParamSpec *pspec)
{
	GitgRepository *self = GITG_REPOSITORY(object);
	
	switch (prop_id)
	{
		case PROP_PATH:
			g_free(self->priv->path);
			self->priv->path = gitg_utils_find_git(g_value_get_string(value));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_repository_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgRepository *self = GITG_REPOSITORY(object);
	
	switch (prop_id)
	{
		case PROP_PATH:
			g_value_set_string(value, self->priv->path);
		break;
		case PROP_LOADER:
			g_value_set_object(value, self->priv->loader);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void 
gitg_repository_class_init(GitgRepositoryClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	object_class->finalize = gitg_repository_finalize;
	
	object_class->set_property = gitg_repository_set_property;
	object_class->get_property = gitg_repository_get_property;
	
	g_object_class_install_property(object_class, PROP_PATH,
						 g_param_spec_string ("path",
								      "PATH",
								      "The repository path",
								      NULL,
								      G_PARAM_READWRITE | G_PARAM_CONSTRUCT));
	
	g_object_class_install_property(object_class, PROP_LOADER,
						 g_param_spec_object ("loader",
								      "LOADER",
								      "The repository loader",
								      GITG_TYPE_RUNNER,
								      G_PARAM_READABLE));
	
	g_type_class_add_private(object_class, sizeof(GitgRepositoryPrivate));
}

static guint
hash_hash(gconstpointer v)
{
	/* 31 bit hash function, copied from g_str_hash */
	const signed char *p = v;
	guint32 h = *p;
	int i;
	
	for (i = 1; i < 20; ++i)
		h = (h << 5) - h + p[i];

	return h;
}

static gboolean 
hash_equal(gconstpointer a, gconstpointer b)
{
	return strncmp((char const *)a, (char const *)b, 20) == 0;
}

static void
on_loader_update(GitgRunner *object, gchar **buffer, GitgRepository *self)
{
	gchar *line;

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
	
		GitgRevision *rv = gitg_revision_new(components[0], components[1], components[2], components[3], timestamp);
		gitg_repository_add(self, rv, NULL);

		g_object_unref(rv);
		g_strfreev(components);
	}
}

static void
gitg_repository_init(GitgRepository *object)
{
	object->priv = GITG_REPOSITORY_GET_PRIVATE(object);
	object->priv->hashtable = g_hash_table_new_full(hash_hash, hash_equal, NULL, NULL);
	
	object->priv->column_types[0] = GITG_TYPE_REVISION;
	object->priv->column_types[1] = G_TYPE_STRING;
	object->priv->column_types[2] = G_TYPE_STRING;
	object->priv->column_types[3] = G_TYPE_STRING;
	
	object->priv->grow_size = 1000;
	object->priv->stamp = g_random_int();
	
	object->priv->loader = gitg_runner_new(5000);
	g_signal_connect(object->priv->loader, "update", G_CALLBACK(on_loader_update), object);
}

static void
grow_storage(GitgRepository *repository, gint size)
{
	if (repository->priv->size + size <= repository->priv->allocated)
		return;
	
	gulong prevallocated = repository->priv->allocated;
	repository->priv->allocated += repository->priv->grow_size;
	GitgRevision **newstorage = g_slice_alloc(sizeof(GitgRevision *) * repository->priv->allocated);
	
	int i;
	for (i = 0; i < repository->priv->size; ++i)
		newstorage[i] = repository->priv->storage[i];
	
	if (repository->priv->storage)
		g_slice_free1(sizeof(GitgRevision *) * prevallocated, repository->priv->storage);
		
	repository->priv->storage = newstorage;
}

GitgRepository *
gitg_repository_new(gchar const *path)
{
	return g_object_new(GITG_TYPE_REPOSITORY, "path", path, NULL);
}

gchar const *
gitg_repository_get_path(GitgRepository *self)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(self), NULL);
	
	return self->priv->path;
}

GitgRunner *
gitg_repository_get_loader(GitgRepository *self)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(self), NULL);
	return GITG_RUNNER(g_object_ref(self->priv->loader));
}

gboolean
gitg_repository_load(GitgRepository *self, GError **error)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(self), FALSE);
	
	if (self->priv->path == NULL)
	{
		if (error)
			*error = g_error_new_literal(gitg_repository_error_quark(), GITG_REPOSITORY_ERROR_NOT_FOUND, _("Not a valid git repository"));
			
		return FALSE;
	}

	gitg_runner_cancel(self->priv->loader);
	gitg_repository_clear(self);
	
	gchar *argv[] = {
		"git",
		"--git-dir",
		gitg_utils_dot_git_path(self->priv->path),
		"log",
		"--encoding=UTF-8",
		"--topo-order",
		"--pretty=format:%H\01%an\01%s\01%P\01%at",
		"HEAD",
		NULL
	};
	
	gboolean ret = gitg_runner_run(self->priv->loader, argv, error);
	g_free(argv[2]);
	
	return ret;
}

void
gitg_repository_add(GitgRepository *self, GitgRevision *obj, GtkTreeIter *iter)
{
	GtkTreeIter iter1;

	/* validate our parameters */
	g_return_if_fail(GITG_IS_REPOSITORY(self));
	g_return_if_fail(GITG_IS_REVISION(obj));
	
	grow_storage(self, 1);

	/* put this object in our data storage */
	self->priv->storage[self->priv->size++] = g_object_ref(obj);

	g_hash_table_insert(self->priv->hashtable, (gpointer)gitg_revision_get_hash(obj), GUINT_TO_POINTER(self->priv->size - 1));

	iter1.stamp = self->priv->stamp;
	iter1.user_data = GINT_TO_POINTER(self->priv->size - 1);
	iter1.user_data2 = NULL;
	iter1.user_data3 = NULL;
	
	GtkTreePath *path = gtk_tree_path_new_from_indices(self->priv->size - 1, -1);
	gtk_tree_model_row_inserted(GTK_TREE_MODEL(self), path, &iter1);
	gtk_tree_path_free(path);
	
	/* return the iter if the user cares */
	if (iter)
		*iter = iter1;
}

void
gitg_repository_clear(GitgRepository *repository)
{
	g_return_if_fail(GITG_IS_REPOSITORY(repository));
	do_clear(repository, TRUE);
}

gboolean
gitg_repository_find_by_hash(GitgRepository *store, gchar const *hash, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REPOSITORY(store), FALSE);
	
	gpointer result = g_hash_table_lookup(store->priv->hashtable, hash);
	
	if (!result)
		return FALSE;
	
	GtkTreePath *path = gtk_tree_path_new_from_indices(GPOINTER_TO_UINT(result), -1);
	gtk_tree_model_get_iter(GTK_TREE_MODEL(store), iter, path);
	gtk_tree_path_free(path);

	return TRUE;
}

gboolean
gitg_repository_find(GitgRepository *store, GitgRevision *revision, GtkTreeIter *iter)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), FALSE);
	
	return gitg_repository_find_by_hash(store, gitg_revision_get_hash(revision), iter);
}

