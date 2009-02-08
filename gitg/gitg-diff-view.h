/*
 * gitg-diff-view.h
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

#ifndef __GITG_DIFF_VIEW_H__
#define __GITG_DIFF_VIEW_H__

#include <gtksourceview/gtksourceview.h>

G_BEGIN_DECLS

#define GITG_TYPE_DIFF_VIEW				(gitg_diff_view_get_type ())
#define GITG_DIFF_VIEW(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_DIFF_VIEW, GitgDiffView))
#define GITG_DIFF_VIEW_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_DIFF_VIEW, GitgDiffView const))
#define GITG_DIFF_VIEW_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_DIFF_VIEW, GitgDiffViewClass))
#define GITG_IS_DIFF_VIEW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_DIFF_VIEW))
#define GITG_IS_DIFF_VIEW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_DIFF_VIEW))
#define GITG_DIFF_VIEW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_DIFF_VIEW, GitgDiffViewClass))

typedef struct _GitgDiffView		GitgDiffView;
typedef struct _GitgDiffViewClass	GitgDiffViewClass;
typedef struct _GitgDiffViewPrivate	GitgDiffViewPrivate;

struct _GitgDiffView
{
	GtkSourceView parent;
	
	GitgDiffViewPrivate *priv;
};

struct _GitgDiffViewClass
{
	GtkSourceViewClass parent_class;
};

GType gitg_diff_view_get_type(void) G_GNUC_CONST;
GitgDiffView *gitg_diff_view_new(void);
void gitg_diff_view_remove_hunk(GitgDiffView *view, GtkTextIter *iter);

G_END_DECLS

#endif /* __GITG_DIFF_VIEW_H__ */
