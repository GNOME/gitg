/*
 * gitg-hash.c
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

#include <string.h>
#include <glib.h>
#include <stdlib.h>
#include <math.h>

#include "gitg-hash.h"

inline static guint8
atoh (gchar c)
{
	if (c >= 'a')
	{
		return c - 'a' + 10;
	}

	if (c >= 'A')
	{
		return c - 'A' + 10;
	}

	return c - '0';
}

void
gitg_hash_partial_sha1_to_hash (gchar const *sha,
                                gint         length,
                                gchar       *hash)
{
	if (length % 2 == 1)
	{
		--length;
	}

	int i;

	for (i = 0; i < length / 2; ++i)
	{
		gchar h = atoh (*(sha++)) << 4;
		hash[i] = h | atoh (*(sha++));
	}
}

void
gitg_hash_sha1_to_hash (gchar const *sha,
                        gchar       *hash)
{
	gitg_hash_partial_sha1_to_hash (sha, GITG_HASH_SHA_SIZE, hash);
}

void
gitg_hash_hash_to_sha1 (gchar const *hash,
                        gchar       *sha)
{
	char const *repr = "0123456789abcdef";
	int i;
	int pos = 0;

	for (i = 0; i < GITG_HASH_BINARY_SIZE; ++i)
	{
		sha[pos++] = repr[(hash[i] >> 4) & 0x0f];
		sha[pos++] = repr[(hash[i] & 0x0f)];
	}
}

gchar *
gitg_hash_hash_to_sha1_new (gchar const *hash)
{
	gchar *ret = g_new (gchar, GITG_HASH_SHA_SIZE + 1);
	gitg_hash_hash_to_sha1 (hash, ret);

	ret[GITG_HASH_SHA_SIZE] = '\0';
	return ret;
}

gchar *
gitg_hash_partial_sha1_to_hash_new (gchar const *sha,
                                    gint         length,
                                    gint        *retlen)
{
	if (length == -1)
	{
		length = strlen (sha);
	}

	if (length % 2 != 0)
	{
		--length;
	}

	*retlen = length / 2;
	gchar *ret = g_new (gchar, *retlen);

	gitg_hash_partial_sha1_to_hash (sha, length, ret);

	return ret;
}

gchar *
gitg_hash_sha1_to_hash_new (gchar const *sha1)
{
	gchar *ret = g_new (gchar, GITG_HASH_BINARY_SIZE);
	gitg_hash_sha1_to_hash (sha1, ret);

	return ret;
}

guint
gitg_hash_hash (gconstpointer v)
{
	/* 31 bit hash function, copied from g_str_hash */
	const signed char *p = v;
	guint32 h = *p;
	int i;

	for (i = 1; i < GITG_HASH_BINARY_SIZE; ++i)
		h = (h << 5) - h + p[i];

	return h;
}

gboolean
gitg_hash_hash_equal (gconstpointer a, gconstpointer b)
{
	return memcmp (a, b, GITG_HASH_BINARY_SIZE) == 0;
}
