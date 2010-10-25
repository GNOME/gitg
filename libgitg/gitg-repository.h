/*
 * gitg-repository.h
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

#ifndef __GITG_REPOSITORY_H__
#define __GITG_REPOSITORY_H__

#include <gtk/gtk.h>

#include <libgitg/gitg-revision.h>
#include <libgitg/gitg-ref.h>

G_BEGIN_DECLS

#define GITG_TYPE_REPOSITORY			(gitg_repository_get_type ())
#define GITG_REPOSITORY(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY, GitgRepository))
#define GITG_REPOSITORY_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY, GitgRepository const))
#define GITG_REPOSITORY_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REPOSITORY, GitgRepositoryClass))
#define GITG_IS_REPOSITORY(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REPOSITORY))
#define GITG_IS_REPOSITORY_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REPOSITORY))
#define GITG_REPOSITORY_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REPOSITORY, GitgRepositoryClass))

typedef struct _GitgRepository			GitgRepository;
typedef struct _GitgRepositoryClass	GitgRepositoryClass;
typedef struct _GitgRepositoryPrivate	GitgRepositoryPrivate;

struct _GitgShell;

typedef enum
{
	GITG_REPOSITORY_NO_ERROR = 0,
	GITG_REPOSITORY_ERROR_NOT_FOUND
} GitgRepositoryError;

struct _GitgRepository
{
	GObject parent;

	GitgRepositoryPrivate *priv;
};

struct _GitgRepositoryClass
{
	GObjectClass parent_class;

	void (*load) (GitgRepository *repository);
	void (*loaded) (GitgRepository *repository);
};

GType gitg_repository_get_type (void) G_GNUC_CONST;

GitgRepository *gitg_repository_new (GFile *git_dir,
                                     GFile *work_tree);

GFile *gitg_repository_get_work_tree (GitgRepository *repository);
GFile *gitg_repository_get_git_dir (GitgRepository *repository);

gboolean gitg_repository_exists (GitgRepository *repository);

gboolean gitg_repository_load(GitgRepository *repository, int argc, gchar const **argv, GError **error);
gboolean gitg_repository_get_loaded(GitgRepository *repository);

void gitg_repository_add(GitgRepository *repository, GitgRevision *revision, GtkTreeIter *iter);
void gitg_repository_clear(GitgRepository *repository);

gboolean gitg_repository_find_by_hash(GitgRepository *self, gchar const *hash, GtkTreeIter *iter);
gboolean gitg_repository_find(GitgRepository *store, GitgRevision *revision, GtkTreeIter *iter);
GitgRevision *gitg_repository_lookup(GitgRepository *store, gchar const *hash);

GSList *gitg_repository_get_refs(GitgRepository *repository);
GSList *gitg_repository_get_refs_for_hash(GitgRepository *repository, gchar const *hash);
GitgRef *gitg_repository_get_current_ref(GitgRepository *repository);
GitgRef *gitg_repository_get_current_working_ref(GitgRepository *repository);

gchar *gitg_repository_relative(GitgRepository *repository, GFile *file);

gchar *gitg_repository_parse_ref(GitgRepository *repository, gchar const *ref);
gchar *gitg_repository_parse_head(GitgRepository *repository);

void gitg_repository_reload(GitgRepository *repository);

struct _GitgShell *gitg_repository_get_loader (GitgRepository *repository);

gchar **gitg_repository_get_remotes (GitgRepository *repository);
GSList const *gitg_repository_get_ref_pushes (GitgRepository *repository, GitgRef *ref);
gchar const **gitg_repository_get_current_selection (GitgRepository *repository);

G_END_DECLS

#endif /* __GITG_REPOSITORY_H__ */
