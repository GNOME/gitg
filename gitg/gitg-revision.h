#ifndef __GITG_REVISION_H__
#define __GITG_REVISION_H__

#include <glib-object.h>
#include "gitg-lane.h"

G_BEGIN_DECLS

#define GITG_TYPE_REVISION				(gitg_revision_get_type ())
#define GITG_REVISION(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION, GitgRevision))
#define GITG_REVISION_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION, GitgRevision const))
#define GITG_REVISION_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION, GitgRevisionClass))
#define GITG_IS_REVISION(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION))
#define GITG_IS_REVISION_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION))
#define GITG_REVISION_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION, GitgRevisionClass))

typedef gchar Hash[20];

typedef struct _GitgRevision		GitgRevision;
typedef struct _GitgRevisionClass	GitgRevisionClass;
typedef struct _GitgRevisionPrivate	GitgRevisionPrivate;

struct _GitgRevision {
	GObject parent;
	
	GitgRevisionPrivate *priv;
};

struct _GitgRevisionClass {
	GObjectClass parent_class;
};

GType gitg_revision_get_type (void) G_GNUC_CONST;

GitgRevision *gitg_revision_new(gchar const *hash, 
	gchar const *author, gchar const *subject, gchar const *parents, gint64 timestamp);

inline gchar const *gitg_revision_get_author(GitgRevision *revision);
inline gchar const *gitg_revision_get_subject(GitgRevision *revision);
inline guint64 gitg_revision_get_timestamp(GitgRevision *revision);
inline gchar const *gitg_revision_get_hash(GitgRevision *revision);
inline Hash *gitg_revision_get_parents_hash(GitgRevision *revision, guint *num_parents);

gchar *gitg_revision_get_sha1(GitgRevision *revision);
gchar **gitg_revision_get_parents(GitgRevision *revision);

GSList *gitg_revision_get_lanes(GitgRevision *revision);
void gitg_revision_set_lanes(GitgRevision *revision, GSList *lanes);

gint8 gitg_revision_get_mylane(GitgRevision *revision);
void gitg_revision_set_mylane(GitgRevision *revision, gint8 mylane);

G_END_DECLS

#endif /* __GITG_REVISION_H__ */
