/*
 * gitg-ref.h
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

#ifndef __GITG_REF_H__
#define __GITG_REF_H__

#include <glib-object.h>
#include "gitg-types.h"

G_BEGIN_DECLS

#define GITG_TYPE_REF					(gitg_ref_get_type ())
#define GITG_REF(obj)					((GitgRef *)obj)
#define GITG_REF_CONST(obj)				((GitgRef const *)obj)

typedef enum
{
	GITG_REF_TYPE_NONE = 0,
	GITG_REF_TYPE_BRANCH,
	GITG_REF_TYPE_REMOTE,
	GITG_REF_TYPE_TAG,
	GITG_REF_TYPE_STASH
} GitgRefType;

typedef enum
{
	GITG_REF_STATE_NONE = 0,
	GITG_REF_STATE_SELECTED,
	GITG_REF_STATE_PRELIGHT
} GitgRefState;

typedef struct _GitgRef GitgRef;

GType 			 gitg_ref_get_type 				(void) G_GNUC_CONST;

GitgRef 		*gitg_ref_new					(gchar const  *hash, 
                                                 gchar const  *name);

gchar const 	*gitg_ref_get_hash				(GitgRef      *ref);
GitgRefType 	 gitg_ref_get_ref_type			(GitgRef      *ref);
gchar const 	*gitg_ref_get_name				(GitgRef      *ref);

gchar const 	*gitg_ref_get_shortname			(GitgRef      *ref);
gchar const 	*gitg_ref_get_prefix			(GitgRef      *ref);

gchar           *gitg_ref_get_local_name 		(GitgRef      *ref);

GitgRefState     gitg_ref_get_state             (GitgRef      *ref);
void			 gitg_ref_set_state				(GitgRef      *ref,
                                                 GitgRefState state);

GitgRef			*gitg_ref_copy					(GitgRef      *ref);
void 			 gitg_ref_free					(GitgRef      *ref);

gboolean 		 gitg_ref_equal					(GitgRef      *ref, 
                                                 GitgRef      *other);

gboolean		 gitg_ref_equal_prefix			(GitgRef      *ref,
                                                 GitgRef      *other);

G_END_DECLS

#endif /* __GITG_REF_H__ */

