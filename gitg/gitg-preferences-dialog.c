/*
 * gitg-preferences-dialog.c
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

#include "gitg-preferences-dialog.h"

#include "gitg-preferences.h"
#include "gitg-data-binding.h"
#include "gitg-utils.h"
#include "gitg-config.h"

#include <stdlib.h>
#include <glib/gi18n.h>

enum
{
	COLUMN_NAME,
	COLUMN_PROPERTY,
	N_COLUMNS
};

#define GITG_PREFERENCES_DIALOG_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_PREFERENCES_DIALOG, GitgPreferencesDialogPrivate))

static GitgPreferencesDialog *preferences_dialog;

struct _GitgPreferencesDialogPrivate
{
	GitgConfig *config;

	GtkCheckButton *history_search_filter;
	GtkAdjustment *collapse_inactive_lanes;
	GtkCheckButton *history_show_virtual_stash;
	GtkCheckButton *history_show_virtual_staged;
	GtkCheckButton *history_show_virtual_unstaged;
	GtkCheckButton *check_button_collapse_inactive;
	
	GtkCheckButton *check_button_show_right_margin;
	GtkLabel *label_right_margin;
	GtkSpinButton *spin_button_right_margin;
	
	GtkEntry *entry_configuration_user_name;
	GtkEntry *entry_configuration_user_email;
	
	GtkWidget *table;

	gint prev_value;
};

G_DEFINE_TYPE(GitgPreferencesDialog, gitg_preferences_dialog, GTK_TYPE_DIALOG)

static gint
round_val(gdouble val)
{
	gint ival = (gint)val;

	return ival + (val - ival > 0.5);
}

static void
gitg_preferences_dialog_finalize(GObject *object)
{
	GitgPreferencesDialog *dialog = GITG_PREFERENCES_DIALOG (object);
	
	g_object_unref (dialog->priv->config);
	
	G_OBJECT_CLASS(gitg_preferences_dialog_parent_class)->finalize(object);
}

static void
gitg_preferences_dialog_class_init(GitgPreferencesDialogClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_preferences_dialog_finalize;

	g_type_class_add_private(object_class, sizeof(GitgPreferencesDialogPrivate));
}

static void
gitg_preferences_dialog_init(GitgPreferencesDialog *self)
{
	self->priv = GITG_PREFERENCES_DIALOG_GET_PRIVATE(self);
	
	self->priv->config = gitg_config_new (NULL);
}

static void
on_response(GtkWidget *dialog, gint response, gpointer data)
{
	gtk_widget_destroy(dialog);
}

static gboolean
convert_collapsed(GValue const *source, GValue *dest, gpointer userdata)
{
	GitgPreferencesDialog *dialog = GITG_PREFERENCES_DIALOG(userdata);

	gint val = round_val(g_value_get_double(source));
	
	if (val == dialog->priv->prev_value)
		return FALSE;
	
	dialog->priv->prev_value = val;
	return g_value_transform(source, dest);
}

static void
on_collapse_inactive_toggled(GtkToggleButton *button, GitgPreferencesDialog *dialog)
{
	gboolean active = gtk_toggle_button_get_active (button);
	gtk_widget_set_sensitive(dialog->priv->table, active);
}

static void
on_check_button_show_right_margin_toggled(GtkToggleButton *button, GitgPreferencesDialog *dialog)
{
	gboolean active = gtk_toggle_button_get_active (button);

	gtk_widget_set_sensitive(GTK_WIDGET(dialog->priv->label_right_margin), active);
	gtk_widget_set_sensitive(GTK_WIDGET(dialog->priv->spin_button_right_margin), active);
}

static void
initialize_view(GitgPreferencesDialog *dialog)
{
	GitgPreferences *preferences = gitg_preferences_get_default();

	g_signal_connect (dialog->priv->check_button_collapse_inactive,
	                  "toggled",
	                  G_CALLBACK (on_collapse_inactive_toggled),
	                  dialog);

	g_signal_connect (dialog->priv->check_button_show_right_margin,
	                  "toggled",
	                  G_CALLBACK (on_check_button_show_right_margin_toggled),
	                  dialog);

	gitg_data_binding_new_mutual(preferences, 
	                             "history-search-filter", 
	                             dialog->priv->history_search_filter, 
	                             "active");

	gitg_data_binding_new_mutual_full(preferences, 
	                                  "history-collapse-inactive-lanes",
	                                  dialog->priv->collapse_inactive_lanes, 
	                                  "value",
	                                  (GitgDataBindingConversion)g_value_transform,
	                                  convert_collapsed,
	                                  dialog);

	gitg_data_binding_new_mutual(preferences, 
	                             "history-collapse-inactive-lanes-active",
	                             dialog->priv->check_button_collapse_inactive,
	                             "active");

	gitg_data_binding_new_mutual(preferences, 
	                             "history-show-virtual-stash",
	                             dialog->priv->history_show_virtual_stash, 
	                             "active");

	gitg_data_binding_new_mutual(preferences, 
	                             "history-show-virtual-staged",
	                             dialog->priv->history_show_virtual_staged, 
	                             "active");

	gitg_data_binding_new_mutual(preferences, 
	                             "history-show-virtual-unstaged",
	                             dialog->priv->history_show_virtual_unstaged, 
	                             "active");

	gitg_data_binding_new_mutual(preferences,
	                             "message-show-right-margin",
	                             dialog->priv->check_button_show_right_margin,
	                             "active");

	gitg_data_binding_new_mutual(preferences,
	                             "message-right-margin-at",
	                             dialog->priv->spin_button_right_margin,
	                             "value");
}

static void
create_preferences_dialog()
{
	GtkBuilder *b = gitg_utils_new_builder("gitg-preferences.ui");
	
	preferences_dialog = GITG_PREFERENCES_DIALOG(gtk_builder_get_object(b, "dialog_preferences"));
	g_object_add_weak_pointer(G_OBJECT(preferences_dialog), (gpointer *)&preferences_dialog);
	
	GitgPreferencesDialogPrivate *priv = preferences_dialog->priv;
	
	priv->history_search_filter = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_history_search_filter"));
	priv->collapse_inactive_lanes = GTK_ADJUSTMENT(gtk_builder_get_object(b, "adjustment_collapse_inactive_lanes"));
	
	priv->history_show_virtual_stash = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_history_show_virtual_stash"));
	priv->history_show_virtual_staged = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_history_show_virtual_staged"));
	priv->history_show_virtual_unstaged = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_history_show_virtual_unstaged"));
	
	priv->check_button_collapse_inactive = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_collapse_inactive"));
	priv->table = GTK_WIDGET(gtk_builder_get_object(b, "table_collapse_inactive_lanes"));
	
	priv->check_button_show_right_margin = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_show_right_margin"));
	priv->label_right_margin = GTK_LABEL(gtk_builder_get_object(b, "label_right_margin"));
	priv->spin_button_right_margin = GTK_SPIN_BUTTON(gtk_builder_get_object(b, "spin_button_right_margin"));
	
	priv->prev_value = (gint)gtk_adjustment_get_value(priv->collapse_inactive_lanes);
	g_signal_connect(preferences_dialog, "response", G_CALLBACK(on_response), NULL);
	
	initialize_view(preferences_dialog);
	
	priv->entry_configuration_user_name = GTK_ENTRY(gtk_builder_get_object(b, "entry_configuration_user_name"));
	priv->entry_configuration_user_email = GTK_ENTRY(gtk_builder_get_object(b, "entry_configuration_user_email"));

	gtk_builder_connect_signals(b, preferences_dialog);
	g_object_unref(b);
	
	gchar *val;
	
	val = gitg_config_get_value (priv->config, "user.name");
	gtk_entry_set_text (priv->entry_configuration_user_name, val ? val : "");
	g_free (val);
	
	val = gitg_config_get_value (priv->config, "user.email");
	gtk_entry_set_text (priv->entry_configuration_user_email, val ? val : "");
	g_free (val);
}

GitgPreferencesDialog *
gitg_preferences_dialog_present(GtkWindow *window)
{
	if (!preferences_dialog)
		create_preferences_dialog();

	gtk_window_set_transient_for(GTK_WINDOW(preferences_dialog), window);
	gtk_window_present(GTK_WINDOW(preferences_dialog));

	return preferences_dialog;
}

void
on_collapse_inactive_lanes_changed(GtkAdjustment *adjustment, GParamSpec *spec, GitgPreferencesDialog *dialog)
{
	gint val = round_val(gtk_adjustment_get_value(adjustment));

	if (val > 0)
	{
		g_signal_handlers_block_by_func(adjustment, G_CALLBACK(on_collapse_inactive_lanes_changed), dialog);
		gtk_adjustment_set_value(adjustment, val);
		g_signal_handlers_unblock_by_func(adjustment, G_CALLBACK(on_collapse_inactive_lanes_changed), dialog);
	}
}

gboolean
on_entry_configuration_user_name_focus_out_event(GtkEntry *entry, GdkEventFocus *event, GitgPreferencesDialog *dialog)
{
	gitg_config_set_value (dialog->priv->config, "user.name", gtk_entry_get_text (entry));
	return FALSE;
}

gboolean
on_entry_configuration_user_email_focus_out_event(GtkEntry *entry, GdkEventFocus *event, GitgPreferencesDialog *dialog)
{
	gitg_config_set_value (dialog->priv->config, "user.email", gtk_entry_get_text (entry));
	return FALSE;
}

