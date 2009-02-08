/*
 * gitg-preferences-dialog.h
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
