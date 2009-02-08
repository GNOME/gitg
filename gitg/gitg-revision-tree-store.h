/*
 * gitg-revision-tree-store.h
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

#ifndef __GITG_REVISION_TREE_STORE_H__
#define __GITG_REVISION_TREE_STORE_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_TREE_STORE				(gitg_revision_tree_store_get_type ())
#define GITG_REVISION_TREE_STORE(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStore))
#define GITG_REVISION_TREE_STORE_CONST(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStore const))
#define GITG_REVISION_TREE_STORE_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStoreClass))
#define GITG_IS_REVISION_TREE_STORE(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_TREE_STORE))
#define GITG_IS_REVISION_TREE_STORE_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_TREE_STORE))
#define GITG_REVISION_TREE_STORE_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_TREE_STORE, GitgRevisionTreeStoreClass))

typedef struct _GitgRevisionTreeStore			GitgRevisionTreeStore;
typedef struct _GitgRevisionTreeStoreClass		GitgRevisionTreeStoreClass;
typedef struct _GitgRevisionTreeStorePrivate	GitgRevisionTreeStorePrivate;

enum {
	GITG_REVISION_TREE_STORE_ICON_COLUMN,
	GITG_REVISION_TREE_STORE_NAME_COLUMN,
	GITG_REVISION_TREE_STORE_CONTENT_TYPE_COLUMN,
	GITG_REVISION_TREE_STORE_N_COLUMNS
};

struct _GitgRevisionTreeStore {
	GtkTreeStore parent;
	
	GitgRevisionTreeStorePrivate *priv;
};

struct _GitgRevisionTreeStoreClass {
	GtkTreeStoreClass parent_class;
};

GType gitg_revision_tree_store_get_type (void) G_GNUC_CONST;
GitgRevisionTreeStore *gitg_revision_tree_store_new(void);


G_END_DECLS

#endif /* __GITG_REVISION_TREE_STORE_H__ */
