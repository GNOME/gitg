/*
 * gitg-preferences.h
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

#ifndef __GITG_PREFERENCES_H__
#define __GITG_PREFERENCES_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define GITG_TYPE_PREFERENCES				(gitg_preferences_get_type ())
#define GITG_PREFERENCES(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_PREFERENCES, GitgPreferences))
#define GITG_PREFERENCES_CONST(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_PREFERENCES, GitgPreferences const))
#define GITG_PREFERENCES_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_PREFERENCES, GitgPreferencesClass))
#define GITG_IS_PREFERENCES(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_PREFERENCES))
#define GITG_IS_PREFERENCES_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_PREFERENCES))
#define GITG_PREFERENCES_GET_CLASS(obj)		(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_PREFERENCES, GitgPreferencesClass))

typedef enum
{
	GITG_PREFERENCES_STYLE_NONE = 0,
	GITG_PREFERENCES_STYLE_BOLD = 1 << 0,
	GITG_PREFERENCES_STYLE_ITALIC = 1 << 1,
	GITG_PREFERENCES_STYLE_UNDERLINE = 1 << 2,
	GITG_PREFERENCES_STYLE_LINE_BACKGROUND = 1 << 3,
} GitgPreferencesStyleFlags;

typedef struct _GitgPreferences			GitgPreferences;
typedef struct _GitgPreferencesClass	GitgPreferencesClass;
typedef struct _GitgPreferencesPrivate	GitgPreferencesPrivate;

struct _GitgPreferences {
	GObject parent;

	GitgPreferencesPrivate *priv;
};

struct _GitgPreferencesClass {
	GObjectClass parent_class;
};

GType gitg_preferences_get_type (void) G_GNUC_CONST;
GitgPreferences *gitg_preferences_get_default (void);

G_END_DECLS

#endif /* __GITG_PREFERENCES_H__ */
