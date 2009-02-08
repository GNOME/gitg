/*
 * gitg-lanes.h
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

#ifndef __GITG_LANES_H__
#define __GITG_LANES_H__

#include <glib-object.h>
#include "gitg-revision.h"
#include "gitg-lane.h"

G_BEGIN_DECLS

#define GITG_TYPE_LANES				(gitg_lanes_get_type ())
#define GITG_LANES(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LANES, GitgLanes))
#define GITG_LANES_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LANES, GitgLanes const))
#define GITG_LANES_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_LANES, GitgLanesClass))
#define GITG_IS_LANES(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_LANES))
#define GITG_IS_LANES_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_LANES))
#define GITG_LANES_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_LANES, GitgLanesClass))

typedef struct _GitgLanes			GitgLanes;
typedef struct _GitgLanesClass		GitgLanesClass;
typedef struct _GitgLanesPrivate	GitgLanesPrivate;

struct _GitgLanes {
	GObject parent;
	
	GitgLanesPrivate *priv;
};

struct _GitgLanesClass {
	GObjectClass parent_class;
};

GType gitg_lanes_get_type (void) G_GNUC_CONST;

GitgLanes *gitg_lanes_new(void);
void gitg_lanes_reset(GitgLanes *lanes);
GSList *gitg_lanes_next(GitgLanes *lanes, GitgRevision *next, gint8 *mylane);

G_END_DECLS


#endif /* __GITG_LANES_H__ */

