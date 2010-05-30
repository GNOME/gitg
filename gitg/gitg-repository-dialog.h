/*
 * gitg-repository-dialog.h
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

void gitg_repository_dialog_close (void);

G_END_DECLS

#endif /* __GITG_REPOSITORY_DIALOG_H__ */
