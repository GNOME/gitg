#include <gtk/gtk.h>
#include <glib.h>
#include <glib/gi18n.h>
#include <stdlib.h>
#include <string.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <gtksourceview/gtksourcestyleschememanager.h>

#include "gitg-window.h"
#include "sexy-icon-entry.h"
#include "config.h"

static gboolean commit_mode = FALSE;

static GOptionEntry entries[] = 
{
	{ "commit", 0, 0, G_OPTION_ARG_NONE, &commit_mode, N_("Start gitg in commit mode") }, 
	{ NULL }
};

void
parse_options(int *argc, char ***argv)
{
	GError *error = NULL;
	GOptionContext *context;
	
	context = g_option_context_new(_("- git repository viewer"));
	
	// Ignore unknown options so we can pass them to git
	g_option_context_set_ignore_unknown_options(context, TRUE);
	g_option_context_add_main_entries(context, entries, GETTEXT_PACKAGE);
	g_option_context_add_group(context, gtk_get_option_group (TRUE));
	
	if (!g_option_context_parse(context, argc, argv, &error))
	{
		g_print("option parsing failed: %s\n", error->message);
		g_error_free(error);
		exit(1);
	}
	
	g_option_context_free(context);
}

static gboolean
on_window_delete_event(GtkWidget *widget, GdkEvent *event, gpointer userdata)
{
	gtk_main_quit();
	return FALSE;
}

static GitgWindow *
build_ui()
{
	GError *error = NULL;
	
	GtkBuilder *builder = gtk_builder_new();
	gtk_builder_set_translation_domain(builder, GETTEXT_PACKAGE);
	
	if (!gtk_builder_add_from_file(builder, GITG_UI_DIR "/gitg-ui.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-ui.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	GtkWidget *window = GTK_WIDGET(gtk_builder_get_object(builder, "window"));
	gtk_widget_show_all(window);

	g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete_event), NULL);
	return GITG_WINDOW(window);
}

static void
set_language_search_path()
{
	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default();
	gchar const * const *orig = gtk_source_language_manager_get_search_path(manager);
	gchar const **dirs = g_new0(gchar const *, g_strv_length((gchar **)orig) + 2);
	guint i = 0;
	
	while (orig[i])
	{
		dirs[i + 1] = orig[i];
		++i;
	}
	
	dirs[0] = GITG_DATADIR "/language-specs";
	gtk_source_language_manager_set_search_path(manager, (gchar **)dirs);
}

static void
set_style_scheme_search_path()
{
	GtkSourceStyleSchemeManager *manager = gtk_source_style_scheme_manager_get_default();
	
	gtk_source_style_scheme_manager_prepend_search_path(manager, GITG_DATADIR "/styles");
}

int
main(int argc, char **argv)
{
	bindtextdomain(GETTEXT_PACKAGE, GITG_LOCALEDIR);
	bind_textdomain_codeset(GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);
	
	// Parse gtk options
	g_thread_init(NULL);

	gtk_init(&argc, &argv);
	parse_options(&argc, &argv);
	
	set_language_search_path();
	set_style_scheme_search_path();
	
	GitgWindow *window = build_ui();
	gitg_window_load_repository(window, argc > 1 ? argv[1] : NULL, argc - 2, (gchar const **)&argv[2]);
	
	if (commit_mode)
		gitg_window_show_commit(window);
	
	gtk_main();
	
	return 0;
}
