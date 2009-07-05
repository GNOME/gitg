/*
 * gitg-settings.h
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

#ifndef __GITG_SETTINGS_H__
#define __GITG_SETTINGS_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define GITG_TYPE_SETTINGS				(gitg_settings_get_type ())
#define GITG_SETTINGS(obj)				(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SETTINGS, GitgSettings))
#define GITG_SETTINGS_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_SETTINGS, GitgSettings const))
#define GITG_SETTINGS_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_SETTINGS, GitgSettingsClass))
#define GITG_IS_SETTINGS(obj)			(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_SETTINGS))
#define GITG_IS_SETTINGS_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_SETTINGS))
#define GITG_SETTINGS_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_SETTINGS, GitgSettingsClass))

#define gitg_settings_set_window_state(settings, value) gitg_settings_set_integer(settings, "window-state", value)
#define gitg_settings_get_window_state(settings, def) gitg_settings_get_integer(settings, "window-state", def)

#define gitg_settings_set_window_width(settings, value) gitg_settings_set_integer(settings, "window-width", value)
#define gitg_settings_get_window_width(settings, def) gitg_settings_get_integer(settings, "window-width", def)

#define gitg_settings_set_window_height(settings, value) gitg_settings_set_integer(settings, "window-height", value)
#define gitg_settings_get_window_height(settings, def) gitg_settings_get_integer(settings, "window-height", def)

#define gitg_settings_set_vpaned_main_position(settings, value) gitg_settings_set_integer(settings, "vpaned-main-position", value)
#define gitg_settings_get_vpaned_main_position(settings, def) gitg_settings_get_integer(settings, "vpaned-main-position", def)

#define gitg_settings_set_hpaned_commit1_position(settings, value) gitg_settings_set_integer(settings, "hpaned-commit1-position", value)
#define gitg_settings_get_hpaned_commit1_position(settings, def) gitg_settings_get_integer(settings, "hpaned-commit1-position", def)

#define gitg_settings_set_hpaned_commit2_position(settings, value) gitg_settings_set_integer(settings, "hpaned-commit2-position", value)
#define gitg_settings_get_hpaned_commit2_position(settings, def) gitg_settings_get_integer(settings, "hpaned-commit2-position", def)

#define gitg_settings_set_vpaned_commit_position(settings, value) gitg_settings_set_integer(settings, "vpaned-commit-position", value)
#define gitg_settings_get_vpaned_commit_position(settings, def) gitg_settings_get_integer(settings, "vpaned-commit-position", def)

#define gitg_settings_set_revision_tree_view_position(settings, value) gitg_settings_set_integer(settings, "revision-tree-view-position", value)
#define gitg_settings_get_revision_tree_view_position(settings, def) gitg_settings_get_integer(settings, "revision-tree-view-position", def)

typedef struct _GitgSettings		GitgSettings;
typedef struct _GitgSettingsClass	GitgSettingsClass;
typedef struct _GitgSettingsPrivate	GitgSettingsPrivate;

struct _GitgSettings {
	GObject parent;
	
	GitgSettingsPrivate *priv;
};

struct _GitgSettingsClass {
	GObjectClass parent_class;
};

GType gitg_settings_get_type (void) G_GNUC_CONST;
GitgSettings *gitg_settings_get_default(void);
void gitg_settings_save(GitgSettings *settings);

gint gitg_settings_get_integer(GitgSettings *settings, gchar const *key, gint def);
void gitg_settings_set_integer(GitgSettings *setting, gchar const *key, gint value);

gdouble gitg_settings_get_double(GitgSettings *settings, gchar const *key, gdouble def);
void gitg_settings_set_double(GitgSettings *settings, gchar const *key, gdouble value);

gchar *gitg_settings_get_string(GitgSettings *settings, gchar const *key, gchar const *def);
void gitg_settings_set_string(GitgSettings *settings, gchar const *key, gchar const *value);

G_END_DECLS

#endif /* __GITG_SETTINGS_H__ */
