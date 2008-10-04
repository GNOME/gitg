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
	GitgRef *inst = g_new0(GitgRef, 1);

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
	GitgRef *ret = g_new0(GitgRef, 1);
	
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
	g_free(ref->name);
	g_free(ref->shortname);

	g_free(ref);
}
