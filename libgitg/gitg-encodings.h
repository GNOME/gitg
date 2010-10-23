/*
 * Copied from gedit-encodings.h
 *
 *
 * gedit-encodings.h
 * This file is part of gedit
 *
 * Copyright (C) 2002-2005 Paolo Maggi
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

/*
 * Modified by the gedit Team, 2002-2005. See the AUTHORS file for a
 * list of people on the gedit Team.
 * See the ChangeLog files for a list of changes.
 *
 * $Id$
 */

#ifndef __GITG_ENCODINGS_H__
#define __GITG_ENCODINGS_H__

#include <glib.h>
#include <glib-object.h>

G_BEGIN_DECLS

typedef struct _GitgEncoding GitgEncoding;

#define GITG_TYPE_ENCODING     (gitg_encoding_get_type ())

GType              	 gitg_encoding_get_type	 (void) G_GNUC_CONST;

const GitgEncoding	*gitg_encoding_get_from_charset (const gchar         *charset);
const GitgEncoding	*gitg_encoding_get_from_index	 (gint                 index);

gchar 			*gitg_encoding_to_string	 (const GitgEncoding *enc);

const gchar		*gitg_encoding_get_name	 (const GitgEncoding *enc);
const gchar		*gitg_encoding_get_charset	 (const GitgEncoding *enc);

const GitgEncoding 	*gitg_encoding_get_utf8	 (void);
const GitgEncoding 	*gitg_encoding_get_current	 (void);

GSList                  *gitg_encoding_get_candidates (void);

/* These should not be used, they are just to make python bindings happy */
GitgEncoding		*gitg_encoding_copy		 (const GitgEncoding *enc);
void               	 gitg_encoding_free		 (GitgEncoding       *enc);

GSList			*_gitg_encoding_strv_to_list    (const gchar * const *enc_str);
gchar		       **_gitg_encoding_list_to_strv	 (const GSList        *enc);

G_END_DECLS

#endif  /* __GITG_ENCODINGS_H__ */

/* ex:ts=8:noet: */
