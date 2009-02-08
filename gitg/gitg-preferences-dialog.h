#ifndef __GITG_PREFERENCES_DIALOG_H__
#define __GITG_PREFERENCES_DIALOG_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GITG_TYPE_PREFERENCES_DIALOG			(gitg_preferences_dialog_get_type ())
#define GITG_PREFERENCES_DIALOG(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_PREFERENCES_DIALOG, GitgPreferencesDialog))
#define GITG_PREFERENCES_DIALOG_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_PREFERENCES_DIALOG, GitgPreferencesDialog const))
#define GITG_PREFERENCES_DIALOG_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_PREFERENCES_DIALOG, GitgPreferencesDialogClass))
#define GITG_IS_PREFERENCES_DIALOG(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_PREFERENCES_DIALOG))
#define GITG_IS_PREFERENCES_DIALOG_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_PREFERENCES_DIALOG))
#define GITG_PREFERENCES_DIALOG_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_PREFERENCES_DIALOG, GitgPreferencesDialogClass))

typedef struct _GitgPreferencesDialog			GitgPreferencesDialog;
typedef struct _GitgPreferencesDialogClass		GitgPreferencesDialogClass;
typedef struct _GitgPreferencesDialogPrivate	GitgPreferencesDialogPrivate;

struct _GitgPreferencesDialog {
	GtkDialog parent;
	
	GitgPreferencesDialogPrivate *priv;
};

struct _GitgPreferencesDialogClass {
	GtkDialogClass parent_class;
};

GType gitg_preferences_dialog_get_type(void) G_GNUC_CONST;
GitgPreferencesDialog *gitg_preferences_dialog_present(GtkWindow *window);

G_END_DECLS

#endif /* __GITG_PREFERENCES_DIALOG_H__ */
