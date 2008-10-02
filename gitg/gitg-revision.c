#include "gitg-revision.h"
#include "gitg-utils.h"

#define GITG_REVISION_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION, GitgRevisionPrivate))

struct _GitgRevisionPrivate
{
	Hash hash;
	gchar *author;
	gchar *subject;
	Hash *parents;
	guint num_parents;
	
	GSList *lanes;
	gint8 mylane;

	gint64 timestamp;
};

G_DEFINE_TYPE(GitgRevision, gitg_revision, G_TYPE_OBJECT)

static void
free_lanes(GitgRevision *rv)
{
	g_slist_foreach(rv->priv->lanes, (GFunc)gitg_lane_free, NULL);
	g_slist_free(rv->priv->lanes);
	rv->priv->lanes = NULL;
}

static void
gitg_revision_finalize(GObject *object)
{
	GitgRevision *rv = GITG_REVISION(object);
	
	g_free(rv->priv->author);
	g_free(rv->priv->subject);
	g_free(rv->priv->parents);
	
	free_lanes(rv);
	
	G_OBJECT_CLASS(gitg_revision_parent_class)->finalize(object);
}

static void
gitg_revision_class_init(GitgRevisionClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_revision_finalize;

	g_type_class_add_private(object_class, sizeof(GitgRevisionPrivate));
}

static void
gitg_revision_init(GitgRevision *self)
{
	self->priv = GITG_REVISION_GET_PRIVATE(self);
}

GitgRevision *gitg_revision_new(gchar const *sha, 
		gchar const *author, 
		gchar const *subject, 
		gchar const *parents, 
		gint64 timestamp)
{
	GitgRevision *rv = g_object_new(GITG_TYPE_REVISION, NULL);
	
	gitg_utils_sha1_to_hash(sha, rv->priv->hash);
	rv->priv->author = g_strdup(author);
	rv->priv->subject = g_strdup(subject);
	rv->priv->timestamp = timestamp;
	
	gchar **shas = g_strsplit(parents, " ", 0);
	gint num = g_strv_length(shas);
	rv->priv->parents = g_new(Hash, num + 1);
	
	int i;
	for (i = 0; i < num; ++i)
		gitg_utils_sha1_to_hash(shas[i], rv->priv->parents[i]);
	
	g_strfreev(shas);
	rv->priv->num_parents = num;
	
	return rv;
}

gchar const *
gitg_revision_get_author(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);
	return revision->priv->author;
}

gchar const *
gitg_revision_get_subject(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);
	return revision->priv->subject;
}

guint64
gitg_revision_get_timestamp(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), 0);
	return revision->priv->timestamp;
}

gchar const *
gitg_revision_get_hash(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);
	return revision->priv->hash;
}

gchar *
gitg_revision_get_sha1(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);

	char res[40];
	gitg_utils_hash_to_sha1(revision->priv->hash, res);

	return g_strndup(res, 40);
}

Hash *
gitg_revision_get_parents_hash(GitgRevision *revision, guint *num_parents)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);
	
	if (num_parents)
		*num_parents = revision->priv->num_parents;

	return revision->priv->parents;
}

gchar **
gitg_revision_get_parents(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);

	gchar **ret = g_new(gchar *, revision->priv->num_parents + 1);
	
	int i;
	for (i = 0; i < revision->priv->num_parents; ++i)
	{
		ret[i] = g_new(gchar, 41);
		gitg_utils_hash_to_sha1(revision->priv->parents[i], ret[i]);
		
		ret[i][40] = '\0';
	}

	ret[revision->priv->num_parents] = NULL;

	return ret;
}

GSList *
gitg_revision_get_lanes(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), NULL);
	return g_slist_copy(revision->priv->lanes);
}

void 
gitg_revision_set_lanes(GitgRevision *revision, GSList *lanes)
{
	g_return_if_fail(GITG_IS_REVISION(revision));
	
	free_lanes(revision);
	revision->priv->lanes = lanes;
}

gint8
gitg_revision_get_mylane(GitgRevision *revision)
{
	g_return_val_if_fail(GITG_IS_REVISION(revision), -1);
	return revision->priv->mylane;
}

void 
gitg_revision_set_mylane(GitgRevision *revision, gint8 mylane)
{
	g_return_if_fail(GITG_IS_REVISION(revision));
	revision->priv->mylane = mylane;
}
