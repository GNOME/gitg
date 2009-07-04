/*
 * gitg-spinner.h
 * This file is part of gitg
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 * Copyright (C) 2005 - Paolo Maggi 
 * Copyright (C) 2000 - Eazel, Inc. 
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
 
/*
 * This widget was originally written by Andy Hertzfeld <andy@eazel.com> for
 * Nautilus.
 *
 * Modified by the gitg Team, 2005. See the AUTHORS file for a 
 * list of people on the gitg Team.  
 * See the ChangeLog files for a list of changes. 
 *
 * Modified by the gitg Team, 2009
 *
 * $Id$
 */

#ifndef __GITG_SPINNER_H__
#define __GITG_SPINNER_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

/*
 * Type checking and casting macros
 */
#define GITG_TYPE_SPINNER		(gitg_spinner_get_type ())
#define GITG_SPINNER(o)		(G_TYPE_CHECK_INSTANCE_CAST ((o), GITG_TYPE_SPINNER, GitgSpinner))
#define GITG_SPINNER_CLASS(k)		(G_TYPE_CHECK_CLASS_CAST((k), GITG_TYPE_SPINNER, GitgSpinnerClass))
#define GITG_IS_SPINNER(o)		(G_TYPE_CHECK_INSTANCE_TYPE ((o), GITG_TYPE_SPINNER))
#define GITG_IS_SPINNER_CLASS(k)	(G_TYPE_CHECK_CLASS_TYPE ((k), GITG_TYPE_SPINNER))
#define GITG_SPINNER_GET_CLASS(o)	(G_TYPE_INSTANCE_GET_CLASS ((o), GITG_TYPE_SPINNER, GitgSpinnerClass))


/* Private structure type */
typedef struct _GitgSpinnerPrivate	GitgSpinnerPrivate;

/*
 * Main object structure
 */
typedef struct _GitgSpinner		GitgSpinner;

struct _GitgSpinner
{
	GObject parent;

	/*< private >*/
	GitgSpinnerPrivate *priv;
};

/*
 * Class definition
 */
typedef struct _GitgSpinnerClass	GitgSpinnerClass;

struct _GitgSpinnerClass
{
	GObjectClass parent_class;
	
	void (*frame)(GitgSpinner *spinner, GdkPixbuf *pixbuf);
};

/*
 * Public methods
 */
GType			gitg_spinner_get_type	(void) G_GNUC_CONST;

GitgSpinner	   *gitg_spinner_new		(GtkIconSize  size);
void 			gitg_spinner_set_screen (GitgSpinner *spinner, 
										 GdkScreen   *screen);
void			gitg_spinner_start		(GitgSpinner  *spinner);
void			gitg_spinner_stop		(GitgSpinner  *spinner);

GdkPixbuf      *gitg_spinner_get_pixbuf (GitgSpinner *spinner);

G_END_DECLS

#endif /* __GITG_SPINNER_H__ */
