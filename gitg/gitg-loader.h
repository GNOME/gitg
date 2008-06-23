#include "gitg-rv-model.h"

#ifndef __GITG_LOADER_H__
#define __GITG_LOADER_H__

#include <glib-object.h>
#include "gitg-revision.h"
#include "gitg-runner.h"

G_BEGIN_DECLS

#define GITG_TYPE_LOADER			(gitg_loader_get_type ())
#define GITG_LOADER(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LOADER, GitgLoader))
#define GITG_LOADER_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_LOADER, GitgLoader const))
#define GITG_LOADER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_LOADER, GitgLoaderClass))
#define GITG_IS_LOADER(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_LOADER))
#define GITG_IS_LOADER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_LOADER))
#define GITG_LOADER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_LOADER, GitgLoaderClass))

typedef struct _GitgLoader			GitgLoader;
typedef struct _GitgLoaderClass		GitgLoaderClass;
typedef struct _GitgLoaderPrivate	GitgLoaderPrivate;

struct _GitgLoader {
	GitgRunner parent;
	
	GitgLoaderPrivate *priv;
};

struct _GitgLoaderClass {
	GitgRunnerClass parent_class;
	
	void (* revisions_added) (GitgLoader *loader, GitgRevision **revisions);
};

GType gitg_loader_get_type (void) G_GNUC_CONST;
GitgLoader *gitg_loader_new();

void gitg_loader_set_store(GitgLoader *loader, GitgRvModel *store);
GitgRvModel *gitg_loader_get_store(GitgLoader *loader);

gboolean gitg_loader_load(GitgLoader *loader, gchar const *path, GError **error);

G_END_DECLS

#endif /* __GITG_LOADER_H__ */
