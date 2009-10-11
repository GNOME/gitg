/*
 * gitg-cell-renderer-path.h
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

#ifndef __GITG_CELL_RENDERER_PATH_H__
#define __GITG_CELL_RENDERER_PATH_H__

#include <gtk/gtkcellrenderertext.h>
#include "gitg-ref.h"

G_BEGIN_DECLS

#define GITG_TYPE_CELL_RENDERER_PATH			(gitg_cell_renderer_path_get_type ())
#define GITG_CELL_RENDERER_PATH(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPath))
#define GITG_CELL_RENDERER_PATH_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPath const))
#define GITG_CELL_RENDERER_PATH_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathClass))
#define GITG_IS_CELL_RENDERER_PATH(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_CELL_RENDERER_PATH))
#define GITG_IS_CELL_RENDERER_PATH_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_CELL_RENDERER_PATH))
#define GITG_CELL_RENDERER_PATH_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathClass))

typedef struct _GitgCellRendererPath		GitgCellRendererPath;
typedef struct _GitgCellRendererPathClass	GitgCellRendererPathClass;
typedef struct _GitgCellRendererPathPrivate	GitgCellRendererPathPrivate;

struct _GitgCellRendererPath {
	GtkCellRendererText parent;
	
	GitgCellRendererPathPrivate *priv;
};

struct _GitgCellRendererPathClass {
	GtkCellRendererTextClass parent_class;
};

GType gitg_cell_renderer_path_get_type (void) G_GNUC_CONST;
GtkCellRenderer *gitg_cell_renderer_path_new(void);

GitgRef *gitg_cell_renderer_path_get_ref_at_pos (GtkWidget *widget, GitgCellRendererPath *renderer, gint x, gint *hot_x);
GdkPixbuf *gitg_cell_renderer_path_render_ref (GtkWidget *widget, GitgCellRendererPath *renderer, GitgRef *ref, gint minwidth);

G_END_DECLS

#endif /* __GITG_CELL_RENDERER_PATH_H__ */
