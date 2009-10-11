/*
 * gitg-preferences.c
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

#include "gitg-preferences.h"
#include <gtksourceview/gtksourcestyleschememanager.h>
#include <gconf/gconf-client.h>
#include <string.h>

#define GITG_PREFERENCES_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_PREFERENCES, GitgPreferencesPrivate))

#define KEY_ROOT "/apps/gitg/preferences"

/* Properties */
enum
{
	PROP_0,
	
	PROP_HISTORY_SEARCH_FILTER,

	PROP_HISTORY_COLLAPSE_INACTIVE_LANES_ACTIVE,
	PROP_HISTORY_COLLAPSE_INACTIVE_LANES,

	PROP_HISTORY_SHOW_VIRTUAL_STASH,
	PROP_HISTORY_SHOW_VIRTUAL_STAGED,
	PROP_HISTORY_SHOW_VIRTUAL_UNSTAGED,
	
	PROP_MESSAGE_SHOW_RIGHT_MARGIN,
	PROP_MESSAGE_RIGHT_MARGIN_AT,
	
	PROP_HIDDEN_SIGN_TAG,

	PROP_STYLE_TEXT_FOREGROUND,
	PROP_STYLE_TEXT_BACKGROUND,
	PROP_STYLE_TEXT_STYLE,
	
	PROP_STYLE_ADDED_LINE_FOREGROUND,
	PROP_STYLE_ADDED_LINE_BACKGROUND,
	PROP_STYLE_ADDED_LINE_STYLE,

	PROP_STYLE_REMOVED_LINE_FOREGROUND,
	PROP_STYLE_REMOVED_LINE_BACKGROUND,
	PROP_STYLE_REMOVED_LINE_STYLE,

	PROP_STYLE_CHANGED_LINE_FOREGROUND,
	PROP_STYLE_CHANGED_LINE_BACKGROUND,
	PROP_STYLE_CHANGED_LINE_STYLE,

	PROP_STYLE_HEADER_FOREGROUND,
	PROP_STYLE_HEADER_BACKGROUND,
	PROP_STYLE_HEADER_STYLE,

	PROP_STYLE_HUNK_FOREGROUND,
	PROP_STYLE_HUNK_BACKGROUND,
	PROP_STYLE_HUNK_STYLE,
	
	PROP_STYLE_TRAILING_SPACES_FOREGROUND,
	PROP_STYLE_TRAILING_SPACES_BACKGROUND,
	PROP_STYLE_TRAILING_SPACES_STYLE,

	PROP_LAST
};

typedef struct _Binding Binding;

typedef void (*WrapGet)(GitgPreferences *preferences, Binding *binding, GValue *value);
typedef gboolean (*WrapSet)(GitgPreferences *preferences, Binding *binding, GValue const *value);

static void on_preference_changed(GConfClient *client, guint id, GConfEntry *entry, GitgPreferences *preferences);

struct _Binding
{
	gchar key[PATH_MAX];
	gchar property[PATH_MAX];

	WrapGet wrap_get;
	WrapSet wrap_set;
};

struct _GitgPreferencesPrivate
{
	GConfClient *client;
	
	guint notify_id;
	
	gboolean block_notify[PROP_LAST];
};

G_DEFINE_TYPE(GitgPreferences, gitg_preferences, G_TYPE_OBJECT)

static Binding property_bindings[PROP_LAST];

static gboolean
wrap_set_boolean(GitgPreferences *preferences, Binding *binding, GValue const *value)
{
	gboolean val = g_value_get_boolean(value);
	return gconf_client_set_bool(preferences->priv->client, binding->key, val, NULL);
}

static void
wrap_get_boolean(GitgPreferences *preferences, Binding *binding, GValue *value)
{
	gboolean val = gconf_client_get_bool(preferences->priv->client, binding->key, NULL);
	g_value_set_boolean(value, val);
}

static gboolean
wrap_set_int(GitgPreferences *preferences, Binding *binding, GValue const *value)
{
	gint val = g_value_get_int(value);
	return gconf_client_set_int(preferences->priv->client, binding->key, val, NULL);
}

static void
wrap_get_int(GitgPreferences *preferences, Binding *binding, GValue *value)
{
	gint val = gconf_client_get_int(preferences->priv->client, binding->key, NULL);
	g_value_set_int(value, val);
}

static gboolean
wrap_set_string(GitgPreferences *preferences, Binding *binding, GValue const *value)
{
	gchar const *val = g_value_get_string(value);
	return gconf_client_set_string(preferences->priv->client, binding->key, val ? val : "", NULL);
}

static void
wrap_get_string(GitgPreferences *preferences, Binding *binding, GValue *value)
{
	gchar *val = gconf_client_get_string(preferences->priv->client, binding->key, NULL);
	g_value_take_string(value, val);
}

static void
finalize_notify(GitgPreferences *preferences)
{
	gconf_client_remove_dir(preferences->priv->client, KEY_ROOT, NULL);
	gconf_client_notify_remove(preferences->priv->client, preferences->priv->notify_id);
}

static void
gitg_preferences_finalize(GObject *object)
{
	GitgPreferences *preferences = GITG_PREFERENCES(object);
	
	finalize_notify(preferences);
	
	g_object_unref(preferences->priv->client);
	G_OBJECT_CLASS(gitg_preferences_parent_class)->finalize(object);
}

static void
gitg_preferences_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgPreferences *self = GITG_PREFERENCES(object);
	
	if (prop_id > PROP_0 && prop_id < PROP_LAST)
	{
		Binding *b = &property_bindings[prop_id];
		self->priv->block_notify[prop_id] = b->wrap_set(self, b, value);
	}
	else
	{
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
	}
}

static void
gitg_preferences_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgPreferences *self = GITG_PREFERENCES(object);

	if (prop_id > PROP_0 && prop_id < PROP_LAST)
	{
		Binding *b = &property_bindings[prop_id];
		b->wrap_get(self, b, value);
	}
	else
	{
		G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
	}
}

static void
install_property_binding(guint prop_id, gchar const *group, gchar const *name, WrapGet wrap_get, WrapSet wrap_set)
{
	Binding *b = &property_bindings[prop_id];
	
	g_snprintf(b->key, PATH_MAX, "%s/%s/%s", KEY_ROOT, group, name);

	gchar const *prefix = g_utf8_strrchr(group, -1, '/');
	
	if (prefix)
	{
		prefix += 1;
	}
	else
	{
		prefix = group;
	}
	
	g_snprintf(b->property, PATH_MAX, "%s-%s", prefix, name);

	b->wrap_get = wrap_get;
	b->wrap_set = wrap_set;
}

static void
install_style_properties(GObjectClass *object_class, guint prop_start, gchar const *name)
{
	gchar *group = g_strconcat("style/", name, NULL);

	/* install bindings */
	install_property_binding(prop_start + 0,
							 group,
							 "foreground",
							 wrap_get_string,
							 wrap_set_string);

	install_property_binding(prop_start + 1,
							 group,
							 "background",
							 wrap_get_string,
							 wrap_set_string);

	install_property_binding(prop_start + 2,
							 group,
							 "style",
							 wrap_get_int,
							 wrap_set_int);
	g_free(group);
	
	gchar *stylename = g_strconcat("gitgdiff:", name, NULL);
	
	GtkSourceStyleSchemeManager *manager = gtk_source_style_scheme_manager_get_default();
	GtkSourceStyleScheme *scheme = gtk_source_style_scheme_manager_get_scheme(manager, "gitg");
	GtkSourceStyle *style = gtk_source_style_scheme_get_style(scheme, stylename);
	
	g_free(stylename);

	gchar *foreground = NULL;
	gchar *background = NULL;
	gboolean line_background;
	
	group = g_strconcat(name, "-foreground", NULL);
	g_object_get(G_OBJECT(style), "line-background-set", &line_background, NULL);

	g_object_get(G_OBJECT(style), "foreground", &foreground, line_background ? "line-background" : "background", &background, NULL);

	/* install foreground property */
	g_object_class_install_property(object_class, prop_start + 0,
					 g_param_spec_string(group,
							      NULL,
							      NULL,
							      foreground,
							      G_PARAM_READWRITE));

	g_free(group);
	group = g_strconcat(name, "-background", NULL);

	/* install background property */
	g_object_class_install_property(object_class, prop_start + 1,
					 g_param_spec_string(group,
							      NULL,
							      NULL,
							      background,
							      G_PARAM_READWRITE));

	g_free(group);
	group = g_strconcat(name, "-style", NULL);

	gboolean bold;
	gboolean italic;
	gboolean underline;

	g_object_get(G_OBJECT(style), "bold", &bold, "italic", &italic, "underline", &underline, NULL);

	/* install style property */
	g_object_class_install_property(object_class, prop_start + 2,
					 g_param_spec_int(group,
							      NULL,
							      NULL,
							      0,
							      G_MAXINT,
							      bold << 0 | italic << 1 | underline << 2 | line_background << 3,
							      G_PARAM_READWRITE));

	g_free(group);

	g_free(foreground);
	g_free(background);
}

static void
gitg_preferences_class_init(GitgPreferencesClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_preferences_finalize;
	object_class->set_property = gitg_preferences_set_property;
	object_class->get_property = gitg_preferences_get_property;

	install_property_binding(PROP_HISTORY_SEARCH_FILTER, 
							 "view/history",
							 "search-filter", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HISTORY_SEARCH_FILTER,
					 g_param_spec_boolean("history-search-filter",
							      "HISTORY_SEARCH_FILTER",
							      "Filter revisions when searching",
							      FALSE,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HISTORY_COLLAPSE_INACTIVE_LANES_ACTIVE, 
							 "view/history",
							 "collapse-inactive-lanes-active", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HISTORY_COLLAPSE_INACTIVE_LANES_ACTIVE,
					 g_param_spec_boolean("history-collapse-inactive-lanes-active",
							      "HISTORY_COLLAPSE_INACTIVE_LANES_ACTIVE",
							      "Collapsing inactive lanes active",
							      TRUE,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HISTORY_COLLAPSE_INACTIVE_LANES, 
							 "view/history",
							 "collapse-inactive-lanes", 
							 wrap_get_int,
							 wrap_set_int);

	g_object_class_install_property(object_class, PROP_HISTORY_COLLAPSE_INACTIVE_LANES,
					 g_param_spec_int("history-collapse-inactive-lanes",
							      "HISTORY_COLLAPSE_INACTIVE_LANES",
							      "Rule for collapsing inactive lanes",
							      0,
							      5,
							      2,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HISTORY_SHOW_VIRTUAL_STASH, 
							 "view/history",
							 "show-virtual-stash", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HISTORY_SHOW_VIRTUAL_STASH,
					 g_param_spec_boolean("history-show-virtual-stash",
							      "HISTORY_SHOW_VIRTUAL_STASH",
							      "Show stash in history",
							      TRUE,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HISTORY_SHOW_VIRTUAL_STAGED, 
							 "view/history",
							 "show-virtual-staged", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HISTORY_SHOW_VIRTUAL_STAGED,
					 g_param_spec_boolean("history-show-virtual-staged",
							      "HISTORY_SHOW_VIRTUAL_STAGED",
							      "Show staged changes in history",
							      TRUE,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HISTORY_SHOW_VIRTUAL_UNSTAGED, 
							 "view/history",
							 "show-virtual-unstaged", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HISTORY_SHOW_VIRTUAL_UNSTAGED,
					 g_param_spec_boolean("history-show-virtual-unstaged",
							      "HISTORY_SHOW_VIRTUAL_UNSTAGED",
							      "Show unstaged changes in history",
							      TRUE,
							      G_PARAM_READWRITE));


	install_property_binding(PROP_MESSAGE_SHOW_RIGHT_MARGIN, 
							 "commit/message",
							 "show-right-margin", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_MESSAGE_SHOW_RIGHT_MARGIN,
					 g_param_spec_boolean("message-show-right-margin",
							      "MESSAGE_SHOW_RIGHT_MARGIN",
							      "Show right margin in commit message view",
							      TRUE,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_MESSAGE_RIGHT_MARGIN_AT, 
							 "commit/message",
							 "right-margin-at", 
							 wrap_get_int,
							 wrap_set_int);

	g_object_class_install_property(object_class, PROP_MESSAGE_RIGHT_MARGIN_AT,
					 g_param_spec_int("message-right-margin-at",
							      "MESSAGE_RIGHT_MARGIN_AT",
							      "The column to show the right margin at",
							      1,
							      160,
							      72,
							      G_PARAM_READWRITE));

	install_property_binding(PROP_HIDDEN_SIGN_TAG, 
							 "hidden",
							 "sign-tag", 
							 wrap_get_boolean,
							 wrap_set_boolean);

	g_object_class_install_property(object_class, PROP_HIDDEN_SIGN_TAG,
					 g_param_spec_boolean("hidden-sign-tag",
							      "HIDDEN_SIGN_TAG",
							      "Whether to sign tag objects",
							      TRUE,
							      G_PARAM_READWRITE));

	install_style_properties(object_class, PROP_STYLE_TEXT_FOREGROUND, "text");
	install_style_properties(object_class, PROP_STYLE_ADDED_LINE_FOREGROUND, "added-line");
	install_style_properties(object_class, PROP_STYLE_REMOVED_LINE_FOREGROUND, "removed-line");
	install_style_properties(object_class, PROP_STYLE_CHANGED_LINE_FOREGROUND, "changed-line");
	install_style_properties(object_class, PROP_STYLE_HEADER_FOREGROUND, "header");
	install_style_properties(object_class, PROP_STYLE_HUNK_FOREGROUND, "hunk");
	install_style_properties(object_class, PROP_STYLE_TRAILING_SPACES_FOREGROUND, "trailing-spaces");

	g_type_class_add_private(object_class, sizeof(GitgPreferencesPrivate));
}

static void
initialize_notify(GitgPreferences *preferences)
{
	gconf_client_add_dir(preferences->priv->client, 
					     KEY_ROOT, 
					     GCONF_CLIENT_PRELOAD_NONE,
					     NULL);

	gconf_client_notify_add(preferences->priv->client, 
							KEY_ROOT,
							(GConfClientNotifyFunc)on_preference_changed,
							preferences,
							NULL,
							NULL);							
}

static void
initialize_default_values(GitgPreferences *preferences)
{
	guint i;
	GObjectClass *class = G_OBJECT_GET_CLASS(G_OBJECT(preferences));

	for (i = PROP_0 + 1; i < PROP_LAST; ++i)
	{
		Binding *binding = &property_bindings[i];
		
		GConfValue *v = gconf_client_get_without_default(preferences->priv->client, binding->key, NULL);
		
		if (v)
		{
			gconf_value_free(v);
			continue;
		}
		
		GParamSpec *spec = g_object_class_find_property(class, binding->property);
		GValue value = {0,};
		
		/* Get default value */
		g_value_init(&value, G_PARAM_SPEC_VALUE_TYPE(spec));
		g_param_value_set_default(spec, &value);
		
		/* Set it */
		g_object_set_property(G_OBJECT(preferences), binding->property, &value);
		
		g_value_unset(&value);		
	}
}

static void
gitg_preferences_init(GitgPreferences *self)
{
	self->priv = GITG_PREFERENCES_GET_PRIVATE(self);
	
	self->priv->client = gconf_client_get_default();
	
	initialize_notify(self);
	
	/* Set initial values for properties that have defaults and do not exist
	   yet */
	initialize_default_values(self);
}

GitgPreferences *
gitg_preferences_get_default()
{
	static GitgPreferences *preferences = NULL;
	
	if (!preferences)
	{
		preferences = g_object_new(GITG_TYPE_PREFERENCES, NULL);
		g_object_add_weak_pointer(G_OBJECT(preferences), (gpointer *)&preferences);
	}
	
	return preferences;
}

/* Callbacks */
static void 
on_preference_changed(GConfClient *client, guint id, GConfEntry *entry, GitgPreferences *preferences)
{
	gchar const *key = gconf_entry_get_key(entry);
	
	/* Find corresponding property */
	guint i;
	
	for (i = PROP_0 + 1; i < PROP_LAST; ++i)
	{
		Binding *b = &property_bindings[i];
		
		if (strcmp(key, b->key) == 0)
		{
			/* Property match, emit notify */
			if (!preferences->priv->block_notify[i])
				g_object_notify(G_OBJECT(preferences), b->property);
			
			preferences->priv->block_notify[i] = FALSE;
			break;
		}
	}
}
