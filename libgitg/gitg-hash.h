/*
 * gitg-hash.h
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

#ifndef __GITG_HASH_H__
#define __GITG_HASH_H__

#include <glib.h>

void gitg_hash_sha1_to_hash(gchar const *sha, gchar *hash);
void gitg_hash_hash_to_sha1(gchar const *hash, gchar *sha);

void gitg_hash_partial_sha1_to_hash (gchar const *sha, gint length, gchar *hash);

gchar *gitg_hash_sha1_to_hash_new(gchar const *sha);
gchar *gitg_hash_hash_to_sha1_new(gchar const *hash);

gchar *gitg_hash_partial_sha1_to_hash_new (gchar const *sha, gint length, gint *retlen);

guint gitg_hash_hash(gconstpointer v);
gboolean gitg_hash_hash_equal(gconstpointer a, gconstpointer b);

#endif /* __GITG_HASH_H__ */
