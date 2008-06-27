#ifndef __GITG_REVISION_VIEW_H__
#define __GITG_REVISION_VIEW_H__

#include <gtk/gtk.h>
#include "gitg-revision.h"
#include "gitg-repository.h"

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_VIEW				(gitg_revision_view_get_type ())
#define GITG_REVISION_VIEW(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_VIEW, GitgRevisionView))
#define GITG_REVISION_VIEW_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_VIEW, GitgRevisionView const))
#define GITG_REVISION_VIEW_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_VIEW, GitgRevisionViewClass))
#define GITG_IS_REVISION_VIEW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_VIEW))
#define GITG_IS_REVISION_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_VIEW))
#define GITG_REVISION_VIEW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_VIEW, GitgRevisionViewClass))

typedef struct _GitgRevisionView		GitgRevisionView;
typedef struct _GitgRevisionViewClass	GitgRevisionViewClass;
typedef struct _GitgRevisionViewPrivate	GitgRevisionViewPrivate;

struct _GitgRevisionView {
	GtkVBox parent;
	
	GitgRevisionViewPrivate *priv;
};

struct _GitgRevisionViewClass {
	GtkVBoxClass parent_class;
	
	void (* parent_activated) (GitgRevisionView *revision_view, gchar *hash);
};

GType gitg_revision_view_get_type (void) G_GNUC_CONST;

void gitg_revision_view_update(GitgRevisionView *revision_view, GitgRepository *repository, GitgRevision *revision);


G_END_DECLS

#endif /* __GITG_REVISION_VIEW_H__ */
