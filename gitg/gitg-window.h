/*
 * gitg-window.h
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

#ifndef __GITG_WINDOW_H__
#define __GITG_WINDOW_H__

#include <gtk/gtk.h>
#include "gitg-repository.h"

G_BEGIN_DECLS

#define GITG_TYPE_WINDOW			(gitg_window_get_type ())
#define GITG_WINDOW(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_WINDOW, GitgWindow))
#define GITG_WINDOW_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_WINDOW, GitgWindow const))
#define GITG_WINDOW_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_WINDOW, GitgWindowClass))
#define GITG_IS_WINDOW(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_WINDOW))
#define GITG_IS_WINDOW_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_WINDOW))
#define GITG_WINDOW_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_WINDOW, GitgWindowClass))

typedef struct _GitgWindow		GitgWindow;
typedef struct _GitgWindowClass		GitgWindowClass;
typedef struct _GitgWindowPrivate	GitgWindowPrivate;

struct _GitgWindow {
	GtkWindow parent;
	
	GitgWindowPrivate *priv;
};

struct _GitgWindowClass {
	GtkWindowClass parent_class;
};

GType gitg_window_get_type (void) G_GNUC_CONST;

void gitg_window_load_repository(GitgWindow *window, gchar const *path, gint argc, gchar const **argv);
void gitg_window_show_commit(GitgWindow *window);
GitgRepository *gitg_window_get_repository(GitgWindow *window);

G_END_DECLS

#endif /* __GITG_WINDOW_H__ */
