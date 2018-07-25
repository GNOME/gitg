/*
 * gitg-revision.h
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

#ifndef __GITG_REVISION_H__
#define __GITG_REVISION_H__

#include <glib-object.h>
#include <libgitg/gitg-lane.h>

G_BEGIN_DECLS

#define GITG_TYPE_REVISION       (gitg_revision_get_type ())
#define GITG_REVISION(obj)       ((GitgRevision *)obj)
#define GITG_REVISION_CONST(obj) ((GitgRevision const *)obj)

typedef struct _GitgRevision		GitgRevision;

GType gitg_revision_get_type (void) G_GNUC_CONST;

GitgRevision *gitg_revision_new (gchar const *hash,
                                 gchar const *author,
                                 gchar const *author_email,
                                 gint64       author_date,
                                 gchar const *committer,
                                 gchar const *committer_email,
                                 gint64       committer_date,
                                 gchar const *subject,
                                 gchar const *parents);

gchar const *gitg_revision_get_author (GitgRevision *revision);
gchar const *gitg_revision_get_author_email (GitgRevision *revision);
gint64 gitg_revision_get_author_date (GitgRevision *revision);

gchar const *gitg_revision_get_committer (GitgRevision *revision);
gchar const *gitg_revision_get_committer_email (GitgRevision *revision);
gint64 gitg_revision_get_committer_date (GitgRevision *revision);

gchar const *gitg_revision_get_subject (GitgRevision *revision);

gchar const *gitg_revision_get_hash (GitgRevision *revision);
GitgHash *gitg_revision_get_parents_hash (GitgRevision *revision, guint *num_parents);

gchar *gitg_revision_get_sha1 (GitgRevision *revision);
gchar **gitg_revision_get_parents (GitgRevision *revision);

GSList *gitg_revision_get_lanes (GitgRevision *revision);
GitgLane *gitg_revision_get_lane (GitgRevision *revision);
void gitg_revision_set_lanes (GitgRevision *revision, GSList *lanes, gint8 mylane);

GSList *gitg_revision_remove_lane (GitgRevision *revision, GitgLane *lane);
GSList *gitg_revision_insert_lane (GitgRevision *revision, GitgLane *lane, gint index);

gint8 gitg_revision_get_mylane (GitgRevision *revision);
void gitg_revision_set_mylane (GitgRevision *revision, gint8 mylane);

void gitg_revision_set_sign(GitgRevision *revision, char sign);
char gitg_revision_get_sign(GitgRevision *revision);

GitgRevision *gitg_revision_ref (GitgRevision *revision);
void gitg_revision_unref (GitgRevision *revision);

gchar *gitg_revision_get_format_patch_name (GitgRevision *revision);

gchar *gitg_revision_get_author_date_for_display (GitgRevision *revision);
gchar *gitg_revision_get_committer_date_for_display (GitgRevision *revision);

G_END_DECLS

#endif /* __GITG_REVISION_H__ */
