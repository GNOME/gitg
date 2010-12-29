/*
 * gitg-activatable.c
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

#include "gitg-activatable.h"

G_DEFINE_INTERFACE(GitgActivatable, gitg_activatable, G_TYPE_OBJECT)

/* Default implementation */
static gchar *
gitg_activatable_get_id_default (GitgActivatable *panel)
{
	g_return_val_if_reached (NULL);
}

static gboolean
gitg_activatable_activate_default (GitgActivatable *panel,
                                   gchar const       *cmd)
{
	return FALSE;
}

static void
gitg_activatable_default_init (GitgActivatableInterface *iface)
{
	static gboolean initialized = FALSE;

	iface->get_id = gitg_activatable_get_id_default;
	iface->activate = gitg_activatable_activate_default;

	if (!initialized)
	{
		initialized = TRUE;
	}
}

gchar *
gitg_activatable_get_id (GitgActivatable *panel)
{
	g_return_val_if_fail (GITG_IS_ACTIVATABLE (panel), NULL);

	return GITG_ACTIVATABLE_GET_INTERFACE (panel)->get_id (panel);
}

gboolean
gitg_activatable_activate (GitgActivatable *panel,
                           gchar const     *action)
{
	g_return_val_if_fail (GITG_IS_ACTIVATABLE (panel), FALSE);

	return GITG_ACTIVATABLE_GET_INTERFACE (panel)->activate (panel, action);
}
