#include <gdk/gdkkeysyms.h>
#include <string.h>
#include <stdlib.h>
#include <glib/gi18n.h>

#include "sexy-icon-entry.h"
#include "config.h"

#include "gitg-ref.h"
#include "gitg-utils.h"
#include "gitg-runner.h"
#include "gitg-window.h"
#include "gitg-revision-view.h"
#include "gitg-revision-tree-view.h"
#include "gitg-cell-renderer-path.h"
#include "gitg-commit-view.h"

#define GITG_WINDOW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_WINDOW, GitgWindowPrivate))

struct _GitgWindowPrivate
{
	GitgRepository *repository;

	GtkListStore *branches_store;

	/* Widget placeholders */
	GtkNotebook *notebook_main;
	GtkTreeView *tree_view;
	GtkStatusbar *statusbar;
	GitgRevisionView *revision_view;
	GitgRevisionTreeView *revision_tree_view;
	GitgCommitView *commit_view;
	GtkWidget *search_popup;
	GtkComboBox *combo_branches;
	
	GtkActionGroup *edit_group;
	GtkWidget *open_dialog;
};

static void gitg_window_buildable_iface_init(GtkBuildableIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgWindow, gitg_window, GTK_TYPE_WINDOW, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, gitg_window_buildable_iface_init));

static GtkBuildableIface parent_iface;
static GtkWindowClass *parent_class = NULL;

static void
gitg_window_finalize(GObject *object)
{
	//GitgWindow *self = GITG_WINDOW(object);
	
	G_OBJECT_CLASS(gitg_window_parent_class)->finalize(object);
}

static void
on_selection_changed(GtkTreeSelection *selection, GitgWindow *window)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	GitgRevision *revision = NULL;
	
	if (gtk_tree_selection_get_selected(selection, &model, &iter))
		gtk_tree_model_get(GTK_TREE_MODEL(model), &iter, 0, &revision, -1);
	
	gitg_revision_view_update(window->priv->revision_view, window->priv->repository, revision);
	gitg_revision_tree_view_update(window->priv->revision_tree_view, window->priv->repository, revision);
}

static void
on_search_icon_pressed(SexyIconEntry *entry, SexyIconEntryPosition icon_pos, int button, GitgWindow *window)
{
	gtk_menu_popup(GTK_MENU(window->priv->search_popup), NULL, NULL, NULL, NULL, button, gtk_get_current_event_time());
}

void
search_column_activate(GtkAction *action, gint column, GtkTreeView *tree_view)
{
	if (!gtk_toggle_action_get_active(GTK_TOGGLE_ACTION(action)))
		return;

	gtk_tree_view_set_search_column(tree_view, column);
}

void
on_subject_activate(GtkAction *action, GitgWindow *window)
{
	search_column_activate(action, 1, window->priv->tree_view);
}

void
on_author_activate(GtkAction *action, GitgWindow *window)
{
	search_column_activate(action, 2, window->priv->tree_view);
}

void
on_date_activate(GtkAction *action, GitgWindow *window)
{
	search_column_activate(action, 3, window->priv->tree_view);
}

void
on_hash_activate(GtkAction *action, GitgWindow *window)
{
	search_column_activate(action, 4, window->priv->tree_view);
}

static gboolean
search_hash_equal_func(GtkTreeModel *model, gchar const *key, GtkTreeIter *iter)
{
	GitgRevision *rv;
	gtk_tree_model_get(model, iter, 0, &rv, -1);
	
	gchar *sha = gitg_revision_get_sha1(rv);
	
	gboolean ret = strncmp(sha, key, strlen(key)) != 0;
	
	g_free(sha);
	gitg_revision_unref(rv);
	
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
build_search_entry(GitgWindow *window, GtkBuilder *builder)
{
	GtkWidget *box = GTK_WIDGET(gtk_builder_get_object(builder, "hbox_top"));
	GtkWidget *entry = sexy_icon_entry_new();
	
	GtkImage *image = GTK_IMAGE(gtk_image_new_from_stock(GTK_STOCK_FIND, GTK_ICON_SIZE_MENU));
	sexy_icon_entry_set_icon(SEXY_ICON_ENTRY(entry), SEXY_ICON_ENTRY_PRIMARY, image);
	
	gtk_tree_view_set_search_entry(window->priv->tree_view, GTK_ENTRY(entry));
	gtk_widget_show(entry);
	gtk_box_pack_end(GTK_BOX(box), entry, FALSE, FALSE, 0);
	
	GtkBuilder *b = gtk_builder_new();
	gtk_builder_set_translation_domain(b, GETTEXT_PACKAGE);
	GError *error = NULL;

	if (!gtk_builder_add_from_file(b, GITG_UI_DIR "/gitg-menus.xml", &error))
	{
		g_critical("Could not open UI file: %s (%s)", GITG_UI_DIR "/gitg-menus.xml", error->message);
		g_error_free(error);
		exit(1);
	}
	
	GtkUIManager *manager = GTK_UI_MANAGER(gtk_builder_get_object(b, "uiman"));
	window->priv->search_popup = GTK_WIDGET(g_object_ref(gtk_ui_manager_get_widget(manager, "/ui/search_popup")));
	
	gtk_builder_connect_signals(b, window);
	g_object_unref(b);
	
	g_signal_connect(entry, "icon-pressed", G_CALLBACK(on_search_icon_pressed), window);
	gtk_tree_view_set_search_column(window->priv->tree_view, 1);
	
	gtk_tree_view_set_search_equal_func(window->priv->tree_view, search_equal_func, window, NULL);
	
	GtkAccelGroup *group = gtk_accel_group_new();
	
	GClosure *closure = g_cclosure_new(G_CALLBACK(focus_search), entry, NULL); 
	gtk_accel_group_connect(group, GDK_f, GDK_CONTROL_MASK, 0, closure); 
	gtk_window_add_accel_group(GTK_WINDOW(window), group);
}

static void
on_parent_activated(GitgRevisionView *view, gchar *hash, GitgWindow *window)
{
	GtkTreeIter iter;
	
	if (!gitg_repository_find_by_hash(window->priv->repository, hash, &iter))
		return;
	
	gtk_tree_selection_select_iter(gtk_tree_view_get_selection(window->priv->tree_view), &iter);
	GtkTreePath *path;
	
	path = gtk_tree_model_get_path(GTK_TREE_MODEL(window->priv->repository), &iter);
	
	gtk_tree_view_scroll_to_cell(window->priv->tree_view, path, NULL, FALSE, 0, 0);
	gtk_tree_path_free(path);
}

static void
on_renderer_path(GtkTreeViewColumn *column, GitgCellRendererPath *renderer, GtkTreeModel *model, GtkTreeIter *iter, GitgWindow *window)
{
	GitgRevision *rv;
	
	gtk_tree_model_get(model, iter, 0, &rv, -1);
	GtkTreeIter iter1 = *iter;
	
	GSList *next_lanes = NULL;
	
	if (gtk_tree_model_iter_next(model, &iter1))
	{
		GitgRevision *next;
		gtk_tree_model_get(model, &iter1, 0, &next, -1);
		
		next_lanes = gitg_revision_get_lanes(next);
		gitg_revision_unref(next);
	}
	
	GSList *labels = gitg_repository_get_refs_for_hash(GITG_REPOSITORY(model), gitg_revision_get_hash(rv));

	g_object_set(renderer, "lane", gitg_revision_get_mylane(rv), "lanes", gitg_revision_get_lanes(rv), "next_lanes", next_lanes, "labels", labels, NULL);
	
	gitg_revision_unref(rv);
}

static gboolean
branches_separator_func(GtkTreeModel *model, GtkTreeIter *iter, gpointer data)
{
	gchar *t;
	
	gtk_tree_model_get(model, iter, 0, &t, -1);
	gboolean ret = t == NULL;
	
	g_free(t);
	return ret;
}

static void
on_branches_combo_changed(GtkComboBox *combo, GitgWindow *window)
{
	if (gtk_combo_box_get_active(combo) < 2)
		return;
	
	gchar *name;
	GtkTreeIter iter;
	
	gtk_combo_box_get_active_iter(combo, &iter);
	gtk_tree_model_get(gtk_combo_box_get_model(combo), &iter, 0, &name, -1);
	
	gitg_repository_load(window->priv->repository, 1, (gchar const **)&name, NULL);
	
	g_free(name);
}

static void
build_branches_combo(GitgWindow *window, GtkBuilder *builder)
{
	GtkComboBox *combo = GTK_COMBO_BOX(gtk_builder_get_object(builder, "combo_box_branches"));
	window->priv->branches_store = gtk_list_store_new(1, G_TYPE_STRING);
	window->priv->combo_branches = combo;

	GtkTreeIter iter;
	gtk_list_store_append(window->priv->branches_store, &iter);
	gtk_list_store_set(window->priv->branches_store, &iter, 0, _("Select branch"), -1);
	
	gtk_combo_box_set_model(combo, GTK_TREE_MODEL(window->priv->branches_store));
	gtk_combo_box_set_active(combo, 0);
	
	gtk_combo_box_set_row_separator_func(combo, branches_separator_func, window, NULL);
	
	g_signal_connect(combo, "changed", G_CALLBACK(on_branches_combo_changed), window);
}

static void
gitg_window_parser_finished(GtkBuildable *buildable, GtkBuilder *builder)
{
	if (parent_iface.parser_finished)
		parent_iface.parser_finished(buildable, builder);

	// Store widgets
	GitgWindow *window = GITG_WINDOW(buildable);
	
	window->priv->notebook_main = GTK_NOTEBOOK(gtk_builder_get_object(builder, "notebook_main"));
	window->priv->tree_view = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_rv"));
	window->priv->statusbar = GTK_STATUSBAR(gtk_builder_get_object(builder, "statusbar"));
	window->priv->revision_view = GITG_REVISION_VIEW(gtk_builder_get_object(builder, "revision_view"));
	window->priv->revision_tree_view = GITG_REVISION_TREE_VIEW(gtk_builder_get_object(builder, "revision_tree_view"));
	window->priv->commit_view = GITG_COMMIT_VIEW(gtk_builder_get_object(builder, "hpaned_commit"));

	window->priv->edit_group = GTK_ACTION_GROUP(gtk_builder_get_object(builder, "action_group_menu_edit"));

	GtkTreeViewColumn *col = GTK_TREE_VIEW_COLUMN(gtk_builder_get_object(builder, "rv_column_subject"));
	gtk_tree_view_column_set_cell_data_func(col, GTK_CELL_RENDERER(gtk_builder_get_object(builder, "rv_renderer_subject")), (GtkTreeCellDataFunc)on_renderer_path, window, NULL);
	
	// Intialize branches
	build_branches_combo(window, builder);

	// Create search entry
	build_search_entry(window, builder);
	
	gtk_builder_connect_signals(builder, window);

	// Connect signals
	GtkTreeSelection *selection = gtk_tree_view_get_selection(window->priv->tree_view);
	g_signal_connect(selection, "changed", G_CALLBACK(on_selection_changed), window);
	g_signal_connect(window->priv->revision_view, "parent-activated", G_CALLBACK(on_parent_activated), window);
}

static void
gitg_window_buildable_iface_init(GtkBuildableIface *iface)
{
	parent_iface = *iface;
	
	iface->parser_finished = gitg_window_parser_finished;
}

static void
gitg_window_destroy(GtkObject *object)
{
	gtk_tree_view_set_model(GITG_WINDOW(object)->priv->tree_view, NULL);

	if (GTK_OBJECT_CLASS(parent_class)->destroy)
		GTK_OBJECT_CLASS(parent_class)->destroy(object);
}

static void
gitg_window_class_init(GitgWindowClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkObjectClass *gtkobject_class = GTK_OBJECT_CLASS(klass);
	
	parent_class = g_type_class_peek_parent(klass);
		
	object_class->finalize = gitg_window_finalize;
	gtkobject_class->destroy = gitg_window_destroy;
	
	g_type_class_add_private(object_class, sizeof(GitgWindowPrivate));
}

static void
gitg_window_init(GitgWindow *self)
{
	self->priv = GITG_WINDOW_GET_PRIVATE(self);
}

static void
on_begin_loading(GitgRunner *loader, GitgWindow *window)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(window->priv->tree_view)->window, cursor);
	gdk_cursor_unref(cursor);

	gtk_statusbar_push(window->priv->statusbar, 0, _("Begin loading repository"));
}

static void
on_end_loading(GitgRunner *loader, GitgWindow *window)
{
	gchar *msg = g_strdup_printf(_("Loaded %d revisions"), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(window->priv->repository), NULL));

	gtk_statusbar_push(window->priv->statusbar, 0, msg);
	
	g_free(msg);
	gdk_window_set_cursor(GTK_WIDGET(window->priv->tree_view)->window, NULL);
}

static void
on_update(GitgRunner *loader, gchar **revisions, GitgWindow *window)
{
	gchar *msg = g_strdup_printf(_("Loading %d revisions..."), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(window->priv->repository), NULL));

	gtk_statusbar_push(window->priv->statusbar, 0, msg);
	g_free(msg);
}

static void
handle_no_gitdir(GitgWindow *window)
{
	GtkWidget *dlg = gtk_message_dialog_new(GTK_WINDOW(window), GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, _("Could not find git repository"));
	
	gtk_dialog_run(GTK_DIALOG(dlg));
	gtk_widget_destroy(dlg);
}

static gboolean
create_repository(GitgWindow *window, gchar const *path, gboolean usewd)
{
	gboolean ret = TRUE;

	if (path)
	{
		gchar realp[PATH_MAX];
		
		if (realpath(path, realp))
		{
			window->priv->repository = gitg_repository_new(realp);
		
			if (!gitg_repository_get_path(window->priv->repository))
			{
				// Try current directory
				path = NULL;
				g_object_unref(window->priv->repository);
				window->priv->repository = NULL;
			
				ret = FALSE;
			}
		}
		else
		{
			path = NULL;
		}
	}
	
	if (!path && usewd)
	{
		gchar *curdir = g_get_current_dir();
		window->priv->repository = gitg_repository_new(curdir);
		g_free(curdir);
	}
	
	return ret;	
}

static int
sort_by_ref_type(GitgRef const *a, GitgRef const *b)
{
	if (a->type == b->type)
	{
		if (g_ascii_strcasecmp(a->shortname, "master") == 0)
			return -1;
		else if (g_ascii_strcasecmp(b->shortname, "master") == 0)
			return 1;
		else
			return g_ascii_strcasecmp(a->shortname, b->shortname);
	}
	else
	{
		return a->type - b->type;
	}
}

static void
fill_branches_combo(GitgWindow *window)
{
	GtkTreeIter iter;	
	if (gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(window->priv->branches_store), &iter, NULL, 1))
	{
		while (gtk_list_store_remove(window->priv->branches_store, &iter))
		;
	}
	
	gtk_combo_box_set_active(window->priv->combo_branches, 0);
	
	if (!window->priv->repository)
		return;

	GSList *refs = gitg_repository_get_refs(window->priv->repository);
	
	refs = g_slist_sort(refs, (GCompareFunc)sort_by_ref_type);
	GSList *item;
	GitgRefType prevtype = GITG_REF_TYPE_NONE;

	for (item = refs; item; item = item->next)
	{
		GitgRef *ref = (GitgRef *)item->data;
		
		if (!(ref->type == GITG_REF_TYPE_REMOTE || 
			  ref->type == GITG_REF_TYPE_BRANCH))
			continue;

		GtkTreeIter iter;
		
		if (ref->type != prevtype)
		{
			gtk_list_store_append(window->priv->branches_store, &iter);
			gtk_list_store_set(window->priv->branches_store, &iter, 0, NULL, -1);
			
			prevtype = ref->type;
		}

		gtk_list_store_append(window->priv->branches_store, &iter);
		gtk_list_store_set(window->priv->branches_store, &iter, 0, ref->shortname, -1);
	}
	
	g_slist_foreach(refs, (GFunc)gitg_ref_free, NULL);
	g_slist_free(refs);
}

static void
on_repository_load(GitgRepository *repository, GitgWindow *window)
{
	fill_branches_combo(window);
}

static void
load_repository(GitgWindow *window, gchar const *path, gint argc, gchar const **argv, gboolean usewd)
{
	if (window->priv->repository)
	{
		gtk_tree_view_set_model(window->priv->tree_view, NULL);
		g_signal_handlers_disconnect_by_func(window->priv->repository, G_CALLBACK(on_repository_load), window);

		g_object_unref(window->priv->repository);
		window->priv->repository = NULL;
	}
	
	gboolean haspath = create_repository(window, path, usewd); 

	if (window->priv->repository && gitg_repository_get_path(window->priv->repository))
	{
		gtk_tree_view_set_model(window->priv->tree_view, GTK_TREE_MODEL(window->priv->repository));
		GitgRunner *loader = gitg_repository_get_loader(window->priv->repository);
	
		g_signal_connect(loader, "begin-loading", G_CALLBACK(on_begin_loading), window);
		g_signal_connect(loader, "end-loading", G_CALLBACK(on_end_loading), window);
		g_signal_connect(loader, "update", G_CALLBACK(on_update), window);
		
		g_object_unref(loader);
		
		gchar const **ar = argv;

		if (!haspath && path)
		{
			ar = (gchar const **)g_new(gchar *, ++argc);
			
			int i;
			for (i = 0; i < argc - 1; ++i)
				ar[i] = argv[i];

			ar[argc - 1] = path;
		}

		g_signal_connect(window->priv->repository, "load", G_CALLBACK(on_repository_load), window);
		gitg_repository_load(window->priv->repository, argc, ar, NULL);
		
		if (!haspath && argc)
			g_free(ar);

		gitg_commit_view_set_repository(window->priv->commit_view, window->priv->repository);
	}
	else
	{
		fill_branches_combo(window);
		gitg_commit_view_set_repository(window->priv->commit_view, window->priv->repository);

		handle_no_gitdir(window);
	}
}

void
gitg_window_load_repository(GitgWindow *window, gchar const *path, gint argc, gchar const **argv)
{
	g_return_if_fail(GITG_IS_WINDOW(window));
	
	load_repository(window, path, argc, argv, TRUE);
}

void
gitg_window_show_commit(GitgWindow *window)
{
	g_return_if_fail(GITG_IS_WINDOW(window));
	
	gtk_notebook_set_current_page(window->priv->notebook_main, 1);
}

void
on_file_quit(GtkAction *action, GitgWindow *window)
{
	gtk_main_quit();
}

static void
on_open_dialog_response(GtkFileChooser *dialog, gint response, GitgWindow *window)
{
	if (response != GTK_RESPONSE_ACCEPT)
	{
		gtk_widget_destroy(GTK_WIDGET(dialog));
		return;
	}
	
	gchar *uri = gtk_file_chooser_get_uri(dialog);
	GFile *file = g_file_new_for_uri(uri);
	gchar *path = g_file_get_path(file);
	
	g_free(uri);
	g_object_unref(file);	
	gtk_widget_destroy(GTK_WIDGET(dialog));
	
	load_repository(window, path, 0, NULL, FALSE);
	g_free(path);
}

void
on_file_open(GtkAction *action, GitgWindow *window)
{
	if (window->priv->open_dialog)
	{
		gtk_window_present(GTK_WINDOW(window->priv->open_dialog));
		return;
	}
	
	window->priv->open_dialog = gtk_file_chooser_dialog_new(_("Open git repository"),
															GTK_WINDOW(window),
															GTK_FILE_CHOOSER_ACTION_SELECT_FOLDER,
															GTK_STOCK_CANCEL,
															GTK_RESPONSE_CANCEL,
															GTK_STOCK_OPEN,
															GTK_RESPONSE_ACCEPT,
															NULL);

	gtk_file_chooser_set_local_only(GTK_FILE_CHOOSER(window->priv->open_dialog), TRUE);
	g_object_add_weak_pointer(G_OBJECT(window->priv->open_dialog), (gpointer *)&(window->priv->open_dialog));
	gtk_window_present(GTK_WINDOW(window->priv->open_dialog));
	
	g_signal_connect(window->priv->open_dialog, "response", G_CALLBACK(on_open_dialog_response), window);
}

void
on_edit_copy(GtkAction *action, GitgWindow *window)
{
	GtkWidget *focus = gtk_window_get_focus(GTK_WINDOW(window));

	g_message("ciopy");
	g_signal_emit_by_name(focus, "copy-clipboard", 0);
}

void
on_edit_cut(GtkAction *action, GitgWindow *window)
{

}

void
on_edit_paste(GtkAction *action, GitgWindow *window)
{

}

void
on_window_set_focus(GitgWindow *window, GtkWidget *widget)
{
	if (widget == NULL)
		return;

	gboolean cancopy = g_signal_lookup("copy-clipboard", G_OBJECT_TYPE(widget)) != 0;
	gboolean selection = FALSE;
	gboolean editable = FALSE;
	
	if (GTK_IS_EDITABLE(widget))
	{
		selection = gtk_editable_get_selection_bounds(GTK_EDITABLE(widget), NULL, NULL);
		editable = gtk_editable_get_editable(GTK_EDITABLE(widget));
		cancopy = cancopy && selection;
	}

	gtk_action_set_sensitive(gtk_action_group_get_action(window->priv->edit_group, "EditPasteAction"), editable);
	gtk_action_set_sensitive(gtk_action_group_get_action(window->priv->edit_group, "EditCutAction"), editable && selection);
	gtk_action_set_sensitive(gtk_action_group_get_action(window->priv->edit_group, "EditCopyAction"), cancopy);
}
