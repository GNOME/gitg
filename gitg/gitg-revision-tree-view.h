/*
 * gitg-revision-tree-view.h
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

#ifndef __GITG_REVISION_TREE_VIEW_H__
#define __GITG_REVISION_TREE_VIEW_H__

#include <gtk/gtk.h>
#include <libgitg/gitg-repository.h>
#include <libgitg/gitg-revision.h>

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
