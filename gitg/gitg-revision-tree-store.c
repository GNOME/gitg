#include "gitg-revision-tree-store.h"

//#define GITG_REVISION_TREE_STORE_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStorePrivate))

/*struct _GitgRevisionTreeStorePrivate
{
};*/

//static void gitg_revision_tree_store_drag_source_iface_init(GtkTreeDragSourceIface *iface);

G_DEFINE_TYPE(GitgRevisionTreeStore, gitg_revision_tree_store, GTK_TYPE_TREE_STORE);

//static GtkTreeDragSourceIface parent_drag_source_iface = {0,};

/*static gboolean
drag_source_row_draggable(GtkTreeDragSource *drag_source, GtkTreePath *path)
{
	GtkTreeIter iter;
	
	if (!gtk_tree_model_get_iter(GTK_TREE_MODEL(drag_source), &iter, path))
		return FALSE;
	
	// Test for 'empty'
	gchar *content_type;
	gtk_tree_model_get(GTK_TREE_MODEL(drag_source), &iter, GITG_REVISION_TREE_STORE_CONTENT_TYPE_COLUMN, &content_type, -1);
	gboolean ret = content_type != NULL;
	g_free(content_type);

	return ret;
}

static gboolean
drag_source_drag_data_get(GtkTreeDragSource *drag_source, GtkTreePath *path, GtkSelectionData *selection_data)
{
	g_message("Data get");

	if (!gtk_selection_data_targets_include_uri(selection_data))
		return FALSE;
	
	GtkTreeIter iter;
	if (!gtk_tree_model_get_iter(GTK_TREE_MODEL(drag_source), &iter, path))
		return FALSE;
	
	g_message("data get");
	return FALSE;
}

static gboolean
drag_source_drag_data_delete(GtkTreeDragSource *drag_source, GtkTreePath *path)
{
	// Never delete
	return FALSE;
}

static void
gitg_revision_tree_store_drag_source_iface_init(GtkTreeDragSourceIface *iface)
{
	parent_drag_source_iface = *iface;
	
	iface->row_draggable = drag_source_row_draggable;
	iface->drag_data_get = drag_source_drag_data_get;
	iface->drag_data_delete = drag_source_drag_data_delete;
}*/

static void
gitg_revision_tree_store_finalize(GObject *object)
{
	//GitgRevisionTreeStore *self = GITG_REVISION_TREE_STORE(object);
	
	G_OBJECT_CLASS(gitg_revision_tree_store_parent_class)->finalize(object);
}

static void
gitg_revision_tree_store_class_init(GitgRevisionTreeStoreClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_revision_tree_store_finalize;
	
	//g_type_class_add_private(object_class, sizeof(GitgRevisionTreeStorePrivate));
}

static void
gitg_revision_tree_store_init(GitgRevisionTreeStore *self)
{
	//self->priv = GITG_REVISION_TREE_STORE_GET_PRIVATE(self);

	GType column_types[] = {
		GDK_TYPE_PIXBUF,
		G_TYPE_STRING,
		G_TYPE_STRING
	};
	
	gtk_tree_store_set_column_types(GTK_TREE_STORE(self), GITG_REVISION_TREE_STORE_N_COLUMNS, column_types);
}

GitgRevisionTreeStore *
gitg_revision_tree_store_new()
{
	return GITG_REVISION_TREE_STORE(g_object_new(GITG_TYPE_REVISION_TREE_STORE, NULL));
}
