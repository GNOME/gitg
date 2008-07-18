#ifndef __GITG_LANES_H__
#define __GITG_LANES_H__

#include <glib-object.h>
#include "gitg-revision.h"
#include "gitg-lane.h"

G_BEGIN_DECLS

#define GITG_TYPE_LANES				(gitg_lanes_get_type ())
#define GITG_LANES(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LANES, GitgLanes))
#define GITG_LANES_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LANES, GitgLanes const))
#define GITG_LANES_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_LANES, GitgLanesClass))
#define GITG_IS_LANES(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_LANES))
#define GITG_IS_LANES_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_LANES))
#define GITG_LANES_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_LANES, GitgLanesClass))

typedef struct _GitgLanes			GitgLanes;
typedef struct _GitgLanesClass		GitgLanesClass;
typedef struct _GitgLanesPrivate	GitgLanesPrivate;

struct _GitgLanes {
	GObject parent;
	
	GitgLanesPrivate *priv;
};

struct _GitgLanesClass {
	GObjectClass parent_class;
};

GType gitg_lanes_get_type (void) G_GNUC_CONST;

GitgLanes *gitg_lanes_new(void);
GitgLane **gitg_lanes_reset(GitgLanes *lanes, gchar const *hash);
GitgLane **gitg_lanes_next(GitgLanes *lanes, GitgRevision *previous, GitgRevision *current, gint8 *mylane);

G_END_DECLS


#endif /* __GITG_LANES_H__ */

