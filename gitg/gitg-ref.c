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

struct _GitgRef
{
	Hash hash;
	GitgRefType type;
	
	gchar *name;
	gchar *shortname;
	
	gchar *prefix;
	GitgRefState state;
};

GType 
gitg_ref_get_type (void)
{
	static GType our_type = 0;

	if (!our_type)
	{
		our_type = g_boxed_type_register_static("GitGRef",
		                                        (GBoxedCopyFunc)gitg_ref_copy,
		                                        (GBoxedFreeFunc)gitg_ref_free);
	}
	
	return our_type;
} 

GitgRef *
gitg_ref_new(gchar const *hash, gchar const *name)
{
	GitgRef *inst = g_slice_new0(GitgRef);

	gitg_utils_sha1_to_hash(hash, inst->hash);
	inst->name = g_strdup(name);
	
	PrefixTypeMap map[] = {
		{"refs/heads/", GITG_REF_TYPE_BRANCH},
		{"refs/remotes/", GITG_REF_TYPE_REMOTE},
		{"refs/tags/", GITG_REF_TYPE_TAG},
		{"refs/stash", GITG_REF_TYPE_STASH}
	};

	inst->prefix = NULL;
	
	// set type from name
	int i;
	for (i = 0; i < sizeof(map) / sizeof(PrefixTypeMap); ++i)
	{
		gchar *pos;

		if (!g_str_has_prefix(name, map[i].prefix))
			continue;
		
		inst->type = map[i].type;
		
		if (inst->type == GITG_REF_TYPE_STASH)
		{
			inst->shortname = g_strdup("stash");
		}
		else
		{
			inst->shortname = g_strdup(name + strlen(map[i].prefix));
		}
		
		if (map[i].type == GITG_REF_TYPE_REMOTE && (pos = strchr(inst->shortname, '/')))
		{
			inst->prefix = g_strndup(inst->shortname, pos - inst->shortname);
		}
		
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
	if (ref == NULL)
	{
		return NULL;
	}

	GitgRef *ret = g_slice_new0 (GitgRef);
	
	ret->type = ref->type;
	ret->name = g_strdup(ref->name);
	ret->shortname = g_strdup(ref->shortname);
	ret->prefix = g_strdup(ref->prefix);
	
	int i;
	for (i = 0; i < HASH_BINARY_SIZE; ++i)
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
	g_free(ref->prefix);

	g_slice_free(GitgRef, ref);
}

gboolean 
gitg_ref_equal(GitgRef *ref, GitgRef *other)
{
	if (ref == NULL && other == NULL)
		return TRUE;
	
	if (ref == NULL || other == NULL)
		return FALSE;

	return strcmp(ref->name, other->name) == 0;
}

gboolean
gitg_ref_equal_prefix(GitgRef *ref, GitgRef *other)
{
	if (ref == NULL && other == NULL)
		return TRUE;
	
	if (ref == NULL || other == NULL)
		return FALSE;

	return strcmp(ref->prefix, other->prefix) == 0;
}

gchar const *
gitg_ref_get_hash(GitgRef *ref)
{
	return ref->hash;
}

GitgRefType
gitg_ref_get_ref_type(GitgRef *ref)
{
	return ref->type;
}

gchar const *
gitg_ref_get_name(GitgRef *ref)
{
	return ref->name;
}

gchar const *
gitg_ref_get_shortname(GitgRef *ref)
{
	return ref->shortname;
}

gchar const *
gitg_ref_get_prefix(GitgRef *ref)
{
	return ref->prefix;
}

GitgRefState    
gitg_ref_get_state (GitgRef *ref)
{
	return ref->state;
}

void			
gitg_ref_set_state (GitgRef      *ref,
                    GitgRefState  state)
{
	ref->state = state;
}

gchar *
gitg_ref_get_local_name (GitgRef *ref)
{
	gchar const *shortname = gitg_ref_get_shortname (ref);
	gchar const *prefix = gitg_ref_get_prefix (ref);
	
	if (prefix && g_str_has_prefix (shortname, prefix))
	{
		return g_strdup (shortname + strlen(prefix) + 1);
	}
	else
	{
		return g_strdup (shortname);
	}
}
