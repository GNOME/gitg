/*
 * gitg-blame-renderer.h
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2011 - Ignacio Casal Quinteiro
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

#ifndef __GITG_BLAME_RENDERER_H__
#define __GITG_BLAME_RENDERER_H__

#include <gtksourceview/gtksourceview.h>

G_BEGIN_DECLS

#define GITG_TYPE_BLAME_RENDERER		(gitg_blame_renderer_get_type ())
#define GITG_BLAME_RENDERER(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_BLAME_RENDERER, GitgBlameRenderer))
#define GITG_BLAME_RENDERER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_BLAME_RENDERER, GitgBlameRenderer const))
#define GITG_BLAME_RENDERER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_BLAME_RENDERER, GitgBlameRendererClass))
#define GITG_IS_BLAME_RENDERER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_BLAME_RENDERER))
#define GITG_IS_BLAME_RENDERER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_BLAME_RENDERER))
#define GITG_BLAME_RENDERER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_BLAME_RENDERER, GitgBlameRendererClass))

typedef struct _GitgBlameRenderer		GitgBlameRenderer;
typedef struct _GitgBlameRendererClass		GitgBlameRendererClass;
typedef struct _GitgBlameRendererPrivate	GitgBlameRendererPrivate;

struct _GitgBlameRenderer {
	GtkSourceGutterRenderer parent;
	
	GitgBlameRendererPrivate *priv;
};

struct _GitgBlameRendererClass {
	GtkSourceGutterRendererClass parent_class;
};

GType                    gitg_blame_renderer_get_type                (void) G_GNUC_CONST;

GitgBlameRenderer       *gitg_blame_renderer_new                     (void);

void                     gitg_blame_renderer_set_max_line_count      (GitgBlameRenderer *renderer,
                                                                      gint               max_line_count);

G_END_DECLS

#endif /* __GITG_BLAME_RENDERER_H__ */
