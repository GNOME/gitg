/*
 * gitg-revision-panel.h
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

#ifndef __GITG_REVISION_PANEL_H__
#define __GITG_REVISION_PANEL_H__

#include <gtk/gtk.h>
#include <libgitg/gitg-repository.h>
#include "gitg-window.h"

G_BEGIN_DECLS

#define GITG_TYPE_REVISION_PANEL		(gitg_revision_panel_get_type ())
#define GITG_REVISION_PANEL(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REVISION_PANEL, GitgRevisionPanel))
#define GITG_IS_REVISION_PANEL(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REVISION_PANEL))
#define GITG_REVISION_PANEL_GET_INTERFACE(obj)	(G_TYPE_INSTANCE_GET_INTERFACE ((obj), GITG_TYPE_REVISION_PANEL, GitgRevisionPanelInterface))

typedef struct _GitgRevisionPanel		GitgRevisionPanel;
typedef struct _GitgRevisionPanelInterface	GitgRevisionPanelInterface;

struct _GitgRevisionPanelInterface
{
	GTypeInterface parent;

	void       (*initialize) (GitgRevisionPanel *panel,
	                          GitgWindow        *window);

	void       (*update)     (GitgRevisionPanel *panel,
	                          GitgRepository    *repository,
	                          GitgRevision      *revision);

	gchar     *(*get_label)  (GitgRevisionPanel *panel);
	gchar     *(*get_id)     (GitgRevisionPanel *panel);
	GtkWidget *(*get_panel)  (GitgRevisionPanel *panel);
};

GType gitg_revision_panel_get_type (void) G_GNUC_CONST;

void       gitg_revision_panel_initialize (GitgRevisionPanel *panel,
                                           GitgWindow        *window);

GtkWidget *gitg_revision_panel_get_panel (GitgRevisionPanel *panel);
gchar     *gitg_revision_panel_get_id    (GitgRevisionPanel *panel);
gchar     *gitg_revision_panel_get_label (GitgRevisionPanel *panel);
void       gitg_revision_panel_update    (GitgRevisionPanel *panel,
                                          GitgRepository    *repository,
                                          GitgRevision      *revision);

G_END_DECLS

#endif /* __GITG_REVISION_PANEL_H__ */
