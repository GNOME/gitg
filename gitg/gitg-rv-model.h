#ifndef __GITG_RV_MODEL_H__
#define __GITG_RV_MODEL_H__

#include <gtk/gtkliststore.h>

#include "gitg-revision.h"

G_BEGIN_DECLS

#define GITG_TYPE_RV_MODEL				(gitg_rv_model_get_type ())
#define GITG_RV_MODEL(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RV_MODEL, GitgRvModel))
#define GITG_RV_MODEL_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_RV_MODEL, GitgRvModel const))
#define GITG_RV_MODEL_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_RV_MODEL, GitgRvModelClass))
#define GITG_IS_RV_MODEL(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_RV_MODEL))
#define GITG_IS_RV_MODEL_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_RV_MODEL))
#define GITG_RV_MODEL_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_RV_MODEL, GitgRvModelClass))

typedef struct _GitgRvModel			GitgRvModel;
typedef struct _GitgRvModelClass	GitgRvModelClass;
typedef struct _GitgRvModelPrivate	GitgRvModelPrivate;

struct _GitgRvModel {
	GtkListStore parent;
	
	GitgRvModelPrivate *priv;
};

struct _GitgRvModelClass {
	GtkListStoreClass parent_class;
};

GType gitg_rv_model_get_type (void) G_GNUC_CONST;
GitgRvModel *gitg_rv_model_new(void);

void gitg_rv_model_add(GitgRvModel *self, GitgRevision *obj, GtkTreeIter *iter);
gboolean gitg_rv_model_find_by_hash(GitgRvModel *self, gchar const *hash, GtkTreeIter *iter);
gboolean gitg_rv_model_find(GitgRvModel *store, GitgRevision *revision, GtkTreeIter *iter);

gint gitg_rv_model_compare(GitgRvModel *store, GtkTreeIter *a, GtkTreeIter *b, gint col);

G_END_DECLS

#endif /* __GITG_RV_MODEL_H__ */
