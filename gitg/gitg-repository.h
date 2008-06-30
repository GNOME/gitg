#ifndef __GITG_REPOSITORY_H__
#define __GITG_REPOSITORY_H__

#include <gtk/gtktreemodel.h>

#include "gitg-revision.h"
#include "gitg-runner.h"

G_BEGIN_DECLS

#define GITG_TYPE_REPOSITORY			(gitg_repository_get_type ())
#define GITG_REPOSITORY(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY, GitgRepository))
#define GITG_REPOSITORY_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY, GitgRepository const))
#define GITG_REPOSITORY_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REPOSITORY, GitgRepositoryClass))
#define GITG_IS_REPOSITORY(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REPOSITORY))
#define GITG_IS_REPOSITORY_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REPOSITORY))
#define GITG_REPOSITORY_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REPOSITORY, GitgRepositoryClass))

typedef struct _GitgRepository			GitgRepository;
typedef struct _GitgRepositoryClass	GitgRepositoryClass;
typedef struct _GitgRepositoryPrivate	GitgRepositoryPrivate;

typedef enum 
{
	GITG_REPOSITORY_NO_ERROR = 0,
	GITG_REPOSITORY_ERROR_NOT_FOUND
} GitgRepositoryError;

struct _GitgRepository
{
	GObject parent;
	
	GitgRepositoryPrivate *priv;
};

struct _GitgRepositoryClass
{
	GObjectClass parent_class;
};

GType gitg_repository_get_type (void) G_GNUC_CONST;
GitgRepository *gitg_repository_new(gchar const *path);
gchar const *gitg_repository_get_path(GitgRepository *repository);
GitgRunner *gitg_repository_get_loader(GitgRepository *repository);

gboolean gitg_repository_load(GitgRepository *repository, int argc, gchar **argv, GError **error);

void gitg_repository_add(GitgRepository *repository, GitgRevision *revision, GtkTreeIter *iter);
void gitg_repository_clear(GitgRepository *repository);

gboolean gitg_repository_find_by_hash(GitgRepository *self, gchar const *hash, GtkTreeIter *iter);
gboolean gitg_repository_find(GitgRepository *store, GitgRevision *revision, GtkTreeIter *iter);

G_END_DECLS

#endif /* __GITG_REPOSITORY_H__ */
