#ifndef __GITG_REVISION_H__
#define __GITG_REVISION_H__

#include <glib-object.h>
#include "gitg-lane.h"

G_BEGIN_DECLS

#define GITG_TYPE_REVISION				(gitg_revision_get_type ())
#define GITG_REVISION(obj)				((GitgRevision *)obj)
#define GITG_REVISION_CONST(obj)		((GitgRevision const *)obj)

#include "gitg-types.h"

typedef struct _GitgRevision		GitgRevision;

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

GitgRevision *gitg_revision_ref(GitgRevision *revision);
void gitg_revision_unref(GitgRevision *revision);

G_END_DECLS

#endif /* __GITG_REVISION_H__ */
