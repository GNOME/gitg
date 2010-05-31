#ifndef __GITG_REVISION_CHANGES_PANEL_H__
#define __GITG_REVISION_CHANGES_PANEL_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_CHANGES_PANEL		(gitg_revision_changes_panel_get_type ())
#define GITG_REVISION_CHANGES_PANEL(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_CHANGES_PANEL, GitgRevisionChangesPanel))
#define GITG_REVISION_CHANGES_PANEL_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_CHANGES_PANEL, GitgRevisionChangesPanel const))
#define GITG_REVISION_CHANGES_PANEL_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_CHANGES_PANEL, GitgRevisionChangesPanelClass))
#define GITG_IS_REVISION_CHANGES_PANEL(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_CHANGES_PANEL))
#define GITG_IS_REVISION_CHANGES_PANEL_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_CHANGES_PANEL))
#define GITG_REVISION_CHANGES_PANEL_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_CHANGES_PANEL, GitgRevisionChangesPanelClass))

typedef struct _GitgRevisionChangesPanel	GitgRevisionChangesPanel;
typedef struct _GitgRevisionChangesPanelClass	GitgRevisionChangesPanelClass;
typedef struct _GitgRevisionChangesPanelPrivate	GitgRevisionChangesPanelPrivate;

struct _GitgRevisionChangesPanel {
	GObject parent;

	GitgRevisionChangesPanelPrivate *priv;
};

struct _GitgRevisionChangesPanelClass {
	GObjectClass parent_class;
};

GType gitg_revision_changes_panel_get_type (void) G_GNUC_CONST;

G_END_DECLS

#endif /* __GITG_REVISION_CHANGES_PANEL_H__ */
