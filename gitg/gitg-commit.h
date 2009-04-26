/*
 * gitg-commit.h
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

#ifndef __GITG_COMMIT_H__
#define __GITG_COMMIT_H__

#include <glib-object.h>
#include "gitg-repository.h"
#include "gitg-changed-file.h"

G_BEGIN_DECLS

#define GITG_TYPE_COMMIT			(gitg_commit_get_type ())
#define GITG_COMMIT(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMIT, GitgCommit))
#define GITG_COMMIT_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_COMMIT, GitgCommit const))
#define GITG_COMMIT_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_COMMIT, GitgCommitClass))
#define GITG_IS_COMMIT(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_COMMIT))
#define GITG_IS_COMMIT_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_COMMIT))
#define GITG_COMMIT_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_COMMIT, GitgCommitClass))

#define GITG_COMMIT_ERROR			(gitg_commit_error_quark())

typedef struct _GitgCommit			GitgCommit;
typedef struct _GitgCommitClass		GitgCommitClass;
typedef struct _GitgCommitPrivate	GitgCommitPrivate;

typedef enum
{
	GITG_COMMIT_ERROR_NONE = 0,
	GITG_COMMIT_ERROR_SIGNOFF
} GitgCommitError;

struct _GitgCommit {
	GObject parent;
  
	GitgCommitPrivate *priv;
};

struct _GitgCommitClass {
	GObjectClass parent_class;
	
	void (*inserted) (GitgCommit *commit, GitgChangedFile *file);
	void (*removed) (GitgCommit *commit, GitgChangedFile *file);
};

GQuark gitg_commit_error_quark(void);

GType gitg_commit_get_type(void) G_GNUC_CONST;
GitgCommit *gitg_commit_new(GitgRepository *repository);

void gitg_commit_refresh(GitgCommit *commit);
gboolean gitg_commit_stage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error);
gboolean gitg_commit_unstage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error);

gboolean gitg_commit_has_changes(GitgCommit *commit);
gboolean gitg_commit_commit(GitgCommit *commit, gchar const *comment, gboolean signoff, GError **error);

gboolean gitg_commit_revert(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error);
gboolean gitg_commit_add_ignore(GitgCommit *commit, GitgChangedFile *file, GError **error);

GitgChangedFile *gitg_commit_find_changed_file(GitgCommit *commit, GFile *file);

G_END_DECLS

#endif /* __GITG_COMMIT_H__ */
