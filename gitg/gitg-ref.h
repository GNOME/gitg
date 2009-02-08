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

#include "gitg-types.h"

typedef enum
{
	GITG_REF_TYPE_NONE = 0,
	GITG_REF_TYPE_BRANCH,
	GITG_REF_TYPE_REMOTE,
	GITG_REF_TYPE_TAG
} GitgRefType;

typedef struct
{
	Hash hash;
	GitgRefType type;
	gchar *name;
	gchar *shortname;
} GitgRef;

GitgRef *gitg_ref_new(gchar const *hash, gchar const *name);
void gitg_ref_free(GitgRef *ref);
GitgRef *gitg_ref_copy(GitgRef *ref);

#endif /* __GITG_REF_H__ */

