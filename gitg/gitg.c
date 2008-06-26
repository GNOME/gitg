#include <gtk/gtk.h>
#include <glib.h>
#include <glib/gi18n.h>
#include <stdlib.h>
#include <string.h>
#include <gtksourceview/gtksourceview.h>
#include <gdk/gdkkeysyms.h>

#include "gitg-repository.h"
#include "gitg-revision-view.h"
#include "gitg-utils.h"
#include "gitg-runner.h"
#include "sexy-icon-entry.h"
#include "config.h"

static GOptionEntry entries[] = 
{
	{ NULL }
};

static GtkWindow *window;
static GtkBuilder *builder;
static GtkTreeView *tree_view;
static GtkStatusbar *statusbar;
static GtkWidget *search_popup;
static GitgRepository *repository;
static GitgRevisionView *revision_view;

void
parse_options(int *argc, char ***argv)
{
	GError *error = NULL;
	GOptionContext *context;
	
	context = g_option_context_new(_("- git repository viewer"));
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
	gtk_tree_view_set_model(tree_view, NULL);

	g_object_unref(builder);
	gtk_main_quit();
}

static gint
string_compare(GtkTreeModel *model, GtkTreeIter *a, GtkTreeIter *b, gpointer userdata)
{
	return 0; //gitg_rv_model_compare(store, a, b, GPOINTER_TO_INT(userdata));
}

static void
on_selection_changed(GtkTreeSelection *selection, gpointer userdata)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	GitgRevision *revision = NULL;
	
	if (gtk_tree_selection_get_selected(selection, &model, &iter))
		gtk_tree_model_get(GTK_TREE_MODEL(model), &iter, 0, &revision, -1);
	
	gitg_revision_view_update(revision_view, repository, revision);
}

static void
build_tree_view()
{
	tree_view = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_rv"));

	gtk_tree_view_set_model(tree_view, GTK_TREE_MODEL(repository));

	gtk_tree_view_insert_column_with_attributes(tree_view, 
			0, _("Subject"), gtk_cell_renderer_text_new(), "text", 1, NULL);
			
	gtk_tree_view_insert_column_with_attributes(tree_view, 
			1, _("Author"), gtk_cell_renderer_text_new(), "text", 2, NULL);
	
	gtk_tree_view_insert_column_with_attributes(tree_view, 
			2, _("Date"), gtk_cell_renderer_text_new(), "text", 3, NULL);
	
	int i;
	GtkTreeViewColumn *column;
	
	guint cw[] = {400, 200, 200};

	for (i = 0; i < 3; ++i)
	{
		column = gtk_tree_view_get_column(tree_view, i);
		gtk_tree_view_column_set_resizable(column, TRUE);
		gtk_tree_view_column_set_sizing(column, GTK_TREE_VIEW_COLUMN_FIXED);
		gtk_tree_view_column_set_fixed_width(column, cw[i]);
		
		gtk_tree_view_column_set_sort_column_id(column, i + 1);
		//gtk_tree_sortable_set_sort_func(GTK_TREE_SORTABLE(store), i + 1, string_compare, GINT_TO_POINTER(i + 1), NULL);
	}
	
	GtkTreeSelection *selection = gtk_tree_view_get_selection(tree_view);

	g_signal_connect(selection, "changed", G_CALLBACK(on_selection_changed), NULL);
}

static GtkImage *
search_image()
{
	return GTK_IMAGE(gtk_image_new_from_stock(GTK_STOCK_FIND, GTK_ICON_SIZE_MENU));
}

static void
on_search_icon_pressed(SexyIconEntry *entry, SexyIconEntryPosition icon_pos, int button, gpointer userdata)
{
	gtk_menu_popup(GTK_MENU(search_popup), NULL, NULL, NULL, NULL, button, gtk_get_current_event_time());
}

void
search_column_activate(GtkAction *action, gint column)
{
	if (!gtk_toggle_action_get_active(GTK_TOGGLE_ACTION(action)))
		return;

	gtk_tree_view_set_search_column(tree_view, column);
}

void
on_hash_activate(GtkAction *action, gpointer data)
{
	search_column_activate(action, 4);
}

void
on_subject_activate(GtkAction *action, gpointer data)
{
	search_column_activate(action, 1);
}

void
on_author_activate(GtkAction *action, gpointer data)
{
	search_column_activate(action, 2);
}

void
on_date_activate(GtkAction *action, gpointer data)
{
	search_column_activate(action, 3);
}

static gboolean
search_hash_equal_func(GtkTreeModel *model, gchar const *key, GtkTreeIter *iter)
{
	GitgRevision *rv;
	gtk_tree_model_get(model, iter, 0, &rv, -1);
	
	gchar *sha = gitg_revision_get_sha1(rv);
	
	gboolean ret = strncmp(sha, key, strlen(key)) != 0;
	
	g_free(sha);
	g_object_unref(rv);
	
	return ret;
}

static gboolean
search_equal_func(GtkTreeModel *model, gint column, gchar const *key, GtkTreeIter *iter, gpointer userdata)
{
	if (column == 4)
		return search_hash_equal_func(model, key, iter);

	gchar *cmp;
	gtk_tree_model_get(model, iter, column, &cmp, -1);
	
	gchar *s1 = g_utf8_casefold(key, -1);
	gchar *s2 = g_utf8_casefold(cmp, -1);
	
	gboolean ret = strstr(s2, s1) == NULL;
	
	g_free(s1);
	g_free(s2);

	g_free(cmp);
	
	return ret;
}

static void
focus_search(GtkAccelGroup *group, GObject *acceleratable, guint keyval, GdkModifierType modifier, gpointer userdata)
{
	gtk_widget_grab_focus(GTK_WIDGET(userdata));
}

static void
build_search()
{
	GtkWidget *box = GTK_WIDGET(gtk_builder_get_object(builder, "hbox_top"));
	GtkWidget *entry = sexy_icon_entry_new();
	
	GtkImage *image = search_image();
	sexy_icon_entry_set_icon(SEXY_ICON_ENTRY(entry), SEXY_ICON_ENTRY_PRIMARY, image);
	
	gtk_tree_view_set_search_entry(tree_view, GTK_ENTRY(entry));
	gtk_widget_show(entry);
	gtk_box_pack_end(GTK_BOX(box), entry, FALSE, FALSE, 0);
	
	GtkBuilder *b = gtk_builder_new();
	GError *error = NULL;

	if (!gtk_builder_add_from_file(b, GITG_UI_DIR "/gitg-menus.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-menus.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	GtkUIManager *manager = GTK_UI_MANAGER(gtk_builder_get_object(b, "uiman"));
	search_popup = GTK_WIDGET(g_object_ref(gtk_ui_manager_get_widget(manager, "/ui/search_popup")));
		
	gtk_builder_connect_signals(b, NULL);
	g_object_unref(b);
	
	g_signal_connect(entry, "icon-pressed", G_CALLBACK(on_search_icon_pressed), NULL);
	gtk_tree_view_set_search_column(tree_view, 1);
	
	gtk_tree_view_set_search_equal_func(tree_view, search_equal_func, entry, NULL);
	
	GtkAccelGroup *group = gtk_accel_group_new();
	
	GClosure *closure = g_cclosure_new(G_CALLBACK(focus_search), entry, NULL); 
	gtk_accel_group_connect(group, GDK_f, GDK_CONTROL_MASK, 0, closure); 
	gtk_window_add_accel_group(window, group);
}

static gboolean
on_parent_activated(GitgRevisionView *view, gchar *hash, gpointer userdata)
{
	GtkTreeIter iter;
	
	if (!gitg_repository_find_by_hash(repository, hash, &iter))
		return FALSE;
	
	gtk_tree_selection_select_iter(gtk_tree_view_get_selection(tree_view), &iter);
	GtkTreePath *path;
	
	path = gtk_tree_model_get_path(GTK_TREE_MODEL(repository), &iter);
	
	gtk_tree_view_scroll_to_cell(tree_view, path, NULL, FALSE, 0, 0);
	gtk_tree_path_free(path);
	return TRUE;
}

static void
build_ui()
{
	GError *error = NULL;
	
	builder = gtk_builder_new();
	gtk_builder_set_translation_domain(builder, GETTEXT_PACKAGE);
	
	if (!gtk_builder_add_from_file(builder, GITG_UI_DIR "/gitg-ui.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-ui.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	window = GTK_WINDOW(gtk_builder_get_object(builder, "window"));
	gtk_widget_show_all(GTK_WIDGET(window));

	build_tree_view();
	build_search();

	g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete_event), NULL);
	
	statusbar = GTK_STATUSBAR(gtk_builder_get_object(builder, "statusbar"));
	revision_view = GITG_REVISION_VIEW(gtk_builder_get_object(builder, "revision_view"));
	
	g_signal_connect(revision_view, "parent-activated", G_CALLBACK(on_parent_activated), NULL);
}

static void
on_begin_loading(GitgRunner *loader, gpointer userdata)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(tree_view)->window, cursor);
	gdk_cursor_unref(cursor);

	gtk_statusbar_push(statusbar, 0, _("Begin loading repository"));
}

static void
on_end_loading(GitgRunner *loader, gpointer userdata)
{
	gchar *msg = g_strdup_printf(_("Loaded %d revisions"), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(repository), NULL));

	gtk_statusbar_push(statusbar, 0, msg);
	
	g_free(msg);
	gdk_window_set_cursor(GTK_WIDGET(tree_view)->window, NULL);
}

static void
on_update(GitgRunner *loader, gchar **revisions, gpointer userdata)
{
	gchar *msg = g_strdup_printf(_("Loading %d revisions..."), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(repository), NULL));

	gtk_statusbar_push(statusbar, 0, msg);
	g_free(msg);
}

static gboolean
handle_no_gitdir(gpointer userdata)
{
	if (gitg_repository_get_path(repository))
		return FALSE;

	GtkWidget *dlg = gtk_message_dialog_new(window, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, _("Gitg repository could not be found"));
	
	gtk_dialog_run(GTK_DIALOG(dlg));
	gtk_widget_destroy(dlg);
	return FALSE;
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

	gchar *gitdir = argc > 1 ? g_strdup(argv[1]) : g_get_current_dir();
	repository = gitg_repository_new(gitdir);
	g_free(gitdir);
	
	build_ui();

	GitgRunner *loader = gitg_repository_get_loader(repository);
	g_signal_connect(loader, "begin-loading", G_CALLBACK(on_begin_loading), NULL);
	g_signal_connect(loader, "end-loading", G_CALLBACK(on_end_loading), NULL);
	g_signal_connect(loader, "update", G_CALLBACK(on_update), NULL);
	g_object_unref(loader);
	
	gitg_repository_load(repository, NULL);
	g_object_unref(repository);
	
	g_idle_add(handle_no_gitdir, NULL);
	gtk_main();
	
	return 0;
}
