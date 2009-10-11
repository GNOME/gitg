#ifndef __GITG_REPOSITORY_DIALOG_H__
#define __GITG_REPOSITORY_DIALOG_H__

#include <gtk/gtk.h>
#include "gitg-window.h"

G_BEGIN_DECLS

#define GITG_TYPE_REPOSITORY_DIALOG				(gitg_repository_dialog_get_type ())
#define GITG_REPOSITORY_DIALOG(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY_DIALOG, GitgRepositoryDialog))
#define GITG_REPOSITORY_DIALOG_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_REPOSITORY_DIALOG, GitgRepositoryDialog const))
#define GITG_REPOSITORY_DIALOG_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_REPOSITORY_DIALOG, GitgRepositoryDialogClass))
#define GITG_IS_REPOSITORY_DIALOG(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_REPOSITORY_DIALOG))
#define GITG_IS_REPOSITORY_DIALOG_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_REPOSITORY_DIALOG))
#define GITG_REPOSITORY_DIALOG_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_REPOSITORY_DIALOG, GitgRepositoryDialogClass))

typedef struct _GitgRepositoryDialog		GitgRepositoryDialog;
typedef struct _GitgRepositoryDialogClass	GitgRepositoryDialogClass;
typedef struct _GitgRepositoryDialogPrivate	GitgRepositoryDialogPrivate;

struct _GitgRepositoryDialog
{
	GtkDialog parent;
	
	GitgRepositoryDialogPrivate *priv;
};

struct _GitgRepositoryDialogClass
{
	GtkDialogClass parent_class;
};

GType gitg_repository_dialog_get_type (void) G_GNUC_CONST;
GitgRepositoryDialog *gitg_repository_dialog_present(GitgWindow *window);

void gitg_repository_dialog_close ();

G_END_DECLS

#endif /* __GITG_REPOSITORY_DIALOG_H__ */
