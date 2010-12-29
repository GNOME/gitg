/*
 * gitg-revision-panel.c
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

#include "gitg-revision-panel.h"

G_DEFINE_INTERFACE(GitgRevisionPanel, gitg_revision_panel, G_TYPE_OBJECT)

/* Default implementation */
static void
gitg_revision_panel_initialize_default (GitgRevisionPanel *panel,
                                        GitgWindow        *window)
{
	/* No default implementation */
}

static gchar *
gitg_revision_panel_get_id_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static gchar *
gitg_revision_panel_get_label_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static GtkWidget *
gitg_revision_panel_get_panel_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static void
gitg_revision_panel_update_default (GitgRevisionPanel *panel,
                                    GitgRepository    *repository,
                                    GitgRevision      *revision)
{
	/* No default implementation */
}

static void
gitg_revision_panel_default_init (GitgRevisionPanelInterface *iface)
{
	static gboolean initialized = FALSE;

	iface->initialize = gitg_revision_panel_initialize_default;
	iface->get_id = gitg_revision_panel_get_id_default;
	iface->get_label = gitg_revision_panel_get_label_default;
	iface->get_panel = gitg_revision_panel_get_panel_default;
	iface->update = gitg_revision_panel_update_default;

	if (!initialized)
	{
		initialized = TRUE;
	}
}

gchar *
gitg_revision_panel_get_id (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_id (panel);
}

gchar *
gitg_revision_panel_get_label (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_label (panel);
}

GtkWidget *
gitg_revision_panel_get_panel (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_panel (panel);
}

void
gitg_revision_panel_update (GitgRevisionPanel *panel,
                            GitgRepository    *repository,
                            GitgRevision      *revision)
{
	g_return_if_fail (GITG_IS_REVISION_PANEL (panel));

	GITG_REVISION_PANEL_GET_INTERFACE (panel)->update (panel,
	                                                  repository,
	                                                  revision);
}

void
gitg_revision_panel_initialize (GitgRevisionPanel *panel,
                                GitgWindow        *window)
{
	g_return_if_fail (GITG_IS_REVISION_PANEL (panel));
	g_return_if_fail (GITG_IS_WINDOW (window));

	GITG_REVISION_PANEL_GET_INTERFACE (panel)->initialize (panel,
	                                                       window);
}

