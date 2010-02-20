/*
 * Copyright (C) 1997, 1998, 1999, 2000 Free Software Foundation
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include <string.h>

#include "gitg-i18n.h"

/**
 * _gitg_gettext:
 * @msgid: The string to be translated
 *
 * Returns the translated string from the libgitg translations.
 * This is an internal function and should only be used by
 * the internals of libgitg
 *
 * Returns: the transation of @msgid to the current locale
 */
const gchar *
_gitg_gettext (const gchar *msgid)
{
	static gboolean initialized = FALSE;

	if (G_UNLIKELY (!initialized))
	{
		bindtextdomain (GETTEXT_PACKAGE, GITG_LOCALEDIR);
		bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");

		initialized = TRUE;
	}

	return g_dgettext (GETTEXT_PACKAGE, msgid);
}
