/*
 * gitg-debug.c
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

#include "gitg-debug.h"
#include <glib.h>

static guint debug_enabled = GITG_DEBUG_NONE;

#define DEBUG_FROM_ENV(name) 			\
	{									\
		if (g_getenv(#name))			\
			debug_enabled |= name;		\
	}

void
gitg_debug_init (void)
{
	DEBUG_FROM_ENV(GITG_DEBUG_RUNNER);
}

gboolean
gitg_debug_enabled (guint debug)
{
	return debug_enabled & debug;
}
