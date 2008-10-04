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

