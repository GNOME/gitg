#include "gitg-preferences-dialog.h"

#include "gitg-preferences.h"
#include "gitg-data-binding.h"

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
	GtkCheckButton *history_search_filter;
	GtkAdjustment *collapse_inactive_lanes;

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
	GitgPreferencesDialog *dialog = GITG_PREFERENCES_DIALOG(object);

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
initialize_view(GitgPreferencesDialog *dialog)
{
	GitgPreferences *preferences = gitg_preferences_get_default();
	
	gitg_data_binding_new_mutual(preferences, "history-search-filter", 
						         dialog->priv->history_search_filter, "active");

	gitg_data_binding_new_mutual_full(preferences, "history-collapse-inactive-lanes",
						              dialog->priv->collapse_inactive_lanes, "value",
						              (GitgDataBindingConversion)g_value_transform,
						              convert_collapsed,
						              dialog);
}

static void
create_preferences_dialog()
{
	GtkBuilder *b = gtk_builder_new();
	GError *error = NULL;

	if (!gtk_builder_add_from_file(b, GITG_UI_DIR "/gitg-preferences.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-preferences.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	preferences_dialog = GITG_PREFERENCES_DIALOG(gtk_builder_get_object(b, "dialog_preferences"));
	g_object_add_weak_pointer(G_OBJECT(preferences_dialog), (gpointer *)&preferences_dialog);
	
	GitgPreferencesDialogPrivate *priv = preferences_dialog->priv;
	priv->history_search_filter = GTK_CHECK_BUTTON(gtk_builder_get_object(b, "check_button_history_search_filter"));
	priv->collapse_inactive_lanes = GTK_ADJUSTMENT(gtk_builder_get_object(b, "adjustment_collapse_inactive_lanes"));
	
	priv->prev_value = (gint)gtk_adjustment_get_value(priv->collapse_inactive_lanes);
	g_signal_connect(preferences_dialog, "response", G_CALLBACK(on_response), NULL);
	
	initialize_view(preferences_dialog);

	gtk_builder_connect_signals(b, preferences_dialog);
	g_object_unref(b);
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

	g_signal_handlers_block_by_func(adjustment, G_CALLBACK(on_collapse_inactive_lanes_changed), dialog);
	gtk_adjustment_set_value(adjustment, val);
	g_signal_handlers_unblock_by_func(adjustment, G_CALLBACK(on_collapse_inactive_lanes_changed), dialog);
}
