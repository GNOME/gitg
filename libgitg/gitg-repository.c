/*
 * gitg-repository.c
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

#include "gitg-repository.h"
#include "gitg-hash.h"
#include "gitg-i18n.h"
#include "gitg-lanes.h"
#include "gitg-ref.h"
#include "gitg-config.h"
#include "gitg-shell.h"

#include <gio/gio.h>
#include <sys/time.h>
#include <time.h>
#include <string.h>

#define GITG_REPOSITORY_GET_PRIVATE(object) (G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REPOSITORY, GitgRepositoryPrivate))

static void gitg_repository_tree_model_iface_init (GtkTreeModelIface *iface);

G_DEFINE_TYPE_EXTENDED (GitgRepository, gitg_repository, G_TYPE_OBJECT, 0,
	G_IMPLEMENT_INTERFACE (GTK_TYPE_TREE_MODEL, gitg_repository_tree_model_iface_init));

/* Properties */
enum
{
	PROP_0,
	PROP_WORK_TREE,
	PROP_GIT_DIR,
	PROP_PATH,
	PROP_LOADER,
	PROP_SHOW_STAGED,
	PROP_SHOW_UNSTAGED,
	PROP_SHOW_STASH,
	PROP_TOPO_ORDER,
	PROP_INACTIVE_MAX,
	PROP_INACTIVE_COLLAPSE,
	PROP_INACTIVE_GAP,
	PROP_INACTIVE_ENABLED
};

/* Signals */
enum
{
	LOAD,
	LOADED,
	LAST_SIGNAL
};

static guint repository_signals[LAST_SIGNAL] = { 0 };

enum
{
	OBJECT_COLUMN,
	SUBJECT_COLUMN,
	AUTHOR_COLUMN,
	DATE_COLUMN,
	N_COLUMNS
};

typedef enum
{
	LOAD_STAGE_NONE = 0,
	LOAD_STAGE_STASH,
	LOAD_STAGE_STAGED,
	LOAD_STAGE_UNSTAGED,
	LOAD_STAGE_COMMITS,
	LOAD_STAGE_LAST
} LoadStage;

struct _GitgRepositoryPrivate
{
	GFile *git_dir;
	GFile *work_tree;

	GitgShell *loader;
	GHashTable *hashtable;
	gint stamp;
	GType column_types[N_COLUMNS];

	GHashTable *ref_pushes;
	GHashTable *ref_names;

	GitgRevision **storage;
	GitgLanes *lanes;
	GHashTable *refs;
	GitgRef *current_ref;
	GitgRef *working_ref;

	gulong size;
	gulong allocated;
	gint grow_size;

	gchar **last_args;
	gchar **selection;

	guint idle_relane_id;

	LoadStage load_stage;

	GFileMonitor *monitor;

	guint show_staged : 1;
	guint show_unstaged : 1;
	guint show_stash : 1;
	guint topoorder : 1;
};

static gboolean repository_relane (GitgRepository *repository);
static void build_log_args (GitgRepository  *self,
                            gint             argc,
                            gchar const    **av);

inline static gint
gitg_repository_error_quark ()
{
	static GQuark quark = 0;

	if (G_UNLIKELY (quark == 0))
	{
		quark = g_quark_from_static_string ("GitgRepositoryErrorQuark");
	}

	return quark;
}

/* GtkTreeModel implementations */
static GtkTreeModelFlags
tree_model_get_flags (GtkTreeModel *tree_model)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), 0);
	return GTK_TREE_MODEL_ITERS_PERSIST | GTK_TREE_MODEL_LIST_ONLY;
}

static gint
tree_model_get_n_columns (GtkTreeModel *tree_model)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), 0);
	return N_COLUMNS;
}

static GType
tree_model_get_column_type (GtkTreeModel *tree_model,
                            gint          index)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), G_TYPE_INVALID);
	g_return_val_if_fail (index < N_COLUMNS && index >= 0, G_TYPE_INVALID);

	return GITG_REPOSITORY (tree_model)->priv->column_types[index];
}

static void
fill_iter (GitgRepository *repository,
           gint            index,
           GtkTreeIter    *iter)
{
	iter->stamp = repository->priv->stamp;
	iter->user_data = GINT_TO_POINTER (index);
}

static gboolean
tree_model_get_iter (GtkTreeModel *tree_model,
                     GtkTreeIter  *iter,
                     GtkTreePath  *path)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);

	gint *indices;
	gint depth;

	indices = gtk_tree_path_get_indices (path);
	depth = gtk_tree_path_get_depth (path);

	GitgRepository *rp = GITG_REPOSITORY (tree_model);

	g_return_val_if_fail (depth == 1, FALSE);

	if (indices[0] < 0 || indices[0] >= rp->priv->size)
		return FALSE;

	fill_iter (rp, indices[0], iter);

	return TRUE;
}

static GtkTreePath *
tree_model_get_path (GtkTreeModel *tree_model,
                     GtkTreeIter  *iter)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), NULL);

	GitgRepository *rp = GITG_REPOSITORY (tree_model);
	g_return_val_if_fail (iter->stamp == rp->priv->stamp, NULL);

	return gtk_tree_path_new_from_indices (GPOINTER_TO_INT (iter->user_data), -1);
}

static void
tree_model_get_value (GtkTreeModel *tree_model,
                      GtkTreeIter  *iter,
                      gint          column,
                      GValue       *value)
{
	g_return_if_fail (GITG_IS_REPOSITORY (tree_model));
	g_return_if_fail (column >= 0 && column < N_COLUMNS);

	GitgRepository *rp = GITG_REPOSITORY (tree_model);
	g_return_if_fail (iter->stamp == rp->priv->stamp);

	gint index = GPOINTER_TO_INT (iter->user_data);

	g_return_if_fail (index >= 0 && index < rp->priv->size);
	GitgRevision *rv = rp->priv->storage[index];

	g_value_init (value, rp->priv->column_types[column]);

	switch (column)
	{
		case OBJECT_COLUMN:
			g_value_set_boxed (value, rv);
		break;
		case SUBJECT_COLUMN:
			g_value_set_string (value, gitg_revision_get_subject (rv));
		break;
		case AUTHOR_COLUMN:
			g_value_set_string (value, gitg_revision_get_author (rv));
		break;
		case DATE_COLUMN:
			g_value_take_string (value, gitg_revision_get_author_date_for_display (rv));
		break;
		default:
			g_assert_not_reached ();
		break;
	}
}

static gboolean
tree_model_iter_next (GtkTreeModel *tree_model,
                      GtkTreeIter  *iter)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);

	GitgRepository *rp = GITG_REPOSITORY (tree_model);
	g_return_val_if_fail (iter->stamp == rp->priv->stamp, FALSE);

	gint next = GPOINTER_TO_INT (iter->user_data) + 1;

	if (next >= rp->priv->size)
		return FALSE;

	iter->user_data = GINT_TO_POINTER (next);
	return TRUE;
}

static gboolean
tree_model_iter_children (GtkTreeModel *tree_model,
                          GtkTreeIter  *iter,
                          GtkTreeIter  *parent)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);

	// Only root has children, because it's a flat list
	if (parent != NULL)
	{
		return FALSE;
	}

	GitgRepository *rp = GITG_REPOSITORY (tree_model);
	fill_iter (rp, 0, iter);

	return TRUE;
}

static gboolean
tree_model_iter_has_child (GtkTreeModel *tree_model,
                           GtkTreeIter  *iter)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);

	// Only root (NULL) has children
	return iter == NULL;
}

static gint
tree_model_iter_n_children (GtkTreeModel *tree_model,
                            GtkTreeIter  *iter)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), 0);
	GitgRepository *rp = GITG_REPOSITORY (tree_model);

	return iter ? 0 : rp->priv->size;
}

static gboolean
tree_model_iter_nth_child (GtkTreeModel *tree_model,
                           GtkTreeIter  *iter,
                           GtkTreeIter  *parent,
                           gint          n)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);
	g_return_val_if_fail (n >= 0, FALSE);

	if (parent)
	{
		return FALSE;
	}

	GitgRepository *rp = GITG_REPOSITORY (tree_model);
	g_return_val_if_fail (n < rp->priv->size, FALSE);

	fill_iter (rp, n, iter);

	return TRUE;
}

static gboolean
tree_model_iter_parent (GtkTreeModel *tree_model,
                        GtkTreeIter  *iter,
                        GtkTreeIter  *child)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (tree_model), FALSE);
	return FALSE;
}

static void
gitg_repository_tree_model_iface_init (GtkTreeModelIface *iface)
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
do_clear (GitgRepository *repository,
          gboolean        emit)
{
	gint i;
	GtkTreePath *path = gtk_tree_path_new_from_indices (repository->priv->size - 1, -1);

	for (i = repository->priv->size - 1; i >= 0; --i)
	{
		if (emit)
		{
			GtkTreePath *dup = gtk_tree_path_copy (path);
			gtk_tree_model_row_deleted (GTK_TREE_MODEL (repository), dup);
			gtk_tree_path_free (dup);
		}

		gtk_tree_path_prev (path);
		gitg_revision_unref (repository->priv->storage[i]);
	}

	gtk_tree_path_free (path);

	if (repository->priv->storage)
	{
		g_slice_free1 (sizeof (GitgRevision *) * repository->priv->size,
		               repository->priv->storage);
	}

	repository->priv->storage = NULL;
	repository->priv->size = 0;
	repository->priv->allocated = 0;

	gitg_ref_free (repository->priv->current_ref);
	repository->priv->current_ref = NULL;

	/* clear hash tables */
	g_hash_table_remove_all (repository->priv->hashtable);
	g_hash_table_remove_all (repository->priv->refs);
	g_hash_table_remove_all (repository->priv->ref_names);
	g_hash_table_remove_all (repository->priv->ref_pushes);

	gitg_color_reset ();
}

static void
prepare_relane (GitgRepository *repository)
{
	if (!repository->priv->idle_relane_id)
	{
		repository->priv->idle_relane_id = g_idle_add ((GSourceFunc)repository_relane, repository);
	}
}

static void
gitg_repository_finalize (GObject *object)
{
	GitgRepository *rp = GITG_REPOSITORY (object);

	/* Make sure to cancel the loader */
	gitg_io_cancel (GITG_IO (rp->priv->loader));
	g_object_unref (rp->priv->loader);

	g_object_unref (rp->priv->lanes);

	/* Clear the model to remove all revision objects */
	do_clear (rp, FALSE);

	if (rp->priv->work_tree)
	{
		g_object_unref (rp->priv->work_tree);
	}

	if (rp->priv->git_dir)
	{
		g_object_unref (rp->priv->git_dir);
	}

	/* Free the hash */
	g_hash_table_destroy (rp->priv->hashtable);
	g_hash_table_destroy (rp->priv->refs);
	g_hash_table_destroy (rp->priv->ref_names);
	g_hash_table_destroy (rp->priv->ref_pushes);

	/* Free cached args */
	g_strfreev (rp->priv->last_args);
	g_strfreev (rp->priv->selection);

	if (rp->priv->idle_relane_id)
	{
		g_source_remove (rp->priv->idle_relane_id);
	}

	if (rp->priv->current_ref)
	{
		gitg_ref_free (rp->priv->current_ref);
	}

	if (rp->priv->working_ref)
	{
		gitg_ref_free (rp->priv->working_ref);
	}

	if (rp->priv->monitor)
	{
		g_file_monitor_cancel (rp->priv->monitor);
		g_object_unref (rp->priv->monitor);
	}

	G_OBJECT_CLASS (gitg_repository_parent_class)->finalize (object);
}

static void
gitg_repository_set_property (GObject      *object,
                              guint         prop_id,
                              GValue const *value,
                              GParamSpec   *pspec)
{
	GitgRepository *self = GITG_REPOSITORY (object);

	switch (prop_id)
	{
		case PROP_WORK_TREE:
			if (self->priv->work_tree)
			{
				g_object_unref (self->priv->work_tree);
			}

			self->priv->work_tree = g_value_dup_object (value);
		break;
		case PROP_GIT_DIR:
			if (self->priv->git_dir)
			{
				g_object_unref (self->priv->git_dir);
			}

			self->priv->git_dir = g_value_dup_object (value);
		break;
		case PROP_SHOW_STAGED:
			self->priv->show_staged = g_value_get_boolean (value);
			gitg_repository_reload (self);
		break;
		case PROP_SHOW_UNSTAGED:
			self->priv->show_unstaged = g_value_get_boolean (value);
			gitg_repository_reload (self);
		break;
		case PROP_SHOW_STASH:
			self->priv->show_stash = g_value_get_boolean (value);
			gitg_repository_reload (self);
		break;
		case PROP_TOPO_ORDER:
			self->priv->topoorder = g_value_get_boolean (value);

			if (self->priv->selection != NULL)
			{
				build_log_args (self,
					        g_strv_length (self->priv->selection),
					        (gchar const **)self->priv->selection);
			}

			gitg_repository_reload (self);
		break;
		case PROP_INACTIVE_MAX:
			g_object_set_property (G_OBJECT (self->priv->lanes),
			                      "inactive-max",
			                      value);
			prepare_relane (self);
		break;
		case PROP_INACTIVE_COLLAPSE:
			g_object_set_property (G_OBJECT (self->priv->lanes),
			                      "inactive-collapse",
			                      value);
			prepare_relane (self);
		break;
		case PROP_INACTIVE_GAP:
			g_object_set_property (G_OBJECT (self->priv->lanes),
			                      "inactive-gap",
			                      value);
			prepare_relane (self);
		break;
		case PROP_INACTIVE_ENABLED:
			g_object_set_property (G_OBJECT (self->priv->lanes),
			                      "inactive-enabled",
			                      value);
			prepare_relane (self);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_repository_get_property (GObject    *object,
                              guint       prop_id,
                              GValue     *value,
                              GParamSpec *pspec)
{
	GitgRepository *self = GITG_REPOSITORY (object);

	switch (prop_id)
	{
		case PROP_WORK_TREE:
			g_value_set_object (value, self->priv->work_tree);
		break;
		case PROP_GIT_DIR:
			g_value_set_object (value, self->priv->git_dir);
		break;
		case PROP_LOADER:
			g_value_set_object (value, self->priv->loader);
		break;
		case PROP_SHOW_STAGED:
			g_value_set_boolean (value, self->priv->show_staged);
		break;
		case PROP_SHOW_UNSTAGED:
			g_value_set_boolean (value, self->priv->show_unstaged);
		break;
		case PROP_SHOW_STASH:
			g_value_set_boolean (value, self->priv->show_stash);
		break;
		case PROP_TOPO_ORDER:
			g_value_set_boolean (value, self->priv->topoorder);
		break;
		case PROP_INACTIVE_MAX:
			g_object_get_property (G_OBJECT (self->priv->lanes),
			                      "inactive-max",
			                      value);
		break;
		case PROP_INACTIVE_COLLAPSE:
			g_object_get_property (G_OBJECT (self->priv->lanes),
			                      "inactive-collapse",
			                      value);
		break;
		case PROP_INACTIVE_GAP:
			g_object_get_property (G_OBJECT (self->priv->lanes),
			                      "inactive-gap",
			                      value);
		break;
		case PROP_INACTIVE_ENABLED:
			g_object_get_property (G_OBJECT (self->priv->lanes),
			                      "inactive-enabled",
			                      value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static gchar *
parse_ref_intern (GitgRepository *repository,
                  gchar const    *ref,
                  gboolean        symbolic)
{
	gchar **ret = gitg_shell_run_sync_with_output (gitg_command_new (repository,
	                                                                  "rev-parse",
	                                                                  "--verify",
	                                                                  symbolic ? "--symbolic-full-name" : ref,
	                                                                  symbolic ? ref : NULL,
	                                                                  NULL),
	                                               FALSE,
	                                               NULL);

	if (!ret)
	{
		return NULL;
	}

	gchar *r = g_strdup (*ret);
	g_strfreev (ret);

	return r;
}

static GitgRef *
get_current_working_ref (GitgRepository *repository)
{
	GitgRef *ret = NULL;

	gchar *hash = parse_ref_intern (repository, "HEAD", FALSE);
	gchar *name = parse_ref_intern (repository, "HEAD", TRUE);

	if (hash && name)
	{
		ret = gitg_ref_new (hash, name);
		gitg_ref_set_working (ret, TRUE);
	}

	g_free (hash);
	g_free (name);

	return ret;
}

static void
on_head_changed (GFileMonitor      *monitor,
                 GFile             *file,
                 GFile             *otherfile,
                 GFileMonitorEvent  event,
                 GitgRepository    *repository)
{
	switch (event)
	{
		case G_FILE_MONITOR_EVENT_CHANGED:
		case G_FILE_MONITOR_EVENT_CREATED:
		{
			GitgRef *current = get_current_working_ref (repository);

			if (!gitg_ref_equal (current, repository->priv->working_ref))
			{
				gitg_repository_reload (repository);
			}

			gitg_ref_free (current);
		}
		break;
		default:
		break;
	}
}

static void
install_head_monitor (GitgRepository *repository)
{
	GFile *file = g_file_get_child (repository->priv->git_dir, "HEAD");

	repository->priv->monitor = g_file_monitor_file (file,
	                                                 G_FILE_MONITOR_NONE,
	                                                 NULL,
	                                                 NULL);

	g_signal_connect (repository->priv->monitor,
	                  "changed",
	                  G_CALLBACK (on_head_changed),
	                  repository);

	g_object_unref (file);
}

static void
gitg_repository_constructed (GObject *object)
{
	GitgRepository *repository = GITG_REPOSITORY (object);

	if (repository->priv->git_dir == NULL &&
	    repository->priv->work_tree == NULL)
	{
		return;
	}

	if (repository->priv->git_dir == NULL)
	{
		repository->priv->git_dir = g_file_get_child (repository->priv->work_tree,
		                                              ".git");
	}
	else if (repository->priv->work_tree == NULL)
	{
		repository->priv->work_tree = g_file_get_parent (repository->priv->git_dir);
	}

	install_head_monitor (repository);
}

static void
gitg_repository_class_init (GitgRepositoryClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	object_class->finalize = gitg_repository_finalize;

	object_class->set_property = gitg_repository_set_property;
	object_class->get_property = gitg_repository_get_property;

	object_class->constructed = gitg_repository_constructed;

	g_object_class_install_property (object_class,
	                                 PROP_GIT_DIR,
	                                 g_param_spec_object ("git-dir",
	                                                      "GIT_DIR",
	                                                      "The repository .git directory",
	                                                      G_TYPE_FILE,
	                                                      G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_WORK_TREE,
	                                 g_param_spec_object ("work-tree",
	                                                      "WORK_TREE",
	                                                      "The work tree directory",
	                                                      G_TYPE_FILE,
	                                                      G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_LOADER,
	                                 g_param_spec_object ("loader",
	                                                      "LOADER",
	                                                      "The repository loader",
	                                                      GITG_TYPE_SHELL,
	                                                      G_PARAM_READABLE));

	g_object_class_install_property (object_class,
	                                 PROP_SHOW_STAGED,
	                                 g_param_spec_boolean ("show-staged",
	                                                       "Show Staged",
	                                                       "Show staged",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_SHOW_UNSTAGED,
	                                 g_param_spec_boolean ("show-unstaged",
	                                                       "Show Unstaged",
	                                                       "Show unstaged",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_SHOW_STASH,
	                                 g_param_spec_boolean ("show-stash",
	                                                       "Show Stash",
	                                                       "Show stash",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_TOPO_ORDER,
	                                 g_param_spec_boolean ("topo-order",
	                                                       "Topo order",
	                                                       "Show in topological order",
	                                                       FALSE,
	                                                       G_PARAM_READWRITE));

	/* FIXME: gitg-lanes shouldn't be an object? */
	g_object_class_install_property (object_class,
	                                 PROP_INACTIVE_MAX,
	                                 g_param_spec_int ("inactive-max",
	                                                   "INACTIVE_MAX",
	                                                   "Maximum inactivity on a lane before collapsing",
	                                                   1,
	                                                   G_MAXINT,
	                                                   30,
	                                                   G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_INACTIVE_COLLAPSE,
	                                 g_param_spec_int ("inactive-collapse",
	                                                   "INACTIVE_COLLAPSE",
	                                                   "Number of revisions to collapse",
	                                                   1,
	                                                   G_MAXINT,
	                                                   10,
	                                                   G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_INACTIVE_GAP,
	                                 g_param_spec_int ("inactive-gap",
	                                                   "INACTIVE_GAP",
	                                                   "Minimum of revisions to leave between collapse and expand",
	                                                   1,
	                                                   G_MAXINT,
	                                                   10,
	                                                   G_PARAM_READWRITE));

	g_object_class_install_property (object_class,
	                                 PROP_INACTIVE_ENABLED,
	                                 g_param_spec_boolean ("inactive-enabled",
	                                                       "INACTIVE_ENABLED",
	                                                       "Lane collapsing enabled",
	                                                       TRUE,
	                                                       G_PARAM_READWRITE));

	repository_signals[LOAD] =
		g_signal_new ("load",
		              G_OBJECT_CLASS_TYPE (object_class),
		              G_SIGNAL_RUN_LAST,
		              G_STRUCT_OFFSET (GitgRepositoryClass,
		              load),
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__VOID,
		              G_TYPE_NONE,
		              0);

	repository_signals[LOADED] =
		g_signal_new ("loaded",
		              G_OBJECT_CLASS_TYPE (object_class),
		              G_SIGNAL_RUN_LAST,
		              G_STRUCT_OFFSET (GitgRepositoryClass,
		              loaded),
		              NULL,
		              NULL,
		              g_cclosure_marshal_VOID__VOID,
		              G_TYPE_NONE,
		              0);

	g_type_class_add_private (object_class, sizeof (GitgRepositoryPrivate));
}

static void
append_revision (GitgRepository *repository,
                 GitgRevision   *rv)
{
	GSList *lanes;
	gint8 mylane = 0;

	if (repository->priv->size == 0)
	{
		gitg_lanes_reset (repository->priv->lanes);
	}

	lanes = gitg_lanes_next (repository->priv->lanes, rv, &mylane);
	gitg_revision_set_lanes (rv, lanes, mylane);

	gitg_repository_add (repository, rv, NULL);
	gitg_revision_unref (rv);
}

static void
add_dummy_commit (GitgRepository *repository,
                  gboolean        staged)
{
	GitgRevision *revision;
	gchar const *subject;
	struct timeval tv;

	gettimeofday (&tv, NULL);

	if (staged)
	{
		subject = _ ("Staged changes");
	}
	else
	{
		subject = _ ("Unstaged changes");
	}

	revision = gitg_revision_new ("0000000000000000000000000000000000000000",
	                              "",
	                              "",
	                              tv.tv_sec,
	                              "",
	                              "",
	                              -1,
	                              subject,
	                              NULL);
	gitg_revision_set_sign (revision, staged ? 't' : 'u');

	append_revision (repository, revision);
}

static void
on_loader_end_loading (GitgShell      *object,
                       GError         *error,
                       GitgRepository *repository)
{
	if (gitg_io_get_cancelled (GITG_IO (object)))
	{
		g_signal_emit (repository, repository_signals[LOADED], 0);
		return;
	}

	LoadStage current = repository->priv->load_stage++;
	gboolean show_unstaged;
	gboolean show_staged;

	show_unstaged = repository->priv->show_unstaged;
	show_staged = repository->priv->show_staged;

	switch (current)
	{
		case LOAD_STAGE_STASH:
		case LOAD_STAGE_STAGED:
		{
			/* Check if there are staged changes */
			gchar *head = gitg_repository_parse_head (repository);
			const gchar *cached = NULL;

			if (current == LOAD_STAGE_STAGED)
			{
				/* Check if there are unstaged changes */
				if (show_staged && gitg_io_get_exit_status (GITG_IO (object)) != 0)
				{
					add_dummy_commit (repository, TRUE);
				}
			}
			else
			{
				cached = "--cached";
			}

			gitg_shell_run (object,
			                gitg_command_new (repository,
			                                   "diff-index",
			                                   "--no-ext-diff",
			                                   "--quiet",
			                                   head,
			                                   cached,
			                                   NULL),
			                NULL);

			g_free (head);
		}
		break;
		case LOAD_STAGE_UNSTAGED:
			if (show_unstaged && gitg_io_get_exit_status (GITG_IO (object)) != 0)
			{
				add_dummy_commit (repository, FALSE);
			}

			gitg_shell_run (object,
			                gitg_command_newv (repository,
			                                   (gchar const * const *)repository->priv->last_args),
			                NULL);
		break;
		default:
		break;
	}

	if (repository->priv->load_stage == LOAD_STAGE_LAST)
	{
		g_signal_emit (repository, repository_signals[LOADED], 0);
	}
}

static gint
find_ref_custom (GitgRef *first,
                 GitgRef *second)
{
	return gitg_ref_equal (first, second) ? 0 : 1;
}

static GitgRef *
add_ref (GitgRepository *self,
         gchar const    *sha1,
         gchar const    *name)
{
	GitgRef *ref = gitg_ref_new (sha1, name);
	GSList *refs = (GSList *)g_hash_table_lookup (self->priv->refs,
	                                              gitg_ref_get_hash (ref));

	g_hash_table_insert (self->priv->ref_names,
	                     (gpointer)gitg_ref_get_name (ref),
	                     ref);

	if (refs == NULL)
	{
		g_hash_table_insert (self->priv->refs,
		                     (gpointer)gitg_ref_get_hash (ref),
		                     g_slist_append (NULL, ref));
	}
	else
	{
		if (!g_slist_find_custom (refs, ref, (GCompareFunc)find_ref_custom))
		{
			refs = g_slist_append (refs, ref);
		}
		else
		{
			gitg_ref_free (ref);
		}
	}

	return ref;
}

static void
loader_update_stash (GitgRepository  *repository,
                     gchar          **buffer)
{
	gchar *line;
	gboolean show_stash;

	show_stash = repository->priv->show_stash;

	if (!show_stash)
	{
		return;
	}

	while ((line = *buffer++) != NULL)
	{
		gchar **components = g_strsplit (line, "\01", 0);
		guint len = g_strv_length (components);

		if (len < 5)
		{
			g_strfreev (components);
			continue;
		}

		/* components -> [hash, author, author email, author date,
		                  committer, committer email, committer date,
		                  subject, parents, left-right] */
		gint64 author_date = g_ascii_strtoll (components[3], NULL, 0);

		GitgRevision *rv = gitg_revision_new (components[0],
		                                      components[1],
		                                      components[2],
		                                      author_date,
		                                      NULL,
		                                      NULL,
		                                      -1,
		                                      components[4],
		                                      NULL);

		add_ref (repository, components[0], "refs/stash");

		gitg_revision_set_sign (rv, 's');
		append_revision (repository, rv);
		g_strfreev (components);
	}
}

static void
loader_update_commits (GitgRepository  *self,
                       gchar          **buffer)
{
	gchar *line;

	while ( (line = *buffer++) != NULL)
	{
		/* new line is read */
		gchar **components = g_strsplit (line, "\01", 0);
		guint len = g_strv_length (components);

		if (len < 9)
		{
			g_strfreev (components);
			continue;
		}

		/* components -> [hash, author, subject, parents ([1 2 3]), timestamp[, leftright]] */
		gint64 author_date = g_ascii_strtoll (components[3], NULL, 0);
		gint64 committer_date = g_ascii_strtoll (components[6], NULL, 0);

		GitgRevision *rv = gitg_revision_new (components[0],
		                                      components[1],
		                                      components[2],
		                                      author_date,
		                                      components[4],
		                                      components[5],
		                                      committer_date,
		                                      components[7],
		                                      components[8]);

		if (len > 9 && strlen (components[9]) == 1 && strchr ("<>-^", *components[9]) != NULL)
		{
			gitg_revision_set_sign (rv, *components[9]);
		}

		append_revision (self, rv);
		g_strfreev (components);
	}
}

static void
on_loader_update (GitgShell       *object,
                  gchar          **buffer,
                  GitgRepository  *repository)
{
	switch (repository->priv->load_stage)
	{
		case LOAD_STAGE_STASH:
			loader_update_stash (repository, buffer);
		break;
		case LOAD_STAGE_STAGED:
		break;
		case LOAD_STAGE_UNSTAGED:
		break;
		case LOAD_STAGE_COMMITS:
			loader_update_commits (repository, buffer);
		break;
		default:
		break;
	}
}

static void
free_refs (GSList *refs)
{
	g_slist_foreach (refs, (GFunc)gitg_ref_free, NULL);
	g_slist_free (refs);
}

static gboolean
repository_relane (GitgRepository *repository)
{
	repository->priv->idle_relane_id = 0;

	gitg_lanes_reset (repository->priv->lanes);

	guint i;
	GtkTreeIter iter;
	GtkTreePath *path = gtk_tree_path_new_first ();

	for (i = 0; i < repository->priv->size; ++i)
	{
		gint8 mylane;
		GitgRevision *revision = repository->priv->storage[i];

		GSList *lanes = gitg_lanes_next (repository->priv->lanes,
		                                 revision,
		                                 &mylane);
		gitg_revision_set_lanes (revision,
		                         lanes,
		                         mylane);

		fill_iter (repository, i, &iter);
		gtk_tree_model_row_changed (GTK_TREE_MODEL (repository),
		                            path,
		                            &iter);

		gtk_tree_path_next (path);
	}

	gtk_tree_path_free (path);

	return FALSE;
}

static gchar **
copy_strv (gchar const **ptr,
           gint          argc)
{
	GPtrArray *ret = g_ptr_array_new ();
	gint i = 0;

	while (ptr && ( (argc >= 0 && i < argc) || (argc < 0 && ptr[i])))
	{
		g_ptr_array_add (ret, g_strdup (ptr[i]));
		++i;
	}

	g_ptr_array_add (ret, NULL);
	return (gchar **)g_ptr_array_free (ret, FALSE);
}

static gboolean
has_left_right (gchar const **av,
                int           argc)
{
	int i;

	for (i = 0; i < argc; ++i)
	{
		if (strcmp (av[i], "--left-right") == 0)
		{
				return TRUE;
		}
	}

	return FALSE;
}

static void
build_log_args (GitgRepository  *self,
                gint             argc,
                gchar const    **av)
{
	gboolean topoorder;

	topoorder = self->priv->topoorder;

	gchar **argv = g_new0 (gchar *, 6 + topoorder + (argc > 0 ? argc - 1 : 0));

	argv[0] = g_strdup ("log");

	if (has_left_right (av, argc))
	{
		argv[1] = g_strdup ("--pretty=format:%H\x01%an\x01%ae\x01%at\x01%cn\x01%ce\x01%ct\x01%s\x01%P\x01%m");
	}
	else
	{
		argv[1] = g_strdup ("--pretty=format:%H\x01%an\x01%ae\x01%at\x01%cn\x01%ce\x01%ct\x01%s\x01%P");
	}

	argv[2] = g_strdup ("--encoding=UTF-8");
	gint start = 3;

	if (topoorder)
	{
		argv[3] = g_strdup ("--topo-order");
		++start;
	}

	gchar *head = NULL;

	if (argc <= 0)
	{
		head = gitg_repository_parse_ref (self, "HEAD");

		if (head)
		{
			argv[start] = g_strdup ("HEAD");
		}

		g_free (head);
	}
	else
	{
		int i;

		for (i = 0; i < argc; ++i)
		{
			argv[start + i] = g_strdup (av[i]);
		}
	}

	g_strfreev (self->priv->last_args);
	self->priv->last_args = argv;

	gchar **newselection = copy_strv (av, argc);

	g_strfreev (self->priv->selection);
	self->priv->selection = newselection;
}

static void
gitg_repository_init (GitgRepository *object)
{
	object->priv = GITG_REPOSITORY_GET_PRIVATE (object);

	object->priv->hashtable = g_hash_table_new (gitg_hash_hash,
	                                            gitg_hash_hash_equal);

	object->priv->ref_pushes = g_hash_table_new (gitg_hash_hash,
	                                             gitg_hash_hash_equal);

	object->priv->ref_names = g_hash_table_new (g_str_hash, g_str_equal);

	object->priv->column_types[0] = GITG_TYPE_REVISION;
	object->priv->column_types[1] = G_TYPE_STRING;
	object->priv->column_types[2] = G_TYPE_STRING;
	object->priv->column_types[3] = G_TYPE_STRING;

	object->priv->lanes = gitg_lanes_new ();
	object->priv->grow_size = 1000;
	object->priv->stamp = g_random_int ();

	object->priv->refs = g_hash_table_new_full (gitg_hash_hash,
	                                            gitg_hash_hash_equal,
	                                            NULL,
	                                            (GDestroyNotify)free_refs);

	object->priv->loader = gitg_shell_new (10000);

	g_signal_connect (object->priv->loader,
	                  "update",
	                  G_CALLBACK (on_loader_update),
	                  object);

	g_signal_connect (object->priv->loader,
	                  "end",
	                  G_CALLBACK (on_loader_end_loading),
	                  object);
}

static void
grow_storage (GitgRepository *repository,
              gint            size)
{
	if (repository->priv->size + size <= repository->priv->allocated)
	{
		return;
	}

	gulong prevallocated = repository->priv->allocated;
	repository->priv->allocated += repository->priv->grow_size;
	GitgRevision **newstorage = g_slice_alloc (sizeof (GitgRevision *) * repository->priv->allocated);

	gint i;
	for (i = 0; i < repository->priv->size; ++i)
	{
		newstorage[i] = repository->priv->storage[i];
	}

	if (repository->priv->storage)
	{
		g_slice_free1 (sizeof (GitgRevision *) * prevallocated,
		               repository->priv->storage);
	}

	repository->priv->storage = newstorage;
}

GitgRepository *
gitg_repository_new (GFile *git_dir,
                     GFile *work_tree)
{
	return g_object_new (GITG_TYPE_REPOSITORY,
	                     "git-dir", git_dir,
	                     "work-tree", work_tree,
	                     NULL);
}

GFile *
gitg_repository_get_work_tree (GitgRepository *self)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (self), NULL);

	return g_file_dup (self->priv->work_tree);
}

GFile *
gitg_repository_get_git_dir (GitgRepository *self)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (self), NULL);

	return g_file_dup (self->priv->git_dir);
}

GitgShell *
gitg_repository_get_loader (GitgRepository *self)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (self), NULL);
	return GITG_SHELL (g_object_ref (self->priv->loader));
}

static gboolean
reload_revisions (GitgRepository  *repository,
                  GError         **error)
{
	if (repository->priv->working_ref)
	{
		gitg_ref_free (repository->priv->working_ref);
		repository->priv->working_ref = NULL;
	}

	g_signal_emit (repository, repository_signals[LOAD], 0);

	repository->priv->load_stage = LOAD_STAGE_STASH;

	return gitg_shell_run (repository->priv->loader,
	                       gitg_command_new (repository,
	                                          "log",
	                                          "--pretty=format:%H\x01%an\x01%ae\x01%at\x01%s",
	                                          "--encoding=UTF-8",
	                                          "-g",
	                                          "refs/stash",
	                                          NULL),
	                       error);
}

static gchar *
load_current_ref (GitgRepository *self)
{
	gchar **out;
	gchar *ret = NULL;
	gint i;
	gint numargs;

	if (self->priv->last_args == NULL)
	{
		return NULL;
	}

	numargs = g_strv_length (self->priv->last_args);

	gchar const **argv = g_new0 (gchar const *, numargs + 3);

	argv[0] = "rev-parse";
	argv[1] = "--no-flags";
	argv[2] = "--symbolic-full-name";

	for (i = 1; i < numargs; ++i)
	{
		argv[2 + i] = self->priv->last_args[i];
	}

	out = gitg_shell_run_sync_with_output (gitg_command_newv (self, argv),
	                                       FALSE,
	                                       NULL);

	if (!out)
	{
		return NULL;
	}

	if (*out && !*(out + 1))
	{
		ret = g_strdup (*out);
	}

	g_strfreev (out);
	return ret;
}

static void
load_refs (GitgRepository *self)
{
	gchar **refs;

	refs = gitg_shell_run_sync_with_output (gitg_command_new (self,
	                                                           "for-each-ref",
	                                                           "--format=%(refname) %(objectname) %(*objectname)",
	                                                           "refs",
	                                                           NULL),
	                                        FALSE,
	                                        NULL);

	if (!refs)
	{
		return;
	}

	gchar **buffer = refs;
	gchar *buf;
	gchar *current = load_current_ref (self);

	GitgRef *working = gitg_repository_get_current_working_ref (self);

	while (buffer != NULL && (buf = *buffer++) != NULL)
	{
		// each line will look like <name> <hash>
		gchar **components = g_strsplit (buf, " ", 3);
		guint len = g_strv_length (components);

		if (len == 2 || len == 3)
		{
			gchar const *obj = len == 3 && *components[2] ? components[2] : components[1];
			GitgRef *ref = add_ref (self, obj, components[0]);

			if (current != NULL && strcmp (gitg_ref_get_name (ref), current) == 0)
			{
				self->priv->current_ref = gitg_ref_copy (ref);
			}

			if (working != NULL && gitg_ref_equal (working, ref))
			{
				gitg_ref_set_working (ref, TRUE);
			}
		}

		g_strfreev (components);
	}

	g_strfreev (refs);
	g_free (current);
}

void
gitg_repository_reload (GitgRepository *repository)
{
	g_return_if_fail (GITG_IS_REPOSITORY (repository));
	g_return_if_fail (repository->priv->git_dir != NULL);

	gitg_io_cancel (GITG_IO (repository->priv->loader));

	repository->priv->load_stage = LOAD_STAGE_NONE;
	gitg_repository_clear (repository);

	load_refs (repository);
	reload_revisions (repository, NULL);
}

gboolean
gitg_repository_load (GitgRepository  *self,
                      int              argc,
                      gchar const    **av,
                      GError         **error)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (self), FALSE);

	if (self->priv->git_dir == NULL)
	{
		if (error)
		{
			*error = g_error_new_literal (gitg_repository_error_quark (),
			                              GITG_REPOSITORY_ERROR_NOT_FOUND,
			                              _ ("Not a valid git repository"));
		}

		return FALSE;
	}

	gitg_io_cancel (GITG_IO (self->priv->loader));
	gitg_repository_clear (self);

	build_log_args (self, argc, av);

	/* first get the refs */
	load_refs (self);

	/* request log (all the revision) */
	return reload_revisions (self, error);
}

void
gitg_repository_add (GitgRepository *self,
                     GitgRevision   *obj,
                     GtkTreeIter    *iter)
{
	GtkTreeIter iter1;

	/* validate our parameters */
	g_return_if_fail (GITG_IS_REPOSITORY (self));

	grow_storage (self, 1);

	/* put this object in our data storage */
	self->priv->storage[self->priv->size++] = gitg_revision_ref (obj);

	g_hash_table_insert (self->priv->hashtable,
	                     (gpointer)gitg_revision_get_hash (obj),
	                     GUINT_TO_POINTER (self->priv->size - 1));

	iter1.stamp = self->priv->stamp;
	iter1.user_data = GINT_TO_POINTER (self->priv->size - 1);
	iter1.user_data2 = NULL;
	iter1.user_data3 = NULL;

	GtkTreePath *path = gtk_tree_path_new_from_indices (self->priv->size - 1, -1);
	gtk_tree_model_row_inserted (GTK_TREE_MODEL (self), path, &iter1);
	gtk_tree_path_free (path);

	/* return the iter if the user cares */
	if (iter)
	{
		*iter = iter1;
	}
}

void
gitg_repository_clear (GitgRepository *repository)
{
	g_return_if_fail (GITG_IS_REPOSITORY (repository));
	do_clear (repository, TRUE);
}

GitgRevision *
gitg_repository_lookup (GitgRepository *store,
                        gchar const    *hash)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (store), NULL);

	gpointer result = g_hash_table_lookup (store->priv->hashtable, hash);

	if (!result)
	{
		return NULL;
	}

	return store->priv->storage[GPOINTER_TO_UINT (result)];
}

gboolean
gitg_repository_find_by_hash (GitgRepository *store,
                              gchar const    *hash,
                              GtkTreeIter    *iter)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (store), FALSE);

	gpointer result = g_hash_table_lookup (store->priv->hashtable, hash);

	if (!result)
	{
		return FALSE;
	}

	GtkTreePath *path = gtk_tree_path_new_from_indices (GPOINTER_TO_UINT (result),
	                                                    -1);
	gtk_tree_model_get_iter (GTK_TREE_MODEL (store), iter, path);
	gtk_tree_path_free (path);

	return TRUE;
}

gboolean
gitg_repository_find (GitgRepository *store,
                      GitgRevision   *revision,
                      GtkTreeIter    *iter)
{
	return gitg_repository_find_by_hash (store,
	                                     gitg_revision_get_hash (revision),
	                                     iter);
}

static gint
ref_compare (GitgRef *a,
             GitgRef *b)
{
	GitgRefType t1 = gitg_ref_get_ref_type (a);
	GitgRefType t2 = gitg_ref_get_ref_type (b);

	if (t1 != t2)
	{
		return t1 < t2 ? -1 : 1;
	}
	else
	{
		return g_strcmp0 (gitg_ref_get_shortname (a),
		                  gitg_ref_get_shortname (b));
	}
}

GSList *
gitg_repository_get_refs (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	GList *values = g_hash_table_get_values (repository->priv->refs);
	GSList *ret = NULL;
	GList *item;

	for (item = values; item; item = item->next)
	{
		GSList *val;

		for (val = item->data; val; val = val->next)
		{
			ret = g_slist_insert_sorted (ret,
			                             gitg_ref_copy (val->data),
			                             (GCompareFunc)ref_compare);
		}
	}

	g_list_free (values);

	return ret;
}

GSList *
gitg_repository_get_refs_for_hash (GitgRepository *repository,
                                   gchar const    *hash)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);
	return g_slist_copy ( (GSList *)g_hash_table_lookup (repository->priv->refs, hash));
}

GitgRef *
gitg_repository_get_current_ref (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	return repository->priv->current_ref;
}

gchar *
gitg_repository_relative (GitgRepository *repository,
                          GFile          *file)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);
	g_return_val_if_fail (repository->priv->work_tree != NULL, NULL);

	return g_file_get_relative_path (repository->priv->work_tree, file);
}

gchar *
gitg_repository_parse_ref (GitgRepository *repository,
                           gchar const    *ref)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	return parse_ref_intern (repository, ref, FALSE);
}

gchar *
gitg_repository_parse_head (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	gchar *ret = gitg_repository_parse_ref (repository, "HEAD");

	if (!ret)
	{
		ret = g_strdup ("4b825dc642cb6eb9a060e54bf8d69288fbee4904");
	}

	return ret;
}

GitgRef *
gitg_repository_get_current_working_ref (GitgRepository *repository)
{
	if (repository->priv->working_ref)
	{
		return repository->priv->working_ref;
	}

	repository->priv->working_ref = get_current_working_ref (repository);
	return repository->priv->working_ref;
}

gchar **
gitg_repository_get_remotes (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	GitgConfig *config = gitg_config_new (repository);
	gchar *ret = gitg_config_get_value_regex (config, "remote\\..*\\.url", NULL);

	GPtrArray *remotes = g_ptr_array_new ();

	if (!ret)
	{
		g_ptr_array_add (remotes, NULL);
		g_object_unref (config);

		return (gchar **)g_ptr_array_free (remotes, FALSE);
	}

	gchar **lines = g_strsplit (ret, "\n", -1);
	gchar **ptr = lines;

	g_free (ret);

	GRegex *regex = g_regex_new ("remote\\.(.+?)\\.url\\s+(.*)", 0, 0, NULL);

	while (*ptr)
	{
		GMatchInfo *info = NULL;

		if (g_regex_match (regex, *ptr, 0, &info))
		{
			gchar *name = g_match_info_fetch (info, 1);

			g_ptr_array_add (remotes, name);
		}

		g_match_info_free (info);
		++ptr;
	}

	/* NULL terminate */
	g_ptr_array_add (remotes, NULL);
	g_object_unref (config);
	g_strfreev (lines);

	return (gchar **)g_ptr_array_free (remotes, FALSE);
}

GSList const *
gitg_repository_get_ref_pushes (GitgRepository *repository, GitgRef *ref)

{
	gpointer ret;
	GitgRef *my_ref;

	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	my_ref = g_hash_table_lookup (repository->priv->ref_names,
	                              gitg_ref_get_name (ref));

	if (!my_ref)
	{
		return NULL;
	}

	if (g_hash_table_lookup_extended (repository->priv->ref_pushes,
	                                  my_ref,
	                                  NULL,
	                                  &ret))
	{
		return ret;
	}

	GitgConfig *config = gitg_config_new (repository);
	gchar *escaped = g_regex_escape_string (gitg_ref_get_name (my_ref), -1);
	gchar *value_regex = g_strdup_printf ("^%s:", escaped);

	gchar *pushes = gitg_config_get_value_regex (config,
	                                          "remote\\..*\\.push",
	                                          value_regex);

	g_free (escaped);
	g_free (value_regex);

	if (!pushes || !*pushes)
	{
		g_object_unref (config);
		g_free (pushes);

		g_hash_table_insert (repository->priv->ref_pushes,
		                     my_ref,
		                     NULL);

		return NULL;
	}

	gchar **lines = g_strsplit (pushes, "\n", -1);
	gchar **ptr = lines;

	g_free (pushes);

	GRegex *regex = g_regex_new ("remote\\(.+?)\\.push\\s+.*:refs/heads/(.*)", 0, 0, NULL);
	GSList *refs = NULL;

	while (*ptr)
	{
		GMatchInfo *info = NULL;

		if (g_regex_match (regex, *ptr, 0, &info))
		{
			gchar *remote = g_match_info_fetch (info, 1);
			gchar *branch = g_match_info_fetch (info, 2);

			gchar *rr = g_strconcat ("refs/remotes/", remote, "/", branch, NULL);

			GitgRef *remref = g_hash_table_lookup (repository->priv->ref_names,
			                                       rr);

			g_free (rr);
			g_free (remote);
			g_free (branch);

			if (remref)
			{
				refs = g_slist_prepend (refs, remref);
			}
		}

		g_match_info_free (info);
		++ptr;
	}

	g_object_unref (config);
	g_strfreev (lines);

	refs = g_slist_reverse (refs);

	g_hash_table_insert (repository->priv->ref_pushes,
	                     my_ref,
	                     refs);

	return refs;
}

gboolean
gitg_repository_get_loaded (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), FALSE);

	return repository->priv->load_stage == LOAD_STAGE_LAST &&
	       !gitg_io_get_running (GITG_IO (repository->priv->loader));
}

gchar const **
gitg_repository_get_current_selection (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), NULL);

	return (gchar const **)repository->priv->selection;
}

gboolean
gitg_repository_exists (GitgRepository *repository)
{
	g_return_val_if_fail (GITG_IS_REPOSITORY (repository), FALSE);

	if (repository->priv->git_dir == NULL)
	{
		return FALSE;
	}

	return g_file_query_exists (repository->priv->git_dir, NULL) &&
	       g_file_query_exists (repository->priv->work_tree, NULL);
}
