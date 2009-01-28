#ifndef __GITG_COMMIT_VIEW_H__
#define __GITG_COMMIT_VIEW_H__

#include <gtk/gtk.h>
#include "gitg-repository.h"

G_BEGIN_DECLS

#define GITG_TYPE_COMMIT_VIEW				(gitg_commit_view_get_type ())
#define GITG_COMMIT_VIEW(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMIT_VIEW, GitgCommitView))
#define GITG_COMMIT_VIEW_CONST(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMIT_VIEW, GitgCommitView const))
#define GITG_COMMIT_VIEW_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_COMMIT_VIEW, GitgCommitViewClass))
#define GITG_IS_COMMIT_VIEW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_COMMIT_VIEW))
#define GITG_IS_COMMIT_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_COMMIT_VIEW))
#define GITG_COMMIT_VIEW_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_COMMIT_VIEW, GitgCommitViewClass))

typedef struct _GitgCommitView			GitgCommitView;
typedef struct _GitgCommitViewClass		GitgCommitViewClass;
typedef struct _GitgCommitViewPrivate	GitgCommitViewPrivate;

struct _GitgCommitView {
	GtkHPaned parent;
	
	GitgCommitViewPrivate *priv;
};

struct _GitgCommitViewClass {
	GtkHPanedClass parent_class;
};

GType gitg_commit_view_get_type (void) G_GNUC_CONST;
void gitg_commit_view_set_repository(GitgCommitView *view, GitgRepository *repository);

G_END_DECLS

#endif /* __GITG_COMMIT_VIEW_H__ */
