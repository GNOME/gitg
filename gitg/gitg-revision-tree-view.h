#ifndef __GITG_REVISION_TREE_VIEW_H__
#define __GITG_REVISION_TREE_VIEW_H__

#include <gtk/gtk.h>
#include "gitg-repository.h"
#include "gitg-revision.h"

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_TREE				(gitg_revision_tree_view_get_type ())
#define GITG_REVISION_TREE_VIEW(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE, GitgRevisionTreeView))
#define GITG_REVISION_TREE_VIEW_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE, GitgRevisionTreeView const))
#define GITG_REVISION_TREE_VIEW_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_TREE, GitgRevisionTreeViewClass))
#define GITG_IS_REVISION_TREE_VIEW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_TREE))
#define GITG_IS_REVISION_TREE_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_TREE))
#define GITG_REVISION_TREE_VIEW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_TREE, GitgRevisionTreeViewClass))

typedef struct _GitgRevisionTreeView		GitgRevisionTreeView;
typedef struct _GitgRevisionTreeViewClass	GitgRevisionTreeViewClass;
typedef struct _GitgRevisionTreeViewPrivate	GitgRevisionTreeViewPrivate;

struct _GitgRevisionTreeView {
	GtkHPaned parent;
	
	GitgRevisionTreeViewPrivate *priv;
};

struct _GitgRevisionTreeViewClass {
	GtkHPanedClass parent_class;
};

GType gitg_revision_tree_view_get_type (void) G_GNUC_CONST;
GitgRevisionTreeView *gitg_revision_tree_view_new(void);

void gitg_revision_tree_view_reload(GitgRevisionTreeView *tree);
void gitg_revision_tree_view_update(GitgRevisionTreeView *tree, GitgRepository *repository, GitgRevision *revision);

G_END_DECLS

#endif /* __GITG_REVISION_TREE_VIEW_H__ */
