/*
 * gitg-convert.c
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

#include "gitg-convert.h"

#include <string.h>

static void
utf8_validate_fallback (gchar  *text,
                        gssize  size)
{
	gchar const *end;

	while (!g_utf8_validate (text, size, &end))
	{
		*((gchar *)end) = '?';
	}
}

static gchar *
convert_fallback (gchar const *text,
                  gssize       size,
                  gchar const *fallback)
{
	gchar *res;
	gsize read, written;
	GString *str = g_string_new ("");

	while ((res = g_convert(text,
	                        size,
	                        "UTF-8",
	                        "ASCII",
	                        &read,
	                        &written,
	                        NULL)) == NULL)
	{
		res = g_convert (text, read, "UTF-8", "ASCII", NULL, NULL, NULL);
		str = g_string_append (str, res);

		str = g_string_append (str, fallback);
		text = text + read + 1;
		size = size - read;
	}

	str = g_string_append (str, res);
	g_free (res);

	utf8_validate_fallback (str->str, str->len);
	return g_string_free (str, FALSE);
}

gchar *
gitg_convert_utf8 (gchar const *str, gssize size)
{
	static gchar *encodings[] = {
		"ISO-8859-15",
		"ASCII"
	};

	if (str == NULL)
	{
		return NULL;
	}

	if (size == -1)
	{
		size = strlen (str);
	}

	if (g_utf8_validate (str, size, NULL))
	{
		return g_strndup (str, size);
	}

	int i;
	for (i = 0; i < sizeof (encodings) / sizeof (gchar *); ++i)
	{
		gsize read;
		gsize written;

		gchar *ret = g_convert (str,
		                        size,
		                        "UTF-8",
		                        encodings[i],
		                        &read,
		                        &written,
		                        NULL);

		if (ret && read == size)
		{
			utf8_validate_fallback (ret, written);
			return ret;
		}

		g_free (ret);
	}

	return convert_fallback (str, size, "?");
}
