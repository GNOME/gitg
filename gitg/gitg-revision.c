#include "gitg-revision.h"
#include "gitg-utils.h"

struct _GitgRevision
{
	gint refcount;

	Hash hash;
	gchar *author;
	gchar *subject;
	Hash *parents;
	guint num_parents;
	char sign;
	
	GSList *lanes;
	gint8 mylane;

	gint64 timestamp;
};

static void
free_lanes(GitgRevision *rv)
{
	g_slist_foreach(rv->lanes, (GFunc)gitg_lane_free, NULL);
	g_slist_free(rv->lanes);
	rv->lanes = NULL;
}

static void
gitg_revision_finalize(GitgRevision *revision)
{
	g_free(revision->author);
	g_free(revision->subject);
	g_free(revision->parents);
	
	free_lanes(revision);
	
	g_slice_free(GitgRevision, revision);
}

GitgRevision *
gitg_revision_ref(GitgRevision *revision)
{
	g_atomic_int_inc(&revision->refcount);
	return revision;
}

void
gitg_revision_unref(GitgRevision *revision)
{
	if (!g_atomic_int_dec_and_test(&revision->refcount))
		return;
	
	gitg_revision_finalize(revision);
}

GitgRevision *gitg_revision_new(gchar const *sha, 
		gchar const *author, 
		gchar const *subject, 
		gchar const *parents, 
		gint64 timestamp)
{
	GitgRevision *rv = g_slice_new0 (GitgRevision);
	
	rv->refcount = 1;

	gitg_utils_sha1_to_hash(sha, rv->hash);
	rv->author = g_strdup(author);
	rv->subject = g_strdup(subject);
	rv->timestamp = timestamp;
	
	gchar **shas = g_strsplit(parents, " ", 0);
	gint num = g_strv_length(shas);
	rv->parents = g_new(Hash, num + 1);
	
	int i;
	for (i = 0; i < num; ++i)
		gitg_utils_sha1_to_hash(shas[i], rv->parents[i]);
	
	g_strfreev(shas);
	rv->num_parents = num;
	
	return rv;
}

gchar const *
gitg_revision_get_author(GitgRevision *revision)
{
	return revision->author;
}

gchar const *
gitg_revision_get_subject(GitgRevision *revision)
{
	return revision->subject;
}

guint64
gitg_revision_get_timestamp(GitgRevision *revision)
{
	return revision->timestamp;
}

gchar const *
gitg_revision_get_hash(GitgRevision *revision)
{
	return revision->hash;
}

gchar *
gitg_revision_get_sha1(GitgRevision *revision)
{
	char res[40];
	gitg_utils_hash_to_sha1(revision->hash, res);

	return g_strndup(res, 40);
}

Hash *
gitg_revision_get_parents_hash(GitgRevision *revision, guint *num_parents)
{
	if (num_parents)
		*num_parents = revision->num_parents;

	return revision->parents;
}

gchar **
gitg_revision_get_parents(GitgRevision *revision)
{
	gchar **ret = g_new(gchar *, revision->num_parents + 1);
	
	int i;
	for (i = 0; i < revision->num_parents; ++i)
	{
		ret[i] = g_new(gchar, 41);
		gitg_utils_hash_to_sha1(revision->parents[i], ret[i]);
		
		ret[i][40] = '\0';
	}

	ret[revision->num_parents] = NULL;

	return ret;
}

GSList *
gitg_revision_get_lanes(GitgRevision *revision)
{
	return g_slist_copy(revision->lanes);
}

static void
update_lane_type(GitgRevision *revision)
{
	GitgLane *lane = (GitgLane *)g_slist_nth_data(revision->lanes, revision->mylane);
	
	if (lane == NULL)
		return;
	
	lane->type &= ~(GITG_LANE_SIGN_LEFT | GITG_LANE_SIGN_RIGHT);
	
	if (revision->sign == '<')
		lane->type |= GITG_LANE_SIGN_LEFT;
	else if (revision->sign == '>')
		lane->type |= GITG_LANE_SIGN_RIGHT;
}

void 
gitg_revision_set_lanes(GitgRevision *revision, GSList *lanes, gint8 mylane)
{
	free_lanes(revision);
	revision->lanes = lanes;
	
	if (mylane > 0)
		revision->mylane = mylane;

	update_lane_type(revision);
}

gint8
gitg_revision_get_mylane(GitgRevision *revision)
{
	return revision->mylane;
}

void 
gitg_revision_set_mylane(GitgRevision *revision, gint8 mylane)
{
	revision->mylane = mylane;
	update_lane_type(revision);
}

void
gitg_revision_set_sign(GitgRevision *revision, char sign)
{
	revision->sign = sign;
}

char
gitg_revision_get_sign(GitgRevision *revision)
{
	return revision->sign;
}

GType 
gitg_revision_get_type (void)
{
	static GType our_type = 0;

	if (!our_type)
		our_type = g_boxed_type_register_static(
			"GitgRevision",
			(GBoxedCopyFunc)gitg_revision_ref,
			(GBoxedFreeFunc)gitg_revision_unref);

	return our_type;
} 
