/*
 * gitg-ref.c
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

#include "gitg-ref.h"
#include "gitg-utils.h"
#include <string.h>

typedef struct 
{
	gchar const *prefix;
	GitgRefType type;
} PrefixTypeMap;

GitgRef *
gitg_ref_new(gchar const *hash, gchar const *name)
{
	GitgRef *inst = g_slice_new0(GitgRef);

	gitg_utils_sha1_to_hash(hash, inst->hash);
	inst->name = g_strdup(name);
	
	PrefixTypeMap map[] = {
		{"refs/heads/", GITG_REF_TYPE_BRANCH},
		{"refs/remotes/", GITG_REF_TYPE_REMOTE},
		{"refs/tags/", GITG_REF_TYPE_TAG}
	};
	
	// set type from name
	int i;
	for (i = 0; i < sizeof(map) / sizeof(PrefixTypeMap); ++i)
	{
		if (!g_str_has_prefix(name, map[i].prefix))
			continue;
		
		inst->type = map[i].type;
		inst->shortname = g_strdup(name + strlen(map[i].prefix));
		break;
	}
	
	if (inst->shortname == NULL)
	{
		inst->type = GITG_REF_TYPE_NONE;
		inst->shortname = g_strdup(name);
	}
	
	return inst;
}

GitgRef *
gitg_ref_copy(GitgRef *ref)
{
	GitgRef *ret = g_slice_new0(GitgRef);
	
	ret->type = ref->type;
	ret->name = g_strdup(ref->name);
	ret->shortname = g_strdup(ref->shortname);
	
	int i;
	for (i = 0; i < 20; ++i)
		ret->hash[i] = ref->hash[i];

	return ret;
}

void
gitg_ref_free(GitgRef *ref)
{
	if (!ref)
		return;

	g_free(ref->name);
	g_free(ref->shortname);

	g_slice_free(GitgRef, ref);
}
