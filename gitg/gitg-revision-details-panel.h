/*
 * gitg-revision-details-panel.h
 * This file is part of gitg - git repository details_paneler
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

#ifndef __GITG_REVISION_DETAILS_PANEL_H__
#define __GITG_REVISION_DETAILS_PANEL_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_DETAILS_PANEL			(gitg_revision_details_panel_get_type ())
#define GITG_REVISION_DETAILS_PANEL(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsPanel))
#define GITG_REVISION_DETAILS_PANEL_CONST(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsPanel const))
#define GITG_REVISION_DETAILS_PANEL_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsPanelClass))
#define GITG_IS_REVISION_DETAILS_PANEL(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_DETAILS_PANEL))
#define GITG_IS_REVISION_DETAILS_PANEL_CLASS(klass)		(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REVISION_DETAILS_PANEL))
#define GITG_REVISION_DETAILS_PANEL_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REVISION_DETAILS_PANEL, GitgRevisionDetailsClass))

typedef struct _GitgRevisionDetailsPanel		GitgRevisionDetailsPanel;
typedef struct _GitgRevisionDetailsPanelClass		GitgRevisionDetailsPanelClass;
typedef struct _GitgRevisionDetailsPanelPrivate		GitgRevisionDetailsPanelPrivate;

struct _GitgRevisionDetailsPanel
{
	GObject parent;

	GitgRevisionDetailsPanelPrivate *priv;
};

struct _GitgRevisionDetailsPanelClass
{
	GObjectClass parent_class;
};

GType gitg_revision_details_panel_get_type (void) G_GNUC_CONST;

G_END_DECLS

#endif /* __GITG_REVISION_DETAILS_PANEL_H__ */
