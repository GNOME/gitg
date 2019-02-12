/*
 * gitg.c
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

#include <gtk/gtk.h>
#include <glib.h>
#include <glib/gi18n.h>
#include <stdlib.h>
#include <string.h>
#include <gtksourceview/gtksource.h>
#include <libgitg/gitg-debug.h>

#include "gitg-window.h"
#include "config.h"
#include "gitg-dirs.h"
#include "gitg-utils.h"
#include "gitg-uri.h"

static gboolean commit_mode = FALSE;
static gchar *select_sha1 = NULL;

static void
show_version_and_quit (void)
{
	g_print ("%s - Version %s\n", g_get_application_name (), VERSION);

	exit (0);
}

static GOptionEntry entries[] = 
{
	{ "version", 'V', G_OPTION_FLAG_NO_ARG, G_OPTION_ARG_CALLBACK,
	  show_version_and_quit, N_("Show the application's version"), NULL },
	{ "commit", 'c', 0, G_OPTION_ARG_NONE, &commit_mode, N_("Start gitg in commit mode") },
	{ "select", 's', 0, G_OPTION_ARG_STRING, &select_sha1, N_("Select commit after loading the repository") },
	{ NULL }
};

static void
parse_options (int *argc, char ***argv)
{
	GError *error = NULL;
	GOptionContext *context;

	context = g_option_context_new (_("- git repository viewer"));

	// Ignore unknown options so we can pass them to git
	g_option_context_set_ignore_unknown_options (context, TRUE);
	g_option_context_add_main_entries (context, entries, GETTEXT_PACKAGE);
	g_option_context_add_group (context, gtk_get_option_group (TRUE));

	if (!g_option_context_parse (context, argc, argv, &error))
	{
		g_print ("option parsing failed: %s\n", error->message);
		g_error_free (error);
		exit (1);
	}

	g_option_context_free(context);
}

static gboolean
on_window_delete_event (GtkWidget *widget, gpointer userdata)
{
	gtk_main_quit ();
	return FALSE;
}

static GitgWindow *
build_ui (void)
{
	GtkBuilder *builder = gitg_utils_new_builder ("gitg-window.ui");

	GtkWidget *window = GTK_WIDGET (gtk_builder_get_object(builder, "window"));
	gtk_widget_show_all (window);

	g_signal_connect_after (window, "destroy", G_CALLBACK (on_window_delete_event), NULL);
	g_object_unref (builder);

	return GITG_WINDOW (window);
}

static void
set_language_search_path (void)
{
	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default ();
	gchar const * const *orig = gtk_source_language_manager_get_search_path (manager);
	gchar const **dirs = g_new0 (gchar const *, g_strv_length ((gchar **)orig) + 2);
	guint i = 0;

	while (orig[i])
	{
		dirs[i + 1] = orig[i];
		++i;
	}

	gchar *path = gitg_dirs_get_data_filename ("language-specs", NULL);
	dirs[0] = path;
	gtk_source_language_manager_set_search_path (manager, (gchar **)dirs);
	g_free (path);

	g_free (dirs);
}

static void
set_style_scheme_search_path (void)
{
	GtkSourceStyleSchemeManager *manager = gtk_source_style_scheme_manager_get_default ();

	gchar *path = gitg_dirs_get_data_filename ("styles", NULL);
	gtk_source_style_scheme_manager_prepend_search_path (manager, path);
	g_free (path);
}

static void
set_icons (void)
{
	static gchar const *icon_infos[] = {
		"gitg16x16.png",
		"gitg22x22.png",
		"gitg24x24.png",
		"gitg32x32.png",
		"gitg48x48.png",
		"gitg64x64.png",
		"gitg128x128.png",
		NULL
	};

	int i;
	GList *icons = NULL;

	for (i = 0; icon_infos[i]; ++i)
	{
		gchar *filename = gitg_dirs_get_data_filename ("icons", icon_infos[i], NULL);
		GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file (filename, NULL);
		g_free (filename);

		if (pixbuf)
		{
			icons = g_list_prepend (icons, pixbuf);
		}
	}

	gtk_window_set_default_icon_list (icons);

	g_list_free_full (icons, g_object_unref);
}

int
main (int argc, char **argv)
{
	gboolean ret;

	gitg_debug_init ();

	bindtextdomain (GETTEXT_PACKAGE, GITG_LOCALEDIR);
	bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);

	g_set_prgname ("gitg");

	/* Translators: this is the application name as in g_set_application_name */
	g_set_application_name (_("gitg"));

	gitg_dirs_initialize (argc, argv);
	gtk_init (&argc, &argv);
	parse_options (&argc, &argv);

	set_language_search_path ();
	set_style_scheme_search_path ();
	set_icons ();

	GitgWindow *window = build_ui ();

	ret = gitg_window_load_repository_for_command_line (window,
	                                                    argc - 1,
	                                                    (gchar const **)argv + 1,
	                                                    select_sha1);

	if (commit_mode && ret)
	{
		gitg_window_show_commit (window);
	}

	gtk_main ();

	return 0;
}
