#ifndef __GITG_REVISION_TREE_STORE_H__
#define __GITG_REVISION_TREE_STORE_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_TREE_STORE				(gitg_revision_tree_store_get_type ())
#define GITG_REVISION_TREE_STORE(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStore))
#define GITG_REVISION_TREE_STORE_CONST(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStore const))
#define GITG_REVISION_TREE_STORE_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStoreClass))
#define GITG_IS_REVISION_TREE_STORE(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_TREE_STORE))
#define GITG_IS_REVISION_TREE_STORE_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_TREE_STORE))
#define GITG_REVISION_TREE_STORE_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStoreClass))

typedef struct _GitgRevisionTreeStore			GitgRevisionTreeStore;
typedef struct _GitgRevisionTreeStoreClass		GitgRevisionTreeStoreClass;
typedef struct _GitgRevisionTreeStorePrivate	GitgRevisionTreeStorePrivate;

enum {
	GITG_REVISION_TREE_STORE_ICON_COLUMN,
	GITG_REVISION_TREE_STORE_NAME_COLUMN,
	GITG_REVISION_TREE_STORE_CONTENT_TYPE_COLUMN,
	GITG_REVISION_TREE_STORE_N_COLUMNS
};

struct _GitgRevisionTreeStore {
	GtkTreeStore parent;
	
	GitgRevisionTreeStorePrivate *priv;
};

struct _GitgRevisionTreeStoreClass {
	GtkTreeStoreClass parent_class;
};

GType gitg_revision_tree_store_get_type (void) G_GNUC_CONST;
GitgRevisionTreeStore *gitg_revision_tree_store_new(void);


G_END_DECLS

#endif /* __GITG_REVISION_TREE_STORE_H__ */
