/*
 * gitg-window.c
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

#include <gdk/gdkkeysyms.h>
#include <string.h>
#include <stdlib.h>
#include <glib/gi18n.h>

#include "sexy-icon-entry.h"
#include "config.h"

#include "gitg-dirs.h"
#include "gitg-ref.h"
#include "gitg-utils.h"
#include "gitg-runner.h"
#include "gitg-window.h"
#include "gitg-revision-view.h"
#include "gitg-revision-tree-view.h"
#include "gitg-cell-renderer-path.h"
#include "gitg-commit-view.h"
#include "gitg-settings.h"
#include "gitg-preferences-dialog.h"
#include "gitg-repository-dialog.h"
#include "gitg-dnd.h"
#include "gitg-branch-actions.h"
#include "gitg-preferences.h"

#define DYNAMIC_ACTION_DATA_KEY "GitgDynamicActionDataKey"

#define GITG_WINDOW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_WINDOW, GitgWindowPrivate))

enum
{
	COLUMN_BRANCHES_NAME,
	COLUMN_BRANCHES_REF,
	COLUMN_BRANCHES_ICON
};

struct _GitgWindowPrivate
{
	GitgRepository *repository;

	GtkTreeStore *branches_store;

	/* Widget placeholders */
	GtkNotebook *notebook_main;
	GtkTreeView *tree_view;
	GtkStatusbar *statusbar;
	GitgRevisionView *revision_view;
	GitgRevisionTreeView *revision_tree_view;
	GitgCommitView *commit_view;
	GtkWidget *search_popup;
	GtkComboBox *combo_branches;
	
	GtkUIManager *menus_ui_manager;
	
	GtkWidget *vpaned_main;
	GtkWidget *hpaned_commit1;
	GtkWidget *hpaned_commit2;
	GtkWidget *vpaned_commit;
	
	GtkActionGroup *edit_group;
	GtkWidget *open_dialog;

	GitgCellRendererPath *renderer_path;
	
	GTimer *load_timer;
	GdkCursor *hand;
	
	gboolean destroy_has_run;
	guint merge_rebase_uid;
	GtkActionGroup *merge_rebase_action_group;
	GitgRef *popup_refs[2];
	
	GList *branch_actions;
};

static gboolean on_tree_view_motion(GtkTreeView *treeview, GdkEventMotion *event, GitgWindow *window);
static gboolean on_tree_view_button_release(GtkTreeView *treeview, GdkEventButton *event, GitgWindow *window);

static void gitg_window_buildable_iface_init(GtkBuildableIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgWindow, gitg_window, GTK_TYPE_WINDOW, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, gitg_window_buildable_iface_init));

static GtkBuildableIface parent_iface;
static GtkWindowClass *parent_class = NULL;

static void
on_branch_action_runner_end (GitgRunner *runner, gboolean cancelled, GitgWindow *window)
{
	window->priv->branch_actions = g_list_remove (window->priv->branch_actions, runner);
	g_object_unref (runner);
}

static gboolean
add_branch_action (GitgWindow *window, GitgRunner *runner)
{
	if (runner != NULL && gitg_runner_running (runner))
	{
		window->priv->branch_actions = g_list_prepend (window->priv->branch_actions, runner);
		
		g_signal_connect (runner, "end-loading", G_CALLBACK (on_branch_action_runner_end), window);
	}
	else if (runner)
	{
		g_object_unref (runner);
		runner = NULL;
	}
	
	return runner != NULL;
}

static void
gitg_window_finalize(GObject *object)
{
	GitgWindow *self = GITG_WINDOW(object);
	
	g_timer_destroy(self->priv->load_timer);
	gdk_cursor_unref(self->priv->hand);
	
	GList *copy = g_list_copy (self->priv->branch_actions);
	GList *item;
	
	for (item = copy; item; item = g_list_next (item))
	{
		gitg_runner_cancel (GITG_RUNNER (item->data));
	}
	
	g_list_free (copy);

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

	window->priv->search_popup = GTK_WIDGET(g_object_ref(gtk_ui_manager_get_widget(window->priv->menus_ui_manager, "/ui/search_popup")));
	
	g_signal_connect(entry, "icon-pressed", G_CALLBACK(on_search_icon_pressed), window);
	gtk_tree_view_set_search_column(window->priv->tree_view, 1);
	
	gtk_tree_view_set_search_equal_func(window->priv->tree_view, search_equal_func, window, NULL);
	
	GtkAccelGroup *group = gtk_accel_group_new();
	
	GClosure *closure = g_cclosure_new(G_CALLBACK(focus_search), entry, NULL); 
	gtk_accel_group_connect(group, GDK_f, GDK_CONTROL_MASK, 0, closure); 
	gtk_window_add_accel_group(GTK_WINDOW(window), group);
}

static void
goto_hash(GitgWindow *window, gchar const *hash)
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
on_parent_activated(GitgRevisionView *view, gchar *hash, GitgWindow *window)
{
	goto_hash(window, hash);
}

static void
on_renderer_path(GtkTreeViewColumn *column, GitgCellRendererPath *renderer, GtkTreeModel *model, GtkTreeIter *iter, GitgWindow *window)
{
	GitgRevision *rv;
	
	gtk_tree_model_get(model, iter, 0, &rv, -1);
	GtkTreeIter iter1 = *iter;
	
	GitgRevision *next_revision = NULL;
	
	if (gtk_tree_model_iter_next(model, &iter1))
		gtk_tree_model_get(model, &iter1, 0, &next_revision, -1);
	
	GSList *labels;
	const gchar *lbl = NULL;

	switch (gitg_revision_get_sign(rv))
	{
		case 't':
			lbl = "staged";
		break;
		case 'u':
			lbl = "unstaged";
		break;
		default:
		break;
	}
	
	if (lbl != NULL)
	{
		g_object_set(renderer, "style", PANGO_STYLE_ITALIC, NULL);
		labels = g_slist_append(NULL, gitg_ref_new(gitg_revision_get_hash(rv), lbl));
	}
	else
	{
		g_object_set(renderer, "style", PANGO_STYLE_NORMAL, NULL);
		labels = gitg_repository_get_refs_for_hash(GITG_REPOSITORY(model), gitg_revision_get_hash(rv));
	}

	g_object_set(renderer, 
	             "revision", rv, 
	             "next_revision", next_revision, 
	             "labels", labels,
	             NULL);

	gitg_revision_unref(next_revision);
	gitg_revision_unref(rv);
}

static gboolean
branches_separator_func(GtkTreeModel *model, GtkTreeIter *iter, gpointer data)
{
	gchar *name;
	GitgRef *ref;
	
	gtk_tree_model_get(model, 
	                   iter, 
	                   COLUMN_BRANCHES_NAME, &name, 
	                   COLUMN_BRANCHES_REF, &ref,
	                   -1);

	gboolean ret = (name == NULL && ref == NULL);
	
	g_free(name);
	gitg_ref_free(ref);

	return ret;
}

static void
on_branches_combo_changed(GtkComboBox *combo, GitgWindow *window)
{
	if (gtk_combo_box_get_active(combo) < 2)
		return;
	
	gchar *name;
	GtkTreeIter iter;
	GtkTreeIter next;
	
	gtk_combo_box_get_active_iter(combo, &iter);
	next = iter;
	
	if (!gtk_tree_model_iter_next(gtk_combo_box_get_model(combo), &next))
	{
		name = g_strdup("--all");
	}
	else
	{
		GitgRef *ref;
		
		gtk_tree_model_get(gtk_combo_box_get_model(combo), 
		                   &iter, 
		                   COLUMN_BRANCHES_REF, &ref, 
		                   -1);
		
		if (ref == NULL)
		{
			return;
		}
		
		name = g_strdup(gitg_ref_get_name(ref));
		gitg_ref_free(ref);
	}

	gitg_repository_load(window->priv->repository, 1, (gchar const **)&name, NULL);
	g_free(name);
}

static void
build_branches_combo(GitgWindow *window, GtkBuilder *builder)
{
	GtkComboBox *combo = GTK_COMBO_BOX(gtk_builder_get_object(builder, "combo_box_branches"));
	window->priv->branches_store = gtk_tree_store_new(3, G_TYPE_STRING, GITG_TYPE_REF, G_TYPE_STRING);
	window->priv->combo_branches = combo;

	GtkTreeIter iter;
	gtk_tree_store_append(window->priv->branches_store, &iter, NULL);
	gtk_tree_store_set(window->priv->branches_store, 
	                   &iter, 
	                   COLUMN_BRANCHES_NAME, _("Select branch"),
	                   COLUMN_BRANCHES_REF, NULL, 
	                   -1);
	
	gtk_combo_box_set_model(combo, GTK_TREE_MODEL(window->priv->branches_store));
	gtk_combo_box_set_active(combo, 0);
	
	gtk_combo_box_set_row_separator_func(combo, branches_separator_func, window, NULL);
	
	g_signal_connect(combo, "changed", G_CALLBACK(on_branches_combo_changed), window);
}

static void
restore_state(GitgWindow *window)
{
	GitgSettings *settings = gitg_settings_get_default();
	gint dw;
	gint dh;

	gtk_window_get_default_size(GTK_WINDOW(window), &dw, &dh);
	
	gtk_window_set_default_size(GTK_WINDOW(window), 
							    gitg_settings_get_window_width(settings, dw), 
							    gitg_settings_get_window_height(settings, dh));
	
	gitg_utils_restore_pane_position (GTK_PANED(window->priv->vpaned_main),
	                                  gitg_settings_get_vpaned_main_position(settings, -1),
	                                  FALSE);

	gitg_utils_restore_pane_position (GTK_PANED(window->priv->vpaned_commit),
	                                  gitg_settings_get_vpaned_commit_position(settings, -1),
	                                  FALSE);

	gitg_utils_restore_pane_position (GTK_PANED(window->priv->hpaned_commit1),
	                                  gitg_settings_get_hpaned_commit1_position(settings, 200),
	                                  FALSE);

	gitg_utils_restore_pane_position (GTK_PANED(window->priv->hpaned_commit2),
	                                  gitg_settings_get_hpaned_commit2_position(settings, 200),
	                                  TRUE);

	gitg_utils_restore_pane_position (GTK_PANED(window->priv->revision_tree_view),
	                                  gitg_settings_get_revision_tree_view_position(settings, -1),
	                                  FALSE);
}

static void
update_dnd_status (GitgWindow *window, GitgRef *source, GitgRef *dest)
{
	if (!dest)
	{
		gtk_statusbar_push (window->priv->statusbar, 0, "");
	}
	else
	{
		gchar *message = NULL;
		GitgRefType source_type = gitg_ref_get_ref_type (source);
		GitgRefType dest_type = gitg_ref_get_ref_type (dest);
		
		if (source_type == GITG_REF_TYPE_BRANCH &&
		    dest_type== GITG_REF_TYPE_REMOTE)
		{
			message = g_strdup_printf (_("Push local branch <%s> to remote branch <%s>"), 
			                           gitg_ref_get_shortname (source),
			                           gitg_ref_get_shortname (dest));
		}
		else if (source_type == GITG_REF_TYPE_BRANCH &&
		         dest_type == GITG_REF_TYPE_BRANCH)
		{
			message = g_strdup_printf (_("Merge/rebase local branch <%s> with/on local branch <%s>"), 
			                           gitg_ref_get_shortname (source), 
			                           gitg_ref_get_shortname (dest));
		}
		else if (source_type == GITG_REF_TYPE_REMOTE &&
		         dest_type == GITG_REF_TYPE_BRANCH)
		{
			message = g_strdup_printf (_("Merge/rebase local branch <%s> with/on remote branch <%s>"), 
			                           gitg_ref_get_shortname (dest), 
			                           gitg_ref_get_shortname (source));
		}
		else if (source_type == GITG_REF_TYPE_STASH && 
		         dest_type == GITG_REF_TYPE_BRANCH)
		{
			message = g_strdup_printf (_("Apply stash to local branch <%s>"),
			                           gitg_ref_get_shortname (dest));
		}
		
		if (message)
		{
			gtk_statusbar_push (window->priv->statusbar, 0, message);
		}
		
		g_free (message);
	}
}

static gboolean
on_refs_dnd (GitgRef *source, GitgRef *dest, gboolean dropped, GitgWindow *window)
{
	if (!dropped)
	{
		update_dnd_status (window, source, dest);
		return FALSE;
	}

	gboolean ret = FALSE;
	GitgRefType source_type = gitg_ref_get_ref_type (source);
	GitgRefType dest_type = gitg_ref_get_ref_type (dest);

	if (source_type == GITG_REF_TYPE_BRANCH &&
	    dest_type == GITG_REF_TYPE_REMOTE)
	{
		ret = add_branch_action (window, gitg_branch_actions_push (window, source, dest));
	}
	else if (source_type == GITG_REF_TYPE_STASH)
	{
		if (dest_type == GITG_REF_TYPE_BRANCH)
		{
			ret = gitg_branch_actions_apply_stash (window, source, dest);
		}
	}
	else if (dest_type == GITG_REF_TYPE_BRANCH)
	{
		GtkWidget *popup = gtk_ui_manager_get_widget (window->priv->menus_ui_manager,
	                                                  "/ui/dnd_popup");

		window->priv->popup_refs[0] = source;
		window->priv->popup_refs[1] = dest;

		gtk_menu_popup (GTK_MENU (popup), NULL, NULL, NULL, NULL, 1, gtk_get_current_event_time());
	}

	gtk_statusbar_push (window->priv->statusbar, 0, "");
	return ret;
}

static void
init_tree_view (GitgWindow *window, GtkBuilder *builder)
{
	GtkTreeViewColumn *col = GTK_TREE_VIEW_COLUMN(gtk_builder_get_object(builder, "rv_column_subject"));
	
	window->priv->renderer_path = GITG_CELL_RENDERER_PATH(gtk_builder_get_object(builder, "rv_renderer_subject"));

	gtk_tree_view_column_set_cell_data_func(col, GTK_CELL_RENDERER(window->priv->renderer_path), (GtkTreeCellDataFunc)on_renderer_path, window, NULL);
	
	gitg_dnd_enable (window->priv->tree_view, (GitgDndCallback)on_refs_dnd, window);
}

static void
gitg_window_parser_finished(GtkBuildable *buildable, GtkBuilder *builder)
{
	if (parent_iface.parser_finished)
		parent_iface.parser_finished(buildable, builder);

	// Store widgets
	GitgWindow *window = GITG_WINDOW(buildable);
	
	// Insert menu from second ui file
	GtkBuilder *b = gitg_utils_new_builder("gitg-ui.xml");
	GtkUIManager *uiman = GTK_UI_MANAGER (gtk_builder_get_object(b, "uiman"));

	GtkRecentChooser *chooser = GTK_RECENT_CHOOSER(gtk_builder_get_object(b, "RecentOpenAction"));
	GtkRecentFilter *filter = gtk_recent_filter_new();
	gtk_recent_filter_add_group(filter, "gitg");

	gtk_recent_chooser_add_filter(chooser, filter);
	gtk_recent_chooser_set_show_tips(chooser, TRUE);

	GtkWidget *menu = gtk_ui_manager_get_widget (uiman, "/ui/menubar_main");
	GtkWidget *vbox = GTK_WIDGET(gtk_builder_get_object(builder, "vbox_main"));

	gtk_box_pack_start(GTK_BOX(vbox), menu, FALSE, FALSE, 0);
	gtk_box_reorder_child(GTK_BOX(vbox), menu, 0);
	
	gtk_window_add_accel_group (GTK_WINDOW (window), gtk_ui_manager_get_accel_group (uiman));

	window->priv->edit_group = GTK_ACTION_GROUP(gtk_builder_get_object(b, "action_group_menu_edit"));

	gtk_builder_connect_signals(b, window);
	g_object_unref(b);	

	window->priv->vpaned_main = GTK_WIDGET(gtk_builder_get_object(builder, "vpaned_main"));
	window->priv->hpaned_commit1 = GTK_WIDGET(gtk_builder_get_object(builder, "hpaned_commit1"));
	window->priv->hpaned_commit2 = GTK_WIDGET(gtk_builder_get_object(builder, "hpaned_commit2"));
	window->priv->vpaned_commit = GTK_WIDGET(gtk_builder_get_object(builder, "vpaned_commit"));
	
	window->priv->notebook_main = GTK_NOTEBOOK(gtk_builder_get_object(builder, "notebook_main"));
	window->priv->tree_view = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_rv"));
	window->priv->statusbar = GTK_STATUSBAR(gtk_builder_get_object(builder, "statusbar"));
	window->priv->revision_view = GITG_REVISION_VIEW(gtk_builder_get_object(builder, "revision_view"));
	window->priv->revision_tree_view = GITG_REVISION_TREE_VIEW(gtk_builder_get_object(builder, "revision_tree_view"));
	window->priv->commit_view = GITG_COMMIT_VIEW(gtk_builder_get_object(builder, "vpaned_commit"));

	restore_state(window);
	
	init_tree_view (window, builder);
	
	// Intialize branches
	build_branches_combo(window, builder);

	// Get menus ui
	b = gitg_utils_new_builder("gitg-menus.xml");
	window->priv->menus_ui_manager = GTK_UI_MANAGER(g_object_ref(gtk_builder_get_object(b, "uiman")));

	gtk_builder_connect_signals (b, window);
	g_object_unref (b);

	// Create search entry
	build_search_entry(window, builder);
	
	gtk_builder_connect_signals(builder, window);

	// Connect signals
	GtkTreeSelection *selection = gtk_tree_view_get_selection(window->priv->tree_view);
	g_signal_connect(selection, "changed", G_CALLBACK(on_selection_changed), window);
	g_signal_connect(window->priv->revision_view, "parent-activated", G_CALLBACK(on_parent_activated), window);
	
	g_signal_connect(window->priv->tree_view, "motion-notify-event", G_CALLBACK(on_tree_view_motion), window);
	g_signal_connect(window->priv->tree_view, "button-release-event", G_CALLBACK(on_tree_view_button_release), window);
}

static void
gitg_window_buildable_iface_init(GtkBuildableIface *iface)
{
	parent_iface = *iface;
	
	iface->parser_finished = gitg_window_parser_finished;
}

static void
save_state(GitgWindow *window)
{
	GitgSettings *settings = gitg_settings_get_default();
	GtkAllocation *allocation = &(GTK_WIDGET(window)->allocation);
	
	gitg_settings_set_window_width(settings, allocation->width);
	gitg_settings_set_window_height(settings, allocation->height);

	if (GTK_WIDGET_MAPPED (window->priv->vpaned_main))
	{
		gitg_settings_set_vpaned_main_position (settings, 
			                                    gtk_paned_get_position(GTK_PANED(window->priv->vpaned_main)));
	}
	
	if (GTK_WIDGET_MAPPED (window->priv->vpaned_commit))
	{
		gitg_settings_set_vpaned_commit_position (settings, 
			                                      gtk_paned_get_position(GTK_PANED(window->priv->vpaned_commit)));
	}
	
	if (GTK_WIDGET_MAPPED (window->priv->hpaned_commit1))
	{
		gitg_settings_set_hpaned_commit1_position (settings, 
			                                       gtk_paned_get_position(GTK_PANED(window->priv->hpaned_commit1)));
	}
	
	if (GTK_WIDGET_MAPPED (window->priv->hpaned_commit2))
	{
		gitg_settings_set_hpaned_commit2_position (settings, 
			                                       GTK_WIDGET (window->priv->hpaned_commit2)->allocation.width - 
		                                           gtk_paned_get_position(GTK_PANED(window->priv->hpaned_commit2)));
	}

	gitg_settings_set_revision_tree_view_position(settings, gtk_paned_get_position(GTK_PANED(window->priv->revision_tree_view)));

	gitg_settings_save(settings);
}

static gboolean
gitg_window_delete_event (GtkWidget *widget, GdkEventAny *event)
{
	save_state(GITG_WINDOW (widget));
	
	if (GTK_WIDGET_CLASS (parent_class)->delete_event)
	{
		GTK_WIDGET_CLASS (parent_class)->delete_event (widget, event);
	}
	else
	{
		gtk_widget_destroy (widget);
	}
}

static void
gitg_window_destroy(GtkObject *object)
{
	GitgWindow *window = GITG_WINDOW(object);
	
	if (!window->priv->destroy_has_run)
	{
		gtk_tree_view_set_model(window->priv->tree_view, NULL);
		window->priv->destroy_has_run = TRUE;
	}
	
	if (GTK_OBJECT_CLASS(parent_class)->destroy)
		GTK_OBJECT_CLASS(parent_class)->destroy(object);
}

static gboolean
gitg_window_window_state_event(GtkWidget *widget, GdkEventWindowState *event)
{
	GitgWindow *window = GITG_WINDOW(widget);

	if (event->changed_mask &
	    (GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN))
	{
		gboolean show;

		show = !(event->new_window_state &
			(GDK_WINDOW_STATE_MAXIMIZED | GDK_WINDOW_STATE_FULLSCREEN));

		gtk_statusbar_set_has_resize_grip (window->priv->statusbar, show);
	}

	return FALSE;
}

static void
gitg_window_class_init(GitgWindowClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkObjectClass *gtkobject_class = GTK_OBJECT_CLASS(klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);
	
	parent_class = g_type_class_peek_parent(klass);
		
	object_class->finalize = gitg_window_finalize;
	gtkobject_class->destroy = gitg_window_destroy;
	widget_class->delete_event = gitg_window_delete_event;
	
	widget_class->window_state_event = gitg_window_window_state_event;
	
	g_type_class_add_private(object_class, sizeof(GitgWindowPrivate));
}

static void
gitg_window_init(GitgWindow *self)
{
	self->priv = GITG_WINDOW_GET_PRIVATE(self);
	
	self->priv->load_timer = g_timer_new();
	self->priv->hand = gdk_cursor_new(GDK_HAND1);
}

static void
on_begin_loading(GitgRunner *loader, GitgWindow *window)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(window->priv->tree_view)->window, cursor);
	gdk_cursor_unref(cursor);

	gtk_statusbar_push(window->priv->statusbar, 0, _("Begin loading repository"));
	
	g_timer_reset(window->priv->load_timer);
	g_timer_start(window->priv->load_timer);
}

static void
on_end_loading(GitgRunner *loader, gboolean cancelled, GitgWindow *window)
{
	gchar *msg = g_strdup_printf(_("Loaded %d revisions in %.2fs"), gtk_tree_model_iter_n_children(GTK_TREE_MODEL(window->priv->repository), NULL), g_timer_elapsed(window->priv->load_timer, NULL));

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
		GFile *file = g_file_new_for_commandline_arg(path);
		
		if (g_file_is_native(file) && g_file_query_exists(file, NULL))
		{
			gchar *p = g_file_get_path(file);
			window->priv->repository = gitg_repository_new(p);
			g_free(p);
		
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
			ret = FALSE;
			path = NULL;
		}
		
		g_object_unref(file);
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
sort_by_ref_type(GitgRef *a, GitgRef *b)
{
	if (gitg_ref_get_ref_type(a) == gitg_ref_get_ref_type(b))
	{
		if (g_ascii_strcasecmp(gitg_ref_get_shortname(a), "master") == 0)
		{
			return -1;
		}
		else if (g_ascii_strcasecmp(gitg_ref_get_shortname(b), "master") == 0)
		{
			return 1;
		}
		else
		{
			return g_ascii_strcasecmp(gitg_ref_get_shortname(a), gitg_ref_get_shortname(b));
		}
	}
	else
	{
		return gitg_ref_get_ref_type(a) - gitg_ref_get_ref_type(b);
	}
}

static void
clear_branches_combo(GitgWindow *window)
{
	GtkTreeIter iter;	

	if (gtk_tree_model_iter_nth_child(GTK_TREE_MODEL(window->priv->branches_store), &iter, NULL, 1))
	{
		while (gtk_tree_store_remove(window->priv->branches_store, &iter))
		;
	}

	gtk_combo_box_set_active(window->priv->combo_branches, 0);
}

static void
fill_branches_combo(GitgWindow *window)
{
	if (!window->priv->repository)
		return;

	guint children = gtk_tree_model_iter_n_children(GTK_TREE_MODEL(window->priv->branches_store), NULL);
	
	if (children > 1)
		return;

	GSList *refs = gitg_repository_get_refs(window->priv->repository);
	
	refs = g_slist_sort(refs, (GCompareFunc)sort_by_ref_type);
	GSList *item;
	
	GitgRefType prevtype = GITG_REF_TYPE_NONE;
	GtkTreeIter iter;
	GtkTreeIter parent;
	GitgRef *parentref = NULL;
	GtkTreeStore *store = window->priv->branches_store;
	GitgRef *current_ref = gitg_repository_get_current_ref(window->priv->repository);
	gboolean refset = FALSE;
			
	for (item = refs; item; item = item->next)
	{
		GitgRef *ref = (GitgRef *)item->data;
		
		if (!(gitg_ref_get_ref_type(ref) == GITG_REF_TYPE_REMOTE || 
			  gitg_ref_get_ref_type(ref) == GITG_REF_TYPE_BRANCH))
			continue;

		if (gitg_ref_get_ref_type(ref) != prevtype)
		{
			gtk_tree_store_append(store, &iter, NULL);
			gtk_tree_store_set(store, 
			                   &iter, 
			                   COLUMN_BRANCHES_NAME, NULL, 
			                   COLUMN_BRANCHES_REF, NULL,
			                   -1);
			
			prevtype = gitg_ref_get_ref_type(ref);
		}

		if (gitg_ref_get_prefix(ref))
		{
			if (!parentref || !gitg_ref_equal_prefix(parentref, ref))
			{
				parentref = ref;

				gtk_tree_store_append(store, &parent, NULL);
				gtk_tree_store_set(store,
				                   &parent,
				                   COLUMN_BRANCHES_NAME, gitg_ref_get_prefix(ref),
				                   COLUMN_BRANCHES_REF, NULL,
				                   -1);

				if (gitg_ref_get_ref_type(ref) == GITG_REF_TYPE_REMOTE)
				{
					gtk_tree_store_set(store,
					                   &parent,
					                   COLUMN_BRANCHES_ICON, g_strdup(GTK_STOCK_NETWORK),
					                   -1);
				}
			}
			
			gtk_tree_store_append(window->priv->branches_store, &iter, &parent);
		}
		else
		{
			gtk_tree_store_append(window->priv->branches_store, &iter, NULL);
		}

		gtk_tree_store_set(window->priv->branches_store, 
		                   &iter, 
		                   COLUMN_BRANCHES_NAME, gitg_ref_get_shortname(ref), 
		                   COLUMN_BRANCHES_REF, ref, 
		                   -1);
		
		if (!refset && gitg_ref_equal(current_ref, ref))
		{
			gtk_combo_box_set_active_iter(window->priv->combo_branches, &iter);
			refset = TRUE;
		}
	}
	
	gtk_tree_store_append(store, &iter, NULL);
	gtk_tree_store_set(store, 
	                   &iter, 
	                   COLUMN_BRANCHES_NAME, NULL, 
	                   COLUMN_BRANCHES_REF, NULL, -1);

	gtk_tree_store_append(store, &iter, NULL);
	gtk_tree_store_set(store, 
	                   &iter,
	                   COLUMN_BRANCHES_NAME, _("All branches"),
	                   COLUMN_BRANCHES_REF, NULL, 
	                   -1);
	
	if (current_ref == NULL)
	{
		gtk_combo_box_set_active_iter (window->priv->combo_branches, &iter);
	}
	else if (!refset)
	{
		gtk_combo_box_set_active(window->priv->combo_branches, 0);
	}
	
	g_slist_foreach(refs, (GFunc)gitg_ref_free, NULL);
	g_slist_free(refs);
}

static void
update_window_title (GitgWindow *window)
{
	if (!window->priv->repository)
	{
		gtk_window_set_title (GTK_WINDOW (window), _("gitg"));
		return;
	}
	
	GitgRef *ref = gitg_repository_get_current_working_ref (window->priv->repository);
	gchar *refname = NULL;
	
	if (ref)
	{
		refname = g_strconcat (" (", gitg_ref_get_shortname (ref), ")", NULL);
	}
	
	gchar *basename = g_path_get_basename(gitg_repository_get_path(window->priv->repository));
	gchar *title = g_strconcat(_("gitg"), " - ", basename, refname, NULL);
	
	gtk_window_set_title(GTK_WINDOW(window), title);
	
	g_free(basename);
	g_free(title);
	g_free (refname);
}

static void
on_repository_load(GitgRepository *repository, GitgWindow *window)
{
	g_signal_handlers_block_by_func(window->priv->combo_branches, on_branches_combo_changed, window);
	clear_branches_combo(window);
	fill_branches_combo(window);
	g_signal_handlers_unblock_by_func(window->priv->combo_branches, on_branches_combo_changed, window);

	update_window_title (window);
}

static void
add_recent_item(GitgWindow *window)
{
	GtkRecentManager *manager = gtk_recent_manager_get_default();
	GtkRecentData data = { 0 };
	gchar *groups[] = {"gitg", NULL};
	gchar const *path = gitg_repository_get_path(window->priv->repository);
	gchar *basename = g_path_get_basename(path);
	
	data.display_name = basename;
	data.app_name = "gitg";
	data.mime_type = "inode/directory";
	data.app_exec = "gitg %f";
	data.groups = groups;

	GFile *file = g_file_new_for_path(gitg_repository_get_path(window->priv->repository));
	gchar *uri = g_file_get_uri(file);
	gtk_recent_manager_add_full(manager, uri, &data);
	
	g_free(basename);
	g_free(uri);
	g_object_unref(file);
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
		
		gitg_repository_dialog_close ();
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
		clear_branches_combo(window);
		
		gitg_repository_load(window->priv->repository, argc, ar, NULL);
		
		if (!haspath && path)
		{
			g_free(ar);
		}

		gitg_commit_view_set_repository(window->priv->commit_view, window->priv->repository);
		gitg_revision_view_set_repository(window->priv->revision_view, window->priv->repository);
		
		add_recent_item(window);
		gtk_widget_set_sensitive(GTK_WIDGET(window->priv->notebook_main), TRUE);
	}
	else
	{
		clear_branches_combo(window);
		gitg_commit_view_set_repository(window->priv->commit_view, window->priv->repository);
		gitg_revision_view_set_repository(window->priv->revision_view, window->priv->repository);

		if (path || argc > 1)
			handle_no_gitdir(window);

		update_window_title (window);
		gtk_widget_set_sensitive(GTK_WIDGET(window->priv->notebook_main), FALSE);
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

GitgRepository *
gitg_window_get_repository(GitgWindow *window)
{
	g_return_val_if_fail(GITG_IS_WINDOW(window), NULL);
	
	return window->priv->repository;
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

	g_signal_emit_by_name(focus, "copy-clipboard", 0);
}

void
on_edit_cut(GtkAction *action, GitgWindow *window)
{
	GtkWidget *focus = gtk_window_get_focus(GTK_WINDOW(window));

	g_signal_emit_by_name(focus, "cut-clipboard", 0);
}

void
on_edit_paste(GtkAction *action, GitgWindow *window)
{
	GtkWidget *focus = gtk_window_get_focus(GTK_WINDOW(window));

	g_signal_emit_by_name(focus, "paste-clipboard", 0);
}

void
on_view_refresh(GtkAction *action, GitgWindow *window)
{
	if (window->priv->repository && gitg_repository_get_path(window->priv->repository) != NULL)
	{
		gitg_repository_reload(window->priv->repository);
	}
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

gboolean
on_window_state_event(GtkWidget *widget, GdkEventWindowState *event, GitgWindow *window)
{
	GitgSettings *settings = gitg_settings_get_default();
	
	gitg_settings_set_window_state(settings, event->new_window_state);

	return FALSE;
}

void
on_recent_open(GtkRecentChooser *chooser, GitgWindow *window)
{
	GFile *file = g_file_new_for_uri(gtk_recent_chooser_get_current_uri(chooser));
	gchar *path = g_file_get_path(file);
	
	load_repository(window, path, 0, NULL, FALSE);
	
	g_free(path);
	g_object_unref(file);
}

#if GTK_CHECK_VERSION (2, 14, 0)
static void
url_activate_hook(GtkAboutDialog *dialog, gchar const *link, gpointer data)
{
	gtk_show_uri(NULL, link, GDK_CURRENT_TIME, NULL);
}

static void
email_activate_hook(GtkAboutDialog *dialog, gchar const *link, gpointer data)
{
	gchar *uri;
	gchar *escaped;
	
	escaped = g_uri_escape_string(link, NULL, FALSE);
	uri = g_strdup_printf("mailto:%s", escaped);
	
	gtk_show_uri(NULL, uri, GDK_CURRENT_TIME, NULL);
	
	g_free(uri);
	g_free(escaped);
}
#endif

void
on_help_about(GtkAction *action, GitgWindow *window)
{
	static gchar const copyright[] = "Copyright \xc2\xa9 2009 Jesse van den Kieboom";
	static gchar const *authors[] = {"Jesse van den Kieboom <jessevdk@gnome.org>", NULL};
	static gchar const *comments = N_("gitg is a git repository viewer for gtk+/GNOME");
	static gchar const *license = N_("This program is free software; you can redistribute it and/or modify\n"
		"it under the terms of the GNU General Public License as published by\n"
		"the Free Software Foundation; either version 2 of the License, or\n"
		"(at your option) any later version.\n"
		"\n"
		"This program is distributed in the hope that it will be useful,\n"
		"but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
		"MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the\n"
		"GNU General Public License for more details.\n"
		"\n"
		"You should have received a copy of the GNU General Public License\n"
		"along with this program; if not, write to the Free Software\n"
		"Foundation, Inc., 59 Temple Place, Suite 330,\n"
		"Boston, MA 02111-1307, USA.");

#if GTK_CHECK_VERSION (2, 14, 0)
	gtk_about_dialog_set_url_hook(url_activate_hook, NULL, NULL);
	gtk_about_dialog_set_email_hook(email_activate_hook, NULL, NULL);
#endif
	gchar *path = gitg_dirs_get_data_filename("icons", "gitg.svg", NULL);
	GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file(path, NULL);
	g_free(path);
	
	if (!pixbuf)
	{
		path = gitg_dirs_get_data_filename("icons", "gitg128x128.png", NULL);
		pixbuf = gdk_pixbuf_new_from_file(path, NULL);
		g_free(path);
	}

	gtk_show_about_dialog(GTK_WINDOW(window),
						  "authors", authors,
						  "copyright", copyright,
						  "comments", _(comments),
						  "version", VERSION,
						  "website", "http://trac.novowork.com/gitg",
						  "logo", pixbuf,
						  "license", _(license),
						  NULL);
	
	if (pixbuf)
		g_object_unref(pixbuf);
}

static gboolean
find_lane_boundary(GitgWindow *window, GtkTreePath *path, gint cell_x, gchar const **hash)
{
	GtkTreeModel *model = GTK_TREE_MODEL(window->priv->repository);
	GtkTreeIter iter;
	guint width;
	GitgRevision *revision;
	
	gtk_tree_model_get_iter(model, &iter, path);
	gtk_tree_model_get(model, &iter, 0, &revision, -1);
	
	/* Determine lane at cell_x */
	g_object_get(window->priv->renderer_path, "lane-width", &width, NULL);
	guint laneidx = cell_x / width;
	
	GSList *lanes = gitg_revision_get_lanes(revision);
	GitgLane *lane = (GitgLane *)g_slist_nth_data(lanes, laneidx);
	gboolean ret;

	if (lane && GITG_IS_LANE_BOUNDARY(lane))
	{
		if (hash)
			*hash = ((GitgLaneBoundary *)lane)->hash;

		ret = TRUE;
	}
	else
	{
		ret = FALSE;
	}
		
	gitg_revision_unref(revision);
	return ret;
}

static gboolean
is_boundary_from_event(GitgWindow *window, GdkEventAny *event, gint x, gint y, gchar const **hash)
{
	GtkTreePath *path;
	GtkTreeViewColumn *column;
	gint cell_x;
	gint cell_y;

	if (event->window != gtk_tree_view_get_bin_window(window->priv->tree_view))
		return FALSE;

	gtk_tree_view_get_path_at_pos(window->priv->tree_view, x, y, &path, &column, &cell_x, &cell_y);

	if (!path)
		return FALSE;

	/* First check on correct column */
	if (gtk_tree_view_get_column(window->priv->tree_view, 0) != column)
	{
		if (path)
			gtk_tree_path_free(path);
		
		return FALSE;
	}

	/* Check for lanes that have TYPE_END or TYPE_START and where the mouse
	   is actually placed */
	gboolean ret = find_lane_boundary(window, path, cell_x, hash);
	gtk_tree_path_free(path);
	
	return ret;
}

static gboolean 
on_tree_view_motion(GtkTreeView *treeview, GdkEventMotion *event, GitgWindow *window)
{
	if (is_boundary_from_event(window, (GdkEventAny *)event, event->x, event->y, NULL))	
		gdk_window_set_cursor(GTK_WIDGET(treeview)->window, window->priv->hand);
	else
		gdk_window_set_cursor(GTK_WIDGET(treeview)->window, NULL);
	
	return FALSE;
}

static gboolean
on_tree_view_button_release(GtkTreeView *treeview, GdkEventButton *event, GitgWindow *window)
{
	if (event->button != 1)
		return FALSE;

	gchar const *hash;
	
	if (!is_boundary_from_event(window, (GdkEventAny *)event, event->x, event->y, &hash))
		return FALSE;
	
	goto_hash(window, hash);
	return TRUE;
}

void
on_edit_preferences(GtkAction *action, GitgWindow *window)
{
	gitg_preferences_dialog_present(GTK_WINDOW(window));
}

void
on_repository_properties(GtkAction *action, GitgWindow *window)
{
	gitg_repository_dialog_present (window);
}

static void
on_push_activated (GtkAction *action, GitgWindow *window)
{
	gchar const *ptr = g_object_get_data (G_OBJECT (action), 
	                                      DYNAMIC_ACTION_DATA_KEY);
	add_branch_action (window,
	                   gitg_branch_actions_push_remote (window, window->priv->popup_refs[0], ptr));
}

static void
on_rebase_activated (GtkAction *action, GitgWindow *window)
{
	GitgRef *dest = g_object_get_data (G_OBJECT (action), 
	                                   DYNAMIC_ACTION_DATA_KEY);

	add_branch_action (window, gitg_branch_actions_rebase (window, 
	                                                       window->priv->popup_refs[0],
	                                                       dest));
}

static void
on_merge_activated (GtkAction *action, GitgWindow *window)
{
	GitgRef *dest = g_object_get_data (G_OBJECT (action), 
	                                   DYNAMIC_ACTION_DATA_KEY);

	add_branch_action (window, gitg_branch_actions_merge (window, 
	                                                      dest,
	                                                      window->priv->popup_refs[0]));
}

static void
on_stash_activated (GtkAction *action, GitgWindow *window)
{
	GitgRef *dest = g_object_get_data (G_OBJECT (action), 
	                                   DYNAMIC_ACTION_DATA_KEY);

	gitg_branch_actions_apply_stash (window, window->priv->popup_refs[0], dest);
}

static void
update_merge_rebase (GitgWindow *window, GitgRef *ref)
{
	if (window->priv->merge_rebase_uid != 0)
	{
		gtk_ui_manager_remove_ui (window->priv->menus_ui_manager, 
		                          window->priv->merge_rebase_uid);
	}

	GtkActionGroup *ac = window->priv->merge_rebase_action_group;
	
	if (ac)
	{
		GList *actions = gtk_action_group_list_actions (ac);
		GList *item;
		
		for (item = actions; item; item = g_list_next (item))
		{
			gtk_action_group_remove_action (ac, (GtkAction *)item->data);
		}
		
		g_list_free (actions);
	}
	
	if (gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_BRANCH &&
	    gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_STASH)
	{
		return;
	}
	
	if (window->priv->merge_rebase_uid == 0)
	{
		window->priv->merge_rebase_uid = gtk_ui_manager_new_merge_id (window->priv->menus_ui_manager);
	}
	
	if (ac == NULL)
	{
		ac = gtk_action_group_new ("GitgMergeRebaseActions");
		window->priv->merge_rebase_action_group = ac;
		gtk_ui_manager_insert_action_group (window->priv->menus_ui_manager,
		                                    ac,
		                                    0);
	}
	
	GSList *refs = gitg_repository_get_refs (window->priv->repository);
	GSList *item;

	for (item = refs; item; item = g_slist_next (item))
	{
		GitgRef *r = GITG_REF (item->data);
		
		if (gitg_ref_get_ref_type (r) == GITG_REF_TYPE_BRANCH && !gitg_ref_equal (r, ref))
		{
			gchar const *rname = gitg_ref_get_shortname (r);
			
			if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_BRANCH)
			{
				gchar *rebase = g_strconcat ("Rebase", rname, "Action", NULL);
				gchar *merge = g_strconcat ("Merge", rname, "Action", NULL);
			
				GtkAction *rebaseac = gtk_action_new (rebase, rname, NULL, NULL);
				GtkAction *mergeac = gtk_action_new (merge, rname, NULL, NULL);

				g_object_set_data_full (G_OBJECT (rebaseac),
					                    DYNAMIC_ACTION_DATA_KEY,
					                    gitg_ref_copy (r),
					                    (GDestroyNotify)gitg_ref_free);
				g_object_set_data_full (G_OBJECT (mergeac),
					                    DYNAMIC_ACTION_DATA_KEY,
					                    gitg_ref_copy (r),
					                    (GDestroyNotify)gitg_ref_free);

				g_signal_connect (rebaseac,
					              "activate",
					              G_CALLBACK (on_rebase_activated),
					              window);
				g_signal_connect (mergeac,
					              "activate",
					              G_CALLBACK (on_merge_activated),
					              window);

				gtk_action_group_add_action (ac, rebaseac);
				gtk_action_group_add_action (ac, mergeac);
			
				gchar *name = g_strconcat ("Rebase", rname, NULL);

				gtk_ui_manager_add_ui (window->priv->menus_ui_manager,
					                   window->priv->merge_rebase_uid,
					                   "/ui/ref_popup/Rebase/Placeholder",
					                   name,
					                   rebase,
					                   GTK_UI_MANAGER_MENUITEM,
					                   FALSE);
				g_free (name);
			
				name = g_strconcat ("Merge", rname, NULL);

				gtk_ui_manager_add_ui (window->priv->menus_ui_manager,
					                   window->priv->merge_rebase_uid,
					                   "/ui/ref_popup/Merge/Placeholder",
					                   name,
					                   merge,
					                   GTK_UI_MANAGER_MENUITEM,
					                   FALSE);
				g_free (name);

				g_object_unref (rebaseac);
				g_object_unref (mergeac);
			}
			else
			{
				gchar *stash = g_strconcat ("Stash", rname, "Action", NULL);
			
				GtkAction *stashac = gtk_action_new (stash, rname, NULL, NULL);

				g_object_set_data_full (G_OBJECT (stashac),
					                    DYNAMIC_ACTION_DATA_KEY,
					                    gitg_ref_copy (r),
					                    (GDestroyNotify)gitg_ref_free);

				g_signal_connect (stashac,
					              "activate",
					              G_CALLBACK (on_stash_activated),
					              window);

				gtk_action_group_add_action (ac, stashac);
			
				gchar *name = g_strconcat ("Stash", rname, NULL);

				gtk_ui_manager_add_ui (window->priv->menus_ui_manager,
					                   window->priv->merge_rebase_uid,
					                   "/ui/ref_popup/Stash/Placeholder",
					                   name,
					                   stash,
					                   GTK_UI_MANAGER_MENUITEM,
					                   FALSE);
				g_free (name);

				g_object_unref (stashac);
			}
		}
	}
	
	g_slist_foreach (refs, (GFunc)gitg_ref_free, NULL);
	g_slist_free (refs);
	
	if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_BRANCH)
	{
		gchar **remotes = gitg_repository_get_remotes (window->priv->repository);
		gchar **ptr = remotes;
	
		while (*ptr)
		{
			gchar *push = g_strconcat ("Push", *ptr, "Action", NULL);
			GtkAction *pushac = gtk_action_new (push, *ptr, NULL, NULL);
		
			gtk_action_group_add_action (ac, pushac);
		
			gchar *name = g_strconcat ("Push", *ptr, NULL);
			gtk_ui_manager_add_ui (window->priv->menus_ui_manager,
					                   window->priv->merge_rebase_uid,
					                   "/ui/ref_popup/Push/Placeholder",
					                   name,
					                   push,
					                   GTK_UI_MANAGER_MENUITEM,
					                   FALSE);

			g_object_set_data_full (G_OBJECT (pushac),
				                    DYNAMIC_ACTION_DATA_KEY,
				                    g_strdup (*ptr),
				                    (GDestroyNotify)g_free);

			g_signal_connect (pushac, 
				              "activate", 
				              G_CALLBACK (on_push_activated), 
				              window);
			++ptr;
		}
	
		g_strfreev (remotes);	
	}

	gtk_ui_manager_ensure_update (window->priv->menus_ui_manager);
}

static gboolean
has_local_ref (GitgWindow  *window,
               gchar const *name)
{
	GSList *refs = gitg_repository_get_refs (window->priv->repository);
	GSList *item;
	gboolean ret = FALSE;
	
	for (item = refs; item; item = g_slist_next (item))
	{
		GitgRef *ref = GITG_REF (item->data);
		
		if (gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_BRANCH)
		{
			continue;
		}
		
		gchar const *nm = gitg_ref_get_shortname (ref);
		
		if (g_strcmp0 (name, nm) == 0)
		{
			ret = TRUE;
			break;
		}
	}
	
	g_slist_foreach (refs, (GFunc)gitg_ref_free, NULL);
	g_slist_free (refs);
	
	return ret;
}

static gboolean
popup_ref (GitgWindow *window, GdkEventButton *event)
{
	gint cell_x;
	gint cell_y;
	GtkTreePath *path;
	GtkTreeViewColumn *column;
	
	GtkTreeView *tree_view = window->priv->tree_view;

	if (!gtk_tree_view_get_path_at_pos (tree_view,
	                                    (gint)event->x,
	                                    (gint)event->y,
	                                    &path,
	                                    &column,
	                                    &cell_x,
	                                    &cell_y))
	{
		return FALSE;
	}
	
	GtkCellRenderer *cell = gitg_utils_find_cell_at_pos (tree_view, column, path, cell_x);
	
	if (!cell || !GITG_IS_CELL_RENDERER_PATH (cell))
	{
		return FALSE;
	}
	
	GitgRef *ref = gitg_cell_renderer_path_get_ref_at_pos (GTK_WIDGET (tree_view),
	                                                       GITG_CELL_RENDERER_PATH (cell),
	                                                       cell_x,
	                                                       NULL);
	gtk_tree_path_free (path);
	
	if (!ref || (gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_BRANCH && 
	             gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_REMOTE &&
	             gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_STASH &&
	             gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_TAG))
	{
		return FALSE;
	}
	
	GtkWidget *popup = gtk_ui_manager_get_widget (window->priv->menus_ui_manager,
	                                              "/ui/ref_popup");

	GtkAction *checkout = gtk_ui_manager_get_action (window->priv->menus_ui_manager, "/ui/ref_popup/CheckoutAction");
	GtkAction *remove = gtk_ui_manager_get_action (window->priv->menus_ui_manager, "/ui/ref_popup/RemoveAction");

	if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_REMOTE)
	{
		gchar *local = gitg_ref_get_local_name (ref);

		if (!has_local_ref (window, local))
		{
			gchar *label = g_strdup_printf (_("New local branch <%s>"), local);
		
			gtk_action_set_label (checkout, label);
			gtk_action_set_visible (checkout, TRUE);
			g_free (label);
		}
		else
		{
			gtk_action_set_visible (checkout, FALSE);
		}
		
		g_free (local);
		gtk_action_set_label (remove, _("Remove remote branch"));
	}
	else if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_BRANCH)
	{
		gtk_action_set_label (checkout, _("Checkout working copy"));
		gtk_action_set_label (remove, _("Remove local branch"));
		
		GitgRef *working = gitg_repository_get_current_working_ref (window->priv->repository);

		gtk_action_set_visible (checkout, !gitg_ref_equal (working, ref));		
	}
	else if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_STASH)
	{
		gtk_action_set_label (remove, _("Remove stash"));
		gtk_action_set_visible (checkout, FALSE);
	}
	else if (gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_TAG)
	{
		gtk_action_set_label (remove, _("Remove tag"));
		
		if (!has_local_ref (window, gitg_ref_get_shortname (ref)))
		{
			gchar *label = g_strdup_printf (_("New local branch <%s>"), gitg_ref_get_shortname (ref));
			
			gtk_action_set_label (checkout, label);
			gtk_action_set_visible (checkout, TRUE);
			g_free (label);
		}
		else
		{
			gtk_action_set_visible (checkout, FALSE);
		}
	}
	
	update_merge_rebase (window, ref);
	window->priv->popup_refs[0] = ref;

	gtk_menu_popup (GTK_MENU (popup), NULL, NULL, NULL, window, event->button, event->time);
	return TRUE;
}

static gboolean
consecutive_revisions (GitgWindow *window, GList *rows)
{
	return FALSE;
}

static gboolean
popup_revision (GitgWindow *window, GdkEventButton *event)
{
	GtkTreeSelection *selection;
	
	selection = gtk_tree_view_get_selection (window->priv->tree_view);
	GList *rows = gtk_tree_selection_get_selected_rows (selection, NULL);

	gboolean show = FALSE;
	
	if (rows)
	{
		GtkAction *tag = gtk_ui_manager_get_action (window->priv->menus_ui_manager, "/ui/revision_popup/TagAction");
		GtkAction *squash = gtk_ui_manager_get_action (window->priv->menus_ui_manager, "/ui/revision_popup/SquashAction");
		
		if (!rows->next)
		{
			show = TRUE;
			gtk_action_set_visible (squash, FALSE);
			gtk_action_set_visible (tag, TRUE);
		}
		else if (consecutive_revisions (window, rows))
		{
			show = TRUE;
			gtk_action_set_visible (squash, TRUE);
			gtk_action_set_visible (tag, FALSE);
		}
	}
	
	g_list_foreach (rows, (GFunc)gtk_tree_path_free, NULL);
	g_list_free (rows);
	
	if (!show)
	{
		return FALSE;
	}
	
	gtk_menu_popup (GTK_MENU (gtk_ui_manager_get_widget (window->priv->menus_ui_manager, "/ui/revision_popup")),
	                NULL,
	                NULL,
	                NULL,
	                window,
	                event->button,
	                event->time);
	                
	return TRUE;
}

gboolean
on_tree_view_rv_button_press_event (GtkWidget *widget, GdkEventButton *event, GitgWindow *window)
{
	if (event->button == 3)
	{
		return popup_ref (window, event) || popup_revision (window, event);
	}
	
	return FALSE;
}

void
on_checkout_branch_action_activate (GtkAction *action, GitgWindow *window)
{
	if (gitg_branch_actions_checkout (window, window->priv->popup_refs[0]))
	{
		update_window_title (window);
	}
}

void
on_remove_branch_action_activate (GtkAction *action, GitgWindow *window)
{
	gitg_branch_actions_remove (window, window->priv->popup_refs[0]);
}

void
on_rebase_branch_action_activate (GtkAction *action, GitgWindow *window)
{
	gint source;
	
	if (gitg_ref_get_ref_type (window->priv->popup_refs[0]) == GITG_REF_TYPE_REMOTE)
	{
		source = 1;
	}
	else
	{
		source = 0;
	}
	
	add_branch_action (window, gitg_branch_actions_rebase (window, 
	                                                       window->priv->popup_refs[source],
	                                                       window->priv->popup_refs[!source]));
}

void
on_merge_branch_action_activate (GtkAction *action, GitgWindow *window)
{
	gint source;
	
	if (gitg_ref_get_ref_type (window->priv->popup_refs[0]) == GITG_REF_TYPE_REMOTE)
	{
		source = 1;
	}
	else
	{
		source = 0;
	}

	add_branch_action (window, gitg_branch_actions_merge (window, 
	                                                       window->priv->popup_refs[!source],
	                                                       window->priv->popup_refs[source]));
}

typedef struct
{
	GtkBuilder *builder;
	GitgWindow *window;
	GitgRevision *revision;
} TagInfo;

static void
free_tag_info (TagInfo *info)
{
	g_object_unref (info->builder);
	gitg_revision_unref (info->revision);

	g_slice_free (TagInfo, info);
}

static void
on_tag_dialog_response (GtkWidget *dialog, gint response, TagInfo *info)
{
	gboolean destroy = TRUE;
	
	if (response == GTK_RESPONSE_ACCEPT)
	{
		gchar const *name = gtk_entry_get_text (GTK_ENTRY (gtk_builder_get_object (info->builder, "entry_name")));
		
		GtkTextView *view = GTK_TEXT_VIEW (gtk_builder_get_object (info->builder, "text_view_message"));
		GtkTextIter start;
		GtkTextIter end;
		
		gtk_text_buffer_get_bounds (gtk_text_view_get_buffer (view), &start, &end);
		gchar *message = gtk_text_iter_get_text (&start, &end);
		
		if (!*name || !*message)
		{
			GtkWidget *dlg = gtk_message_dialog_new (GTK_WINDOW (dialog),
			                                         GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT,
			                                         GTK_MESSAGE_ERROR,
			                                         GTK_BUTTONS_OK,
			                                         _("Not all fields are correctly filled in"));
			gtk_message_dialog_format_secondary_text (GTK_MESSAGE_DIALOG (dlg),
			                                          _("Please make sure to fill in both the tag name and the commit message"));
			
			g_signal_connect (dlg, "response", G_CALLBACK (gtk_widget_destroy), NULL);
			gtk_widget_show (dlg);
			
			destroy = FALSE;
		}
		else
		{
			gboolean sign = gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (gtk_builder_get_object (info->builder, "check_button_sign")));

			gchar *sha1 = gitg_revision_get_sha1 (info->revision);
			if (!gitg_branch_actions_tag (info->window, 
			                              sha1,
			                              name,
			                              message,
			                              sign))
			{
				destroy = FALSE;
			}

			g_free (sha1);
			
			GitgPreferences *preferences = gitg_preferences_get_default ();
			g_object_set (preferences, "hidden-sign-tag", sign, NULL);
		}
		
		g_free (message);
	}
	
	if (destroy)
	{
		g_slice_free (TagInfo, info);
		gtk_widget_destroy (dialog);
	}
}



void
on_revision_tag_activate (GtkAction *action, GitgWindow *window)
{
	GtkTreeSelection *selection;
	GtkTreeModel *model;
	
	selection = gtk_tree_view_get_selection (window->priv->tree_view);
	GList *rows = gtk_tree_selection_get_selected_rows (selection, &model);
	
	GitgPreferences *preferences = gitg_preferences_get_default ();

	if (rows && !rows->next)
	{
		GtkBuilder *builder = gitg_utils_new_builder ("gitg-tag.ui");
		GtkWidget *widget = GTK_WIDGET (gtk_builder_get_object (builder, "dialog_tag"));
		
		GtkToggleButton *toggle = GTK_TOGGLE_BUTTON (gtk_builder_get_object (builder, "check_button_sign"));
		
		gboolean active = TRUE;
		
		g_object_get (preferences, "hidden-sign-tag", &active, NULL);
		gtk_toggle_button_set_active (toggle, active);
		
		gtk_window_set_transient_for (GTK_WINDOW (widget), GTK_WINDOW (window));
		
		GtkTreeIter iter;
		GitgRevision *rev;
		
		gtk_tree_model_get_iter (model, &iter, (GtkTreePath *)rows->data);
		gtk_tree_model_get (model, &iter, 0, &rev, -1);
		
		TagInfo *info = g_slice_new (TagInfo);
		info->revision = gitg_revision_ref (rev);
		info->window = window;
		info->builder = builder;
		
		g_signal_connect (widget, 
		                  "response", 
		                  G_CALLBACK (on_tag_dialog_response),
		                  info);

		gtk_widget_show (widget);
		
		gtk_widget_grab_focus (GTK_WIDGET (gtk_builder_get_object (builder, "entry_name")));
	}
	
	g_list_foreach (rows, (GFunc)gtk_tree_path_free, NULL);
	g_list_free (rows);
}

void
on_revision_squash_activate (GtkAction *action, GitgWindow *window)
{

}
