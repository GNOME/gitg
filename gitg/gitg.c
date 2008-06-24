#include <gtk/gtk.h>
#include <glib.h>
#include <glib/gi18n.h>
#include <stdlib.h>
#include <string.h>
#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>

#include "gitg-rv-model.h"
#include "gitg-utils.h"
#include "gitg-loader.h"
#include "sexy-icon-entry.h"
#include "config.h"

static GOptionEntry entries[] = 
{
	{ NULL }
};

static GtkWindow *window;
static GtkBuilder *builder;
static GtkTreeView *tree_view;
static GitgRvModel *store;
static GtkStatusbar *statusbar;
static GitgRunner *diff_runner;
static GtkSourceView *diff_view;
static gchar *gitdir;
static GtkWidget *search_popup;

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
}

static gboolean
on_window_delete_event(GtkWidget *widget, GdkEvent *event, gpointer userdata)
{
	gitg_runner_cancel(diff_runner);

	gtk_tree_view_set_model(tree_view, NULL);
	g_object_unref(builder);
	gtk_main_quit();
}

static gint
string_compare(GtkTreeModel *model, GtkTreeIter *a, GtkTreeIter *b, gpointer userdata)
{
	return gitg_rv_model_compare(store, a, b, GPOINTER_TO_INT(userdata));
}

static gchar *
format_sha(GitgRevision *revision, gpointer data)
{
	return gitg_revision_get_sha1(revision);
}

static gchar *
make_bold(GitgRevision *revision, gpointer data)
{
	return g_strconcat("<b>", (gchar*)data, "</b>", NULL);
}

static gchar *
format_date(GitgRevision *revision, gpointer data)
{
	guint64 timestamp = gitg_revision_get_timestamp(revision);
	
	// Remove newline
	char *c = ctime((time_t *)&timestamp);
	return g_strndup(c, strlen(c) - 1);
}

typedef gchar * (*TransformFunc)(GitgRevision *revision, gpointer data);
typedef struct
{
	GObject *object;
	gint column;
	gchar const *property;
	TransformFunc transform;
} Binding;

static void
on_selection_binding_changed(GtkTreeSelection *selection, Binding *binding)
{
	GtkTreeModel *model;
	GtkTreeIter iter;

	GValue value = {0,};
	g_value_init(&value, G_TYPE_STRING);
	
	if (gtk_tree_selection_get_selected(selection, &model, &iter))
	{
		gchar *res;
		
		if (binding->transform)
		{
			GitgRevision *rv;
			gpointer ptr;

			gtk_tree_model_get(model, &iter, 0, &rv, binding->column, &ptr, -1);
			res = binding->transform(rv, ptr);
			g_object_unref(rv);
			
			if (binding->column != -1)
				g_free(ptr);
		}
		else
		{
			gtk_tree_model_get(model, &iter, binding->column, &res, -1);
		}
		
		g_value_take_string(&value, res);
	}
	else
	{
		g_value_set_string(&value, "");
	}
	
	g_object_set_property(binding->object, binding->property, &value);
	g_value_unset(&value);
}

static void
bind(GtkTreeSelection *selection, gint column, GObject *object, gchar const *property, TransformFunc cb)
{
	Binding *b = g_new0(Binding, 1);
	b->column = column;
	b->object = object;
	b->property = property;
	b->transform = cb;
	
	g_signal_connect_data(selection, "changed", G_CALLBACK(on_selection_binding_changed), b, (GClosureNotify)g_free, 0);
}

static void
update_markup(GObject *object)
{
	GtkLabel *label = GTK_LABEL(object);
	gchar const *text = gtk_label_get_text(label);
	
	gchar *newtext = g_strconcat("<span weight='bold' foreground='#777'>", text, "</span>", NULL);

	gtk_label_set_markup(label, newtext);
	g_free(newtext);
}

static gboolean
on_parent_clicked(GtkWidget *ev, GdkEventButton *event, gpointer userdata)
{
	if (event->button != 1)
		return FALSE;
	
	GtkTreeIter iter;
	if (gitg_rv_model_find_by_hash(store, (gchar *)userdata, &iter))
		gtk_tree_selection_select_iter(gtk_tree_view_get_selection(tree_view), &iter);

	return TRUE;
}

static GtkWidget *
make_parent_label(gchar *hash)
{
	GtkWidget *ev = gtk_event_box_new();
	GtkWidget *lbl = gtk_label_new(NULL);
	
	gchar *markup = g_strconcat("<span underline='single' foreground='#00f'>", hash, "</span>", NULL);
	gtk_label_set_markup(GTK_LABEL(lbl), markup);
	g_free(markup);

	gtk_misc_set_alignment(GTK_MISC(lbl), 0.0, 0.5);
	gtk_container_add(GTK_CONTAINER(ev), lbl);
	
	gtk_widget_show(ev);
	gtk_widget_show(lbl);
	
	
	g_signal_connect_data(ev, "button-release-event", G_CALLBACK(on_parent_clicked), gitg_utils_sha1_to_hash_new(hash), (GClosureNotify)g_free, 0);

	return ev;
}

static void
on_update_parents(GtkTreeSelection *selection, GtkVBox *container)
{
	GList *children = gtk_container_get_children(GTK_CONTAINER(container));
	GList *item;
	
	for (item = children; item; item = item->next)
		gtk_container_remove(GTK_CONTAINER(container), GTK_WIDGET(item->data));
	
	g_list_free(children);
	
	GtkTreeModel *model;
	GtkTreeIter iter;

	if (!gtk_tree_selection_get_selected(selection, &model, &iter))
		return;
	
	GitgRevision *rv;
	gtk_tree_model_get(model, &iter, 0, &rv, -1);
	
	gchar **parents = gitg_revision_get_parents(rv);
	gchar **ptr;
	
	for (ptr = parents; *ptr; ++ptr)
	{
		GtkWidget *widget = make_parent_label(*ptr);
		gtk_box_pack_start(GTK_BOX(container), widget, FALSE, TRUE, 0);
		
		gtk_widget_realize(widget);
		GdkCursor *cursor = gdk_cursor_new(GDK_HAND1);
		gdk_window_set_cursor(widget->window, cursor);
		gdk_cursor_unref(cursor);
	}
	
	g_strfreev(parents);	
	g_object_unref(rv);
}

static void
on_update_diff(GtkTreeSelection *selection, GtkVBox *container)
{	
	// First cancel a possibly still running diff
	gitg_runner_cancel(diff_runner);
	
	// Clear the buffer
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(diff_view));
	gtk_text_buffer_set_text(buffer, "", 0);
	
	GtkTreeModel *model;
	GtkTreeIter iter;
	
	if (!gtk_tree_selection_get_selected(selection, &model, &iter))
		return;
	
	GitgRevision *rv;
	gtk_tree_model_get(model, &iter, 0, &rv, -1);
	gchar *hash = gitg_revision_get_sha1(rv);

	gchar *argv[] = {
		"git",
		"--git-dir",
		gitdir,
		"show",
		"--pretty=format:%s%n%n%b",
		"--encoding=UTF-8",
		hash,
		NULL
	};
	
	gitg_runner_run(diff_runner, argv, NULL);
	g_object_unref(rv);
	g_free(hash);
}

static void
build_tree_view()
{
	tree_view = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_rv"));
	store = gitg_rv_model_new();

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
		gtk_tree_sortable_set_sort_func(GTK_TREE_SORTABLE(store), i + 1, string_compare, GINT_TO_POINTER(i + 1), NULL);
	}
	
	GtkTreeSelection *selection = gtk_tree_view_get_selection(tree_view);
	
	bind(selection, 1, gtk_builder_get_object(builder, "label_subject"), "label", make_bold);
	bind(selection, 2, gtk_builder_get_object(builder, "label_author"), "label", NULL);
	bind(selection, -1, gtk_builder_get_object(builder, "label_date"), "label", format_date);
	bind(selection, -1, gtk_builder_get_object(builder, "label_sha"), "label", format_sha);

	g_signal_connect(selection, "changed", G_CALLBACK(on_update_parents), gtk_builder_get_object(builder, "vbox_parents"));
	g_signal_connect(selection, "changed", G_CALLBACK(on_update_diff), NULL);

	gchar const *lbls[] = {
		"label_subject_lbl",
		"label_author_lbl",
		"label_sha_lbl",
		"label_date_lbl",
		"label_parent_lbl"
	};

	gtk_tree_view_set_headers_clickable(tree_view, TRUE);
	for (i = 0; i < sizeof(lbls) / sizeof(gchar *); ++i)
		update_markup(gtk_builder_get_object(builder, lbls[i]));
}

static void
build_diff_view()
{
	GtkWidget *box = GTK_WIDGET(gtk_builder_get_object(builder, "scrolled_window_details"));
	diff_view = GTK_SOURCE_VIEW(gtk_source_view_new());

	gtk_text_view_set_editable(GTK_TEXT_VIEW(diff_view), FALSE);
	gtk_source_view_set_tab_width(diff_view, 4);

	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default();
	GtkSourceLanguage *language = gtk_source_language_manager_get_language(manager, "diff");
	gtk_source_buffer_set_language(GTK_SOURCE_BUFFER(gtk_text_view_get_buffer(GTK_TEXT_VIEW(diff_view))), language);
	
	gtk_widget_show(GTK_WIDGET(diff_view));
	gtk_container_add(GTK_CONTAINER(box), GTK_WIDGET(diff_view));
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

static void
untoggle_all(GtkAction *action)
{
	GtkActionGroup *ag;
	g_object_get(action, "action-group", &ag, NULL);
	
	GList *actions = gtk_action_group_list_actions(ag);
	GList *item;
	
	for (item = actions; item; item = item->next)
	{
		if (GTK_ACTION(item->data) != action)
			gtk_toggle_action_set_active(GTK_TOGGLE_ACTION(item->data), FALSE);
	}

	g_list_free(actions);
	g_object_unref(ag);
}

void
search_column_activate(GtkAction *action, gint column)
{
	if (!gtk_toggle_action_get_active(GTK_TOGGLE_ACTION(action)))
		return;

	untoggle_all(action);
	gtk_tree_view_set_search_column(tree_view, column);
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
}

static void
build_ui()
{
	GError *error = NULL;
	builder = gtk_builder_new();
	
	if (!gtk_builder_add_from_file(builder, GITG_UI_DIR "/gitg-ui.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-ui.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	window = GTK_WINDOW(gtk_builder_get_object(builder, "window"));
	gtk_widget_show_all(GTK_WIDGET(window));

	build_tree_view();
	build_diff_view();
	build_search();

	g_signal_connect(window, "delete-event", G_CALLBACK(on_window_delete_event), NULL);
	statusbar = GTK_STATUSBAR(gtk_builder_get_object(builder, "statusbar"));
}

static void
on_diff_begin_loading(GitgRunner *runner, gpointer userdata)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(diff_view)->window, cursor);
	gdk_cursor_unref(cursor);
}

static void
on_diff_end_loading(GitgRunner *runner, gpointer userdata)
{
	gdk_window_set_cursor(GTK_WIDGET(diff_view)->window, NULL);
}

static void
on_diff_update(GitgRunner *runner, gchar **buffer, gpointer userdata)
{
	gchar *line;
	GtkTextBuffer *buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(diff_view));
	GtkTextIter iter;
	
	gtk_text_buffer_get_end_iter(buf, &iter);
	
	while ((line = *buffer++))
		gtk_text_buffer_insert(buf, &iter, line, -1);
}

static void
on_begin_loading(GitgLoader *loader, gpointer userdata)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(tree_view)->window, cursor);
	gdk_cursor_unref(cursor);

	gtk_statusbar_push(statusbar, 0, _("Begin loading repository"));
}

static void
on_end_loading(GitgLoader *loader, gpointer userdata)
{
	gchar *msg = g_strdup_printf(_("Loaded %d revisions"), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(store), NULL));

	gtk_statusbar_push(statusbar, 0, msg);
	
	g_free(msg);

	gtk_tree_view_set_model(tree_view, GTK_TREE_MODEL(store));
	
	gdk_window_set_cursor(GTK_WIDGET(tree_view)->window, NULL);
}

static void
on_update(GitgLoader *loader, GitgRevision **revisions)
{
	GitgRevision *rv;
	
	gtk_tree_view_set_model(tree_view, NULL);
		
	while ((rv = *revisions++))
		gitg_rv_model_add(store, rv, NULL);
	
	gchar *msg = g_strdup_printf(_("Loading %d revisions..."), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(store), NULL));

	gtk_statusbar_push(statusbar, 0, msg);
	g_free(msg);
	
	//gtk_tree_view_set_model(tree_view, GTK_TREE_MODEL(store));
}

static gchar *
find_dot_git(gchar *path)
{
	while (strcmp(path, ".") != 0)
	{
		gchar *res = g_build_filename(path, ".git", NULL);
		
		if (g_file_test(res, G_FILE_TEST_IS_DIR))
		{
			g_free(path);
			return res;
		}
		
		gchar *tmp = g_path_get_dirname(path);
		g_free(path);
		path = tmp;
		
		g_free(res);
	}
	
	return NULL;
}

static gboolean
handle_no_gitdir(gpointer userdata)
{
	if (gitdir)
		return FALSE;

	GtkWidget *dlg = gtk_message_dialog_new(window, GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, _("No .git directory found"));
	
	gtk_dialog_run(GTK_DIALOG(dlg));
	gtk_widget_destroy(dlg);
	return FALSE;
}

int
main(int argc, char **argv)
{
	bindtextdomain (GETTEXT_PACKAGE, GITG_LOCALEDIR);
	bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
	textdomain (GETTEXT_PACKAGE);
	
	// Parse gtk options
	g_thread_init(NULL);

	gtk_init(&argc, &argv);
	parse_options(&argc, &argv);

	gitdir = find_dot_git(argc > 1 ? g_strdup(argv[1]) : g_get_current_dir());
	build_ui();

	GitgLoader *loader = gitg_loader_new(store);
	diff_runner = gitg_runner_new(2000);
	
	g_signal_connect(diff_runner, "begin-loading", G_CALLBACK(on_diff_begin_loading), NULL);
	g_signal_connect(diff_runner, "update", G_CALLBACK(on_diff_update), NULL);
	g_signal_connect(diff_runner, "end-loading", G_CALLBACK(on_diff_end_loading), NULL);

	g_signal_connect(loader, "begin-loading", G_CALLBACK(on_begin_loading), NULL);
	g_signal_connect(loader, "revisions-added", G_CALLBACK(on_update), NULL);
	g_signal_connect(loader, "end-loading", G_CALLBACK(on_end_loading), NULL);
	
	if (gitdir != NULL)
		gitg_loader_load(loader, gitdir, NULL);
	
	g_idle_add(handle_no_gitdir, NULL);
	gtk_main();
	
	g_free(gitdir);
	
	return 0;
}
