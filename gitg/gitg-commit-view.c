/*
 * gitg-commit-view.c
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

#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <gtksourceview/gtksourcestyleschememanager.h>
#include <glib/gi18n.h>
#include <string.h>

#include "gitg-commit-view.h"
#include "gitg-commit.h"
#include "gitg-utils.h"
#include "gitg-diff-view.h"
#include "gitg-preferences.h"
#include "gitg-data-binding.h"

#define GITG_COMMIT_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_COMMIT_VIEW, GitgCommitViewPrivate))
#define CATEGORY_UNSTAGE_HUNK "CategoryUnstageHunk"
#define CATEGORY_STAGE_HUNK "CategoryStageHunk"

/* Properties */
enum
{
	PROP_0,
	PROP_REPOSITORY,
	PROP_CONTEXT_SIZE
};

enum
{
	COLUMN_NAME = 0,
	COLUMN_FILE,
	N_COLUMNS
};

typedef enum
{
	CONTEXT_TYPE_FILE,
	CONTEXT_TYPE_HUNK
} ContextType;

struct _GitgCommitViewPrivate
{
	GitgCommit *commit;
	GitgRepository *repository;
	
	GtkListStore *store_unstaged;
	GtkListStore *store_staged;
	
	GtkTreeView *tree_view_staged;
	GtkTreeView *tree_view_unstaged;
	
	GtkSourceView *changes_view;
	GtkTextView *comment_view;
	GtkCheckButton *check_button_signed_off_by;
	GtkCheckButton *check_button_amend;
	
	GtkHScale *hscale_context;
	gint context_size;
	
	GitgRunner *runner;
	guint update_id;
	gboolean is_diff;

	GdkCursor *hand;
	GitgChangedFile *current_file;
	GitgChangedFileChanges current_changes;
	
	GtkUIManager *ui_manager;
	ContextType context_type;
	GtkTextIter context_iter;
	
	GtkActionGroup *group_context;
};

static void gitg_commit_view_buildable_iface_init(GtkBuildableIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgCommitView, gitg_commit_view, GTK_TYPE_VPANED, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, gitg_commit_view_buildable_iface_init));

static GtkBuildableIface parent_iface;

static void on_commit_file_inserted(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view);
static void on_commit_file_removed(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view);

static void on_staged_button_press(GtkWidget *widget, GdkEventButton *event, GitgCommitView *view);
static void on_unstaged_button_press(GtkWidget *widget, GdkEventButton *event, GitgCommitView *view);

static gboolean popup_unstaged_menu(GitgCommitView *view, GdkEventButton *event);
static gboolean popup_staged_menu(GitgCommitView *view, GdkEventButton *event);

static gboolean on_staged_popup_menu(GtkWidget *widget, GitgCommitView *view);
static gboolean on_unstaged_popup_menu(GtkWidget *widget, GitgCommitView *view);

static gboolean on_staged_motion(GtkWidget *widget, GdkEventMotion *event, GitgCommitView *view);
static gboolean on_unstaged_motion(GtkWidget *widget, GdkEventMotion *event, GitgCommitView *view);

static void on_commit_clicked(GtkButton *button, GitgCommitView *view);
static void on_context_value_changed(GtkHScale *scale, GitgCommitView *view);

static void on_changes_view_popup_menu(GtkTextView *textview, GtkMenu *menu, GitgCommitView *view);

static void on_stage_changes(GtkAction *action, GitgCommitView *view);
static void on_revert_changes(GtkAction *action, GitgCommitView *view);
static void on_ignore_file(GtkAction *action, GitgCommitView *view);
static void on_unstage_changes(GtkAction *action, GitgCommitView *view);

static void on_check_button_amend_toggled (GtkToggleButton *button, GitgCommitView *view);

static void
gitg_commit_view_finalize(GObject *object)
{
	GitgCommitView *view = GITG_COMMIT_VIEW(object);
	
	if (view->priv->update_id)
		g_signal_handler_disconnect(view->priv->runner, view->priv->update_id);
	
	gitg_runner_cancel(view->priv->runner);
	g_object_unref(view->priv->runner);
	g_object_unref(view->priv->ui_manager);
	
	gdk_cursor_unref(view->priv->hand);
	
	G_OBJECT_CLASS(gitg_commit_view_parent_class)->finalize(object);
}

static void
icon_data_func(GtkTreeViewColumn *column, GtkCellRenderer *renderer, GtkTreeModel *model, GtkTreeIter *iter, GitgCommitView *view)
{
	GitgChangedFile *file;
	
	gtk_tree_model_get(model, iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	
	gboolean staged = (model == GTK_TREE_MODEL(view->priv->store_staged));
	
	switch (status)
	{
		case GITG_CHANGED_FILE_STATUS_NEW:
			g_object_set(renderer, "stock-id", staged ? GTK_STOCK_ADD : GTK_STOCK_NEW, NULL);
		break;
		case GITG_CHANGED_FILE_STATUS_MODIFIED:
			g_object_set(renderer, "stock-id", staged ? GTK_STOCK_APPLY : GTK_STOCK_EDIT, NULL);
		break;
		case GITG_CHANGED_FILE_STATUS_DELETED:
			g_object_set(renderer, "stock-id", staged ? GTK_STOCK_REMOVE : GTK_STOCK_DELETE, NULL);
		break;
		default:
		break;
	}
	
	g_object_unref(file);
}

static void
set_icon_data_func(GitgCommitView *view, GtkTreeView *treeview, GtkCellRenderer *renderer)
{
	GtkTreeViewColumn *column = gtk_tree_view_get_column(treeview, 0);
	
	gtk_tree_view_column_set_cell_data_func(column, renderer, (GtkTreeCellDataFunc)icon_data_func, view, NULL);
}

static void
set_language(GitgCommitView *view, GtkSourceLanguage *language)
{
	GtkSourceBuffer *buffer = GTK_SOURCE_BUFFER(gtk_text_view_get_buffer(GTK_TEXT_VIEW(view->priv->changes_view)));
	
	gtk_source_buffer_set_language(buffer, language);
	gitg_diff_view_set_diff_enabled(GITG_DIFF_VIEW(view->priv->changes_view), FALSE);
}

static void
set_diff_language(GitgCommitView *view)
{
	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default();
	GtkSourceLanguage *language = gtk_source_language_manager_get_language(manager, "gitgdiff");

	set_language(view, language);
	gitg_diff_view_set_diff_enabled(GITG_DIFF_VIEW(view->priv->changes_view), TRUE);
	gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), TRUE);
}

static void
show_binary_information(GitgCommitView *view)
{
	set_language(view, NULL);
	gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), FALSE);

	gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(view->priv->changes_view)), _("Cannot display file content as text"), -1);
}

static void
on_changes_update(GitgRunner *runner, gchar **buffer, GitgCommitView *view)
{
	gchar *line;
	GtkTextBuffer *buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view->priv->changes_view));
	GtkTextIter iter;
	
	gtk_text_buffer_get_end_iter(buf, &iter);
	
	while ((line = *(buffer++)))
	{
		if (view->priv->is_diff && g_str_has_prefix(line, "@@"))
		{
			if (view->priv->current_changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED)
				gtk_source_buffer_create_source_mark(GTK_SOURCE_BUFFER(buf), NULL, CATEGORY_STAGE_HUNK, &iter);
			else
				gtk_source_buffer_create_source_mark(GTK_SOURCE_BUFFER(buf), NULL, CATEGORY_UNSTAGE_HUNK, &iter);
		}

		gtk_text_buffer_insert(buf, &iter, line, -1);
		gtk_text_buffer_insert(buf, &iter, "\n", -1);
	}
	
	if (gtk_source_buffer_get_language(GTK_SOURCE_BUFFER(buf)) == NULL)
	{
		gchar *content_type = gitg_utils_guess_content_type(GTK_TEXT_BUFFER(buf));
		
		if (content_type && !gitg_utils_can_display_content_type(content_type))
		{
			gitg_runner_cancel(runner);
			show_binary_information(view);
		}
		else if (content_type)
		{
			GtkSourceLanguage *language = gitg_utils_get_language(NULL, content_type);
			set_language(view, language);
			gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), FALSE);
		}
		
		g_free(content_type);
	}
	
	while (gtk_events_pending())
		gtk_main_iteration();
}

static void
connect_update(GitgCommitView *view)
{
	view->priv->update_id = g_signal_connect(view->priv->runner, "update", G_CALLBACK(on_changes_update), view);
}

static void
set_current_file(GitgCommitView *view, GitgChangedFile *file, GitgChangedFileChanges changes)
{
	if (view->priv->current_file != NULL)
		g_object_unref(view->priv->current_file);
	
	view->priv->current_file = file ? g_object_ref(file) : NULL;
	view->priv->current_changes = changes;
}

static gboolean
get_selected_files(GtkTreeView             *tree_view,
                   GList                  **files,
                   GList                  **paths,
                   GitgChangedFileChanges  *changes,
                   GitgChangedFileStatus   *status)
{
	GtkTreeSelection *selection = gtk_tree_view_get_selection(tree_view);

	if (files == NULL && changes == NULL && status == NULL && paths == NULL)
		return gtk_tree_selection_count_selected_rows(selection) != 0;
	
	GtkTreeModel *model;
	GList *items = gtk_tree_selection_get_selected_rows(selection, &model);
	
	if (files)
		*files = NULL;
	
	if (paths)
		*paths = NULL;
	
	if (!items)
		return FALSE;
	
	if (changes)
		*changes = ~0;
	
	if (status)
		*status = -1;
	
	GList *item;
	GitgChangedFile *file;

	for (item = items; item; item = g_list_next(item))
	{
		GtkTreeIter iter;

		gtk_tree_model_get_iter(model, &iter, (GtkTreePath *)item->data);
		gtk_tree_model_get(model, &iter, COLUMN_FILE, &file, -1);
		
		if (changes)
			*changes &= gitg_changed_file_get_status(file);
		
		GitgChangedFileStatus s = gitg_changed_file_get_status(file);
		
		if (status)
		{
			if (*status != -1 && *status != s)
				*status = GITG_CHANGED_FILE_STATUS_NONE;
			else
				*status = s;
		}
		
		if (files)
			*files = g_list_prepend(*files, file);
		else
			g_object_unref(file);
	}
	
	if (paths)
	{
		*paths = items;
	}
	else
	{
		g_list_foreach(items, (GFunc)gtk_tree_path_free, NULL);
		g_list_free(items);
	}
	
	if (files)
		*files = g_list_reverse(*files);
	
	return TRUE;
}

static gboolean
check_selection(GtkTreeView    *tree_view, 
                GtkTreeIter    *iter, 
                GitgCommitView *view)
{
	if (view->priv->update_id)
		g_signal_handler_disconnect(view->priv->runner, view->priv->update_id);

	gitg_runner_cancel(view->priv->runner);
	view->priv->update_id = 0;

	GtkTextView *tv = GTK_TEXT_VIEW(view->priv->changes_view);
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(tv);
	GtkTextIter start;
	GtkTextIter end;

	gtk_text_buffer_get_bounds(buffer, &start, &end);
	gtk_source_buffer_remove_source_marks(GTK_SOURCE_BUFFER(buffer), &start, &end, CATEGORY_UNSTAGE_HUNK);
	gtk_source_buffer_remove_source_marks(GTK_SOURCE_BUFFER(buffer), &start, &end, CATEGORY_STAGE_HUNK);
	gtk_text_buffer_set_text(gtk_text_view_get_buffer(tv), "", -1);
	
	GList *paths;
	gboolean ret;
	get_selected_files(tree_view, NULL, &paths, NULL, NULL);
	
	if (g_list_length(paths) != 1)
	{
		set_current_file(view, NULL, GITG_CHANGED_FILE_CHANGES_NONE);
		gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), FALSE);
		ret = FALSE;
	}
	else
	{
		if (iter)
			gtk_tree_model_get_iter(gtk_tree_view_get_model(tree_view),
			                        iter,
			                        (GtkTreePath *)paths->data);
		ret = TRUE;
	}
	
	g_list_foreach(paths, (GFunc)gtk_tree_path_free, NULL);
	g_list_free(paths);
	return ret;
}

static void
unselect_tree_view(GtkTreeView *view)
{
	gtk_tree_selection_unselect_all(gtk_tree_view_get_selection(view));
}

static void
unstaged_selection_changed(GtkTreeSelection *selection, GitgCommitView *view)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	
	if (!check_selection(view->priv->tree_view_unstaged, &iter, view))
		return;
	
	model = gtk_tree_view_get_model(view->priv->tree_view_unstaged);
	unselect_tree_view(view->priv->tree_view_staged);
	
	GitgChangedFile *file;
	
	gtk_tree_model_get(model, &iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	GFile *f = gitg_changed_file_get_file(file);

	if (status == GITG_CHANGED_FILE_STATUS_NEW)
	{
		gchar *content_type = gitg_utils_get_content_type(f);
		
		if (!gitg_utils_can_display_content_type(content_type))
		{
			show_binary_information(view);
		}
		else
		{
			GInputStream *stream = G_INPUT_STREAM(g_file_read(f, NULL, NULL));
			
			if (!stream)
			{
				show_binary_information(view);
			}
			else
			{
				gchar *basename = g_file_get_basename(f);
				GtkSourceLanguage *language = gitg_utils_get_language(basename, content_type);
				g_free(basename);

				set_language(view, language);
				gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), FALSE);
				
				view->priv->is_diff = FALSE;
				connect_update(view);
				
				gitg_runner_run_stream(view->priv->runner, stream, NULL);
				g_object_unref(stream);
			}
		}

		g_free(content_type);
	}
	else
	{
		set_diff_language(view);
		view->priv->is_diff = TRUE;
		connect_update(view);

		gchar *path = gitg_repository_relative(view->priv->repository, f);

		gchar ct[10];
		g_snprintf(ct, sizeof(ct), "-U%d", view->priv->context_size);
		
		gitg_repository_run_commandv(view->priv->repository, view->priv->runner, NULL, "diff", ct, "--", path, NULL);
		g_free(path);
	}
	
	set_current_file(view, file, GITG_CHANGED_FILE_CHANGES_UNSTAGED);

	g_object_unref(file);
	g_object_unref(f);
}

static void
staged_selection_changed(GtkTreeSelection *selection, GitgCommitView *view)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	
	if (!check_selection(view->priv->tree_view_staged, &iter, view))
		return;
	
	model = gtk_tree_view_get_model(view->priv->tree_view_staged);
	unselect_tree_view(view->priv->tree_view_unstaged);

	GitgChangedFile *file;
	
	gtk_tree_model_get(model, &iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(view->priv->repository, f);
	
	if (status == GITG_CHANGED_FILE_STATUS_NEW)
	{
		view->priv->is_diff = FALSE;

		gchar *content_type = gitg_utils_get_content_type(f);
		
		if (!gitg_utils_can_display_content_type(content_type))
		{
			show_binary_information(view);
		}
		else
		{
			gchar *basename = g_file_get_basename(f);
			GtkSourceLanguage *language = gitg_utils_get_language(basename, content_type);
			g_free(basename);

			gtk_widget_set_sensitive(GTK_WIDGET(view->priv->hscale_context), FALSE);

			connect_update(view);

			gchar *indexpath = g_strconcat(":0:", path, NULL);
			gitg_repository_run_commandv(view->priv->repository, view->priv->runner, NULL, "show", "--encoding=UTF-8", indexpath, NULL);
			g_free(indexpath);
		}
		
		g_free(content_type);
	}
	else
	{
		view->priv->is_diff = TRUE;
		set_diff_language(view);
		connect_update(view);
		
		gchar *head = gitg_repository_parse_head(view->priv->repository);
		gchar ct[10];
		g_snprintf(ct, sizeof(ct), "-U%d", view->priv->context_size);

		gitg_repository_run_commandv(view->priv->repository, view->priv->runner, NULL, "diff-index", ct, "--cached", head, "--", path, NULL);
		g_free(head);
	}

	g_object_unref(f);
	g_free(path);	

	set_current_file(view, file, GITG_CHANGED_FILE_CHANGES_CACHED);	
	g_object_unref(file);
}

static int
compare_by_name(GtkTreeModel *model, GtkTreeIter *a, GtkTreeIter *b, gpointer userdata)
{
	gchar *s1;
	gchar *s2;

	gtk_tree_model_get(model, a, COLUMN_NAME, &s1, -1);
	gtk_tree_model_get(model, b, COLUMN_NAME, &s2, -1);
	
	int ret = gitg_utils_sort_names(s1, s2);
	
	g_free(s1);
	g_free(s2);
	
	return ret;
}

static void
set_sort_func(GtkListStore *store)
{
	gtk_tree_sortable_set_sort_column_id(GTK_TREE_SORTABLE(store), 0, GTK_SORT_ASCENDING);
	gtk_tree_sortable_set_sort_func(GTK_TREE_SORTABLE(store), 0, compare_by_name, NULL, NULL);
}

static gboolean
has_hunk_mark(GtkSourceBuffer *buffer, GtkTextIter *iter)
{
	GSList *m1 = gtk_source_buffer_get_source_marks_at_iter(buffer, iter, CATEGORY_UNSTAGE_HUNK);
	gboolean has_mark = (m1 != NULL);
	g_slist_free(m1);
	
	if (has_mark)
		return TRUE;
	
	m1 = gtk_source_buffer_get_source_marks_at_iter(buffer, iter, CATEGORY_STAGE_HUNK);
	has_mark = (m1 != NULL);
	g_slist_free(m1);
	
	return has_mark;
}

static gchar *
get_patch_header(GitgCommitView *view, GtkTextBuffer *buffer, GtkTextIter const *iter)
{
	GtkTextIter begin = *iter;
	GtkTextIter end;

	gboolean foundstart = FALSE;
	gboolean foundend = FALSE;

	while (!gtk_text_iter_is_start(&begin) && !foundstart)
	{
		gtk_text_iter_backward_line(&begin);
		GtkTextIter lineend = begin;
		gtk_text_iter_forward_line(&lineend);
		
		gchar *text = gtk_text_buffer_get_text(buffer, &begin, &lineend, FALSE);
		
		if (g_str_has_prefix(text, "+++ "))
		{
			end = lineend;
			foundend = TRUE;
		}
		else
		{
			foundstart = g_str_has_prefix(text, "diff --git ");
		}

		g_free(text);
	}
	
	if (!foundstart || !foundend)
		return NULL;
	
	return gtk_text_buffer_get_text(buffer, &begin, &end, FALSE);
}

static gchar *
get_patch_contents(GitgCommitView *view, GtkTextBuffer *buffer, GtkTextIter const *iter)
{
	/* iter marks the start of the patch, we go until we find the next hunk,
	   or next file start (or end of file) */
	GtkTextIter begin = *iter;
	GtkTextIter end = begin;
	
	while (!gtk_text_iter_is_end(&end))
	{
		if (!gtk_text_iter_forward_line(&end))
			break;
		
		GtkTextIter lineend = end;
		gtk_text_iter_forward_to_line_end(&lineend);
		
		gchar *text = gtk_text_buffer_get_text(buffer, &end, &lineend, FALSE);
		gboolean isend = g_str_has_prefix(text, "@@") || g_str_has_prefix(text, "diff --git ");
		g_free(text);
		
		if (isend)
		{
			gtk_text_iter_backward_line(&end);
			gtk_text_iter_forward_line(&end);
			break;
		}
	}
	
	return gtk_text_buffer_get_text(buffer, &begin, &end, FALSE);
}

static gchar *
get_hunk_patch(GitgCommitView *view, GtkTextIter *iter)
{
	/* Get patch header */
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view->priv->changes_view));
	gchar *header = get_patch_header(view, buffer, iter);
	
	if (!header)
		return NULL;
	
	/* Get patch contents */
	gchar *contents = get_patch_contents(view, buffer, iter);

	if (!contents)
	{
		g_free(header);
		return NULL;
	}
	
	return g_strconcat(header, contents, NULL);
}

static gboolean
handle_stage_unstage(GitgCommitView *view, GtkTextIter *iter)
{
	gchar *hunk = get_hunk_patch(view, iter);
	
	if (!hunk)
		return FALSE;

	gboolean ret;
	GitgChangedFile *file = g_object_ref(view->priv->current_file);
	gboolean unstage = view->priv->current_changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED;
	
	if (unstage)
		ret = gitg_commit_stage(view->priv->commit, view->priv->current_file, hunk, NULL);
	else
		ret = gitg_commit_unstage(view->priv->commit, view->priv->current_file, hunk, NULL);
	
	if (ret && file == view->priv->current_file)
	{
		/* remove hunk from text view */
		gitg_diff_view_remove_hunk(GITG_DIFF_VIEW(view->priv->changes_view), iter);
	}
	
	g_object_unref(file);
	g_free(hunk);
	
	return ret;
}

static gboolean
get_hunk_at_pointer(GitgCommitView *view, GtkTextIter *iter, gchar **hunk)
{
	GtkTextView *textview = GTK_TEXT_VIEW(view->priv->changes_view);
	gint x;
	gint y;
	gint buf_x;
	gint buf_y;

	/* Get where the pointer really is. */
	GdkWindow *win = gtk_text_view_get_window(textview, GTK_TEXT_WINDOW_TEXT);
	gdk_window_get_pointer(win, &x, &y, NULL);

	/* Get the iter where the cursor is at */
	gtk_text_view_window_to_buffer_coords(textview, GTK_TEXT_WINDOW_TEXT, x, y, &buf_x, &buf_y);
	gtk_text_view_get_iter_at_location(textview, iter, buf_x, buf_y);

	if (gtk_text_iter_backward_line(iter))
		gtk_text_iter_forward_line(iter);

	GtkSourceBuffer *buffer = GTK_SOURCE_BUFFER(gtk_text_view_get_buffer(textview));
	
	if (!has_hunk_mark(buffer, iter))
		return FALSE;

	if (hunk)
		*hunk = get_hunk_patch(view, iter);
	
	return TRUE;
}

static gboolean
view_event(GtkWidget *widget, GdkEventAny *event, GitgCommitView *view)
{
	GtkTextWindowType type;
	GtkTextIter iter;

	type = gtk_text_view_get_window_type(GTK_TEXT_VIEW(widget), event->window);

	if (type != GTK_TEXT_WINDOW_TEXT)
		return FALSE;

	if (event->type != GDK_MOTION_NOTIFY && event->type != GDK_BUTTON_PRESS)
		return FALSE;

	gboolean is_hunk = get_hunk_at_pointer(view, &iter, NULL);

	if (event->type == GDK_MOTION_NOTIFY)
	{
		if (is_hunk)
		{
			gdk_window_set_cursor(event->window, view->priv->hand);
		} 
		else
		{
			gdk_window_set_cursor(event->window, NULL);
		}
	}
	else if (is_hunk && ((GdkEventButton *)event)->button == 1)
	{
		handle_stage_unstage(view, &iter);
	}
	
	return FALSE;
}

static GtkTextBuffer *
initialize_buffer(GitgCommitView *view)
{
	GtkTextBuffer *buffer = GTK_TEXT_BUFFER(gtk_source_buffer_new(NULL));
	
	GtkSourceStyleSchemeManager *manager = gtk_source_style_scheme_manager_get_default();
	GtkSourceStyleScheme *scheme = gtk_source_style_scheme_manager_get_scheme(manager, "gitg");
	gtk_source_buffer_set_style_scheme(GTK_SOURCE_BUFFER(buffer), scheme);
	
	return buffer;
}

static GtkTargetEntry dnd_entries[] = {
	{"text/uri-list", 0, 1}
};

static void
on_tree_view_drag_data_get (GtkWidget        *widget,
                            GdkDragContext   *context,
                            GtkSelectionData *selection,
                            guint             info,
                            guint             time,
                            GitgCommitView   *view)
{
	GList *selected;
	GList *item;
	gchar **uris;
	guint i = 0;

	get_selected_files(GTK_TREE_VIEW(widget), &selected, NULL, NULL, NULL);	
	uris = g_new(gchar *, g_list_length(selected) + 1);
	
	for (item = selected; item; item = g_list_next(item))
	{
		GitgChangedFile *file = GITG_CHANGED_FILE (item->data);
		GFile *gf = gitg_changed_file_get_file(file);
	
		uris[i++] = g_file_get_uri(gf);
		g_object_unref(gf);
	}
	
	uris[i] = NULL;
	gtk_selection_data_set_uris(selection, uris);

	g_strfreev(uris);

	g_list_foreach(selected, (GFunc)g_object_unref, NULL);
	g_list_free(selected);
}

static void
on_tree_view_staged_drag_data_received(GtkWidget        *widget,
                                       GdkDragContext   *drag_context,
                                       gint              x,
                                       gint              y,
                                       GtkSelectionData *data,
                                       guint             info,
                                       guint             time,
                                       GitgCommitView   *view)
{
	/* Stage all the files dropped on this */
	gchar **uris = gtk_selection_data_get_uris(data);
	gchar **uri;

	for (uri = uris; *uri; ++uri)
	{
		GFile *file = g_file_new_for_uri(*uri);
		GitgChangedFile *f;

		f = gitg_commit_find_changed_file(view->priv->commit, file);
		
		if (f && (gitg_changed_file_get_changes(f) & GITG_CHANGED_FILE_CHANGES_UNSTAGED))
		{
			gitg_commit_stage(view->priv->commit, f, NULL, NULL);
		}
		
		g_object_unref(f);
		g_object_unref(file);
	}
}

static void
on_tree_view_unstaged_drag_data_received(GtkWidget        *widget,
                                         GdkDragContext   *drag_context,
                                         gint              x,
                                         gint              y,
                                         GtkSelectionData *data,
                                         guint             info,
                                         guint             time,
                                         GitgCommitView   *view)
{
	/* Unstage all the files dropped on this */
	gchar **uris = gtk_selection_data_get_uris(data);
	gchar **uri;
	
	for (uri = uris; *uri; ++uri)
	{
		GFile *file = g_file_new_for_uri(*uri);
		GitgChangedFile *f;

		f = gitg_commit_find_changed_file(view->priv->commit, file);
		
		if (f && (gitg_changed_file_get_changes(f) & GITG_CHANGED_FILE_CHANGES_CACHED))
		{
			gitg_commit_unstage(view->priv->commit, f, NULL, NULL);
		}
		
		g_object_unref(f);
		g_object_unref(file);
	}
}

static void
initialize_dnd(GitgCommitView *view, 
               GtkTreeView    *tree_view,
               GCallback       drag_data_received)
{
	gtk_tree_view_enable_model_drag_dest(tree_view,
	                                     dnd_entries,
	                                     G_N_ELEMENTS(dnd_entries),
	                                     GDK_ACTION_COPY);

	gtk_tree_view_enable_model_drag_source(tree_view,
	                                      GDK_BUTTON1_MASK,
	                                      dnd_entries,
	                                      G_N_ELEMENTS(dnd_entries),
	                                      GDK_ACTION_COPY);

	g_signal_connect(tree_view, "drag-data-get", G_CALLBACK(on_tree_view_drag_data_get), view);
	g_signal_connect(tree_view, "drag-data-received", G_CALLBACK(drag_data_received), view);
}

static void
initialize_dnd_staged(GitgCommitView *view)
{
	initialize_dnd(view,
	               view->priv->tree_view_staged,
	               G_CALLBACK(on_tree_view_staged_drag_data_received));
}

static void
initialize_dnd_unstaged(GitgCommitView *view)
{
	initialize_dnd(view,
	               view->priv->tree_view_unstaged,
	               G_CALLBACK(on_tree_view_unstaged_drag_data_received));
}

static void
gitg_commit_view_parser_finished(GtkBuildable *buildable, GtkBuilder *builder)
{
	if (parent_iface.parser_finished)
		parent_iface.parser_finished(buildable, builder);

	/* Store widgets */
	GitgCommitView *self = GITG_COMMIT_VIEW(buildable);
	
	GtkBuilder *b = gitg_utils_new_builder("gitg-commit-menu.ui");
	self->priv->ui_manager = g_object_ref(gtk_builder_get_object(b, "uiman"));

	g_signal_connect(gtk_builder_get_object(b, "StageChangesAction"), "activate", G_CALLBACK(on_stage_changes), self);
	g_signal_connect(gtk_builder_get_object(b, "RevertChangesAction"), "activate", G_CALLBACK(on_revert_changes), self);
	g_signal_connect(gtk_builder_get_object(b, "IgnoreFileAction"), "activate", G_CALLBACK(on_ignore_file), self);
	g_signal_connect(gtk_builder_get_object(b, "UnstageChangesAction"), "activate", G_CALLBACK(on_unstage_changes), self);

	self->priv->group_context = GTK_ACTION_GROUP(gtk_builder_get_object(b, "action_group_commit_context"));
	
	g_object_unref(b);
	
	self->priv->tree_view_unstaged = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_unstaged"));
	self->priv->tree_view_staged = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_staged"));
	
	self->priv->store_unstaged = gtk_list_store_new(N_COLUMNS, G_TYPE_STRING, GITG_TYPE_CHANGED_FILE);
	self->priv->store_staged = gtk_list_store_new(N_COLUMNS, G_TYPE_STRING, GITG_TYPE_CHANGED_FILE);
	
	set_sort_func(self->priv->store_unstaged);
	set_sort_func(self->priv->store_staged);
	
	self->priv->changes_view = GTK_SOURCE_VIEW(gtk_builder_get_object(builder, "source_view_changes"));
	self->priv->comment_view = GTK_TEXT_VIEW(gtk_builder_get_object(builder, "text_view_comment"));
	self->priv->check_button_signed_off_by = GTK_CHECK_BUTTON(gtk_builder_get_object(builder, "check_button_signed_off_by"));
	self->priv->check_button_amend = GTK_CHECK_BUTTON(gtk_builder_get_object(builder, "check_button_amend"));
	
	GitgPreferences *preferences = gitg_preferences_get_default();
	
	gitg_data_binding_new(preferences, "message-show-right-margin",
	                      self->priv->comment_view, "show-right-margin");

	gitg_data_binding_new(preferences, "message-right-margin-at",
	                      self->priv->comment_view, "right-margin-position");
	
	self->priv->hscale_context = GTK_HSCALE(gtk_builder_get_object(builder, "hscale_context"));
	gtk_range_set_value (GTK_RANGE (self->priv->hscale_context), 3);
	
	initialize_dnd_staged(self);
	initialize_dnd_unstaged(self);
	
	GtkIconTheme *theme = gtk_icon_theme_get_default();
	GdkPixbuf *pixbuf = gtk_icon_theme_load_icon(theme, GTK_STOCK_ADD, 12, GTK_ICON_LOOKUP_USE_BUILTIN, NULL);
	
	if (pixbuf)
	{
		gtk_source_view_set_mark_category_pixbuf(self->priv->changes_view, CATEGORY_STAGE_HUNK, pixbuf);
		g_object_unref(pixbuf);
	}
	
	pixbuf = gtk_icon_theme_load_icon(theme, GTK_STOCK_REMOVE, 12, GTK_ICON_LOOKUP_USE_BUILTIN, NULL);
	
	if (pixbuf)
	{
		gtk_source_view_set_mark_category_pixbuf(self->priv->changes_view, CATEGORY_UNSTAGE_HUNK, pixbuf);
		g_object_unref(pixbuf);
	}
	
	gitg_utils_set_monospace_font(GTK_WIDGET(self->priv->changes_view));
	
	GtkTextBuffer *buffer = initialize_buffer(self);
	gtk_text_view_set_buffer(GTK_TEXT_VIEW(self->priv->changes_view), buffer);
	g_signal_connect(self->priv->changes_view, "event", G_CALLBACK(view_event), self);
	
	gtk_tree_view_set_model(self->priv->tree_view_unstaged, GTK_TREE_MODEL(self->priv->store_unstaged));
	gtk_tree_view_set_model(self->priv->tree_view_staged, GTK_TREE_MODEL(self->priv->store_staged));
	
	set_icon_data_func(self, self->priv->tree_view_unstaged, GTK_CELL_RENDERER(gtk_builder_get_object(builder, "unstaged_cell_renderer_icon")));
	set_icon_data_func(self, self->priv->tree_view_staged, GTK_CELL_RENDERER(gtk_builder_get_object(builder, "staged_cell_renderer_icon")));
	
	GtkTreeSelection *selection;
	
	selection = gtk_tree_view_get_selection(self->priv->tree_view_unstaged);
	
	gtk_tree_selection_set_mode(selection, GTK_SELECTION_MULTIPLE);
	g_signal_connect(selection, "changed", G_CALLBACK(unstaged_selection_changed), self);
	
	selection = gtk_tree_view_get_selection(self->priv->tree_view_staged);
	gtk_tree_selection_set_mode(selection, GTK_SELECTION_MULTIPLE);
	g_signal_connect(selection, "changed", G_CALLBACK(staged_selection_changed), self);
	
	g_signal_connect(self->priv->tree_view_unstaged, "event-after", G_CALLBACK(on_unstaged_button_press), self);
	g_signal_connect(self->priv->tree_view_staged, "event-after", G_CALLBACK(on_staged_button_press), self);

	g_signal_connect(self->priv->tree_view_unstaged, "popup-menu", G_CALLBACK(on_unstaged_popup_menu), self);
	g_signal_connect(self->priv->tree_view_staged, "popup-menu", G_CALLBACK(on_staged_popup_menu), self);
	g_signal_connect(self->priv->changes_view, "populate-popup", G_CALLBACK(on_changes_view_popup_menu), self);

	g_signal_connect(self->priv->tree_view_unstaged, "motion-notify-event", G_CALLBACK(on_unstaged_motion), self);
	g_signal_connect(self->priv->tree_view_staged, "motion-notify-event", G_CALLBACK(on_staged_motion), self);
	
	g_signal_connect(gtk_builder_get_object(builder, "button_commit"), "clicked", G_CALLBACK(on_commit_clicked), self);
	
	g_signal_connect(self->priv->hscale_context, "value-changed", G_CALLBACK(on_context_value_changed), self);
	
	g_signal_connect (self->priv->check_button_amend,
	                  "toggled",
	                  G_CALLBACK (on_check_button_amend_toggled),
	                  self);
}

static void
gitg_commit_view_buildable_iface_init(GtkBuildableIface *iface)
{
	parent_iface = *iface;
	
	iface->parser_finished = gitg_commit_view_parser_finished;
}

static void
gitg_commit_view_dispose(GObject *object)
{
	GitgCommitView *self = GITG_COMMIT_VIEW(object);
	
	if (self->priv->repository)
	{
		g_object_unref(self->priv->repository);
		self->priv->repository = NULL;
	}
	
	if (self->priv->commit)
	{
		g_signal_handlers_disconnect_by_func(self->priv->commit, on_commit_file_inserted, self);
		g_signal_handlers_disconnect_by_func(self->priv->commit, on_commit_file_removed, self);

		g_object_unref(self->priv->commit);
		self->priv->commit = NULL;
	}
}

static void
gitg_commit_view_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgCommitView *self = GITG_COMMIT_VIEW(object);

	switch (prop_id)
	{
		case PROP_REPOSITORY:
			g_value_set_object(value, self->priv->repository);
		break;
		case PROP_CONTEXT_SIZE:
			g_value_set_int(value, self->priv->context_size);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_commit_view_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgCommitView *self = GITG_COMMIT_VIEW(object);
	
	switch (prop_id)
	{
		case PROP_REPOSITORY:
			self->priv->repository = g_value_dup_object(value);
		break;
		case PROP_CONTEXT_SIZE:
			self->priv->context_size = g_value_get_int(value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
initialize_commit(GitgCommitView *self)
{
	if (self->priv->commit)
		return;

	self->priv->commit = gitg_commit_new(self->priv->repository);

	g_signal_connect(self->priv->commit, "inserted", G_CALLBACK(on_commit_file_inserted), self);
	g_signal_connect(self->priv->commit, "removed", G_CALLBACK(on_commit_file_removed), self);

	gitg_commit_refresh(self->priv->commit);
}

static void
gitg_commit_view_map(GtkWidget *widget)
{
	GitgCommitView *self = GITG_COMMIT_VIEW(widget);

	GTK_WIDGET_CLASS(gitg_commit_view_parent_class)->map(widget);
	
	if (!self->priv->repository)
		return;
	
	initialize_commit(self);
}

static void
gitg_commit_view_class_init(GitgCommitViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);

	object_class->finalize = gitg_commit_view_finalize;
	object_class->dispose = gitg_commit_view_dispose;
	
	widget_class->map = gitg_commit_view_map;

	object_class->set_property = gitg_commit_view_set_property;
	object_class->get_property = gitg_commit_view_get_property;

	g_object_class_install_property(object_class, PROP_REPOSITORY,
					 g_param_spec_object("repository",
							      "REPOSITORY",
							      "Repository",
							      GITG_TYPE_REPOSITORY,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_CONTEXT_SIZE,
					 g_param_spec_int("context-size",
							      "CONTEXT_SIZE",
							      "Diff context size",
							      1,
							      G_MAXINT,
							      3,
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_type_class_add_private(object_class, sizeof(GitgCommitViewPrivate));
}

static void
gitg_commit_view_init(GitgCommitView *self)
{
	self->priv = GITG_COMMIT_VIEW_GET_PRIVATE(self);
	
	self->priv->runner = gitg_runner_new(10000);
	self->priv->hand = gdk_cursor_new(GDK_HAND1);
}

void 
gitg_commit_view_set_repository(GitgCommitView *view, GitgRepository *repository)
{
	g_return_if_fail(GITG_IS_COMMIT_VIEW(view));
	g_return_if_fail(repository == NULL || GITG_IS_REPOSITORY(repository));

	if (view->priv->repository)
	{
		g_object_unref(view->priv->repository);
		view->priv->repository = NULL;
	}
	
	if (view->priv->commit)
	{
		g_object_unref(view->priv->commit);
		view->priv->commit = NULL;
	}
	
	gtk_list_store_clear(view->priv->store_unstaged);
	gtk_list_store_clear(view->priv->store_staged);

	if (repository)
		view->priv->repository = g_object_ref(repository);
	
	if (GTK_WIDGET_MAPPED(GTK_WIDGET(view)))
		initialize_commit(view);
	
	g_object_notify(G_OBJECT(view), "repository");
}

static void
append_file(GtkListStore *store, GitgChangedFile *file, GitgCommitView *view)
{
	GFile *f = gitg_changed_file_get_file(file);
	GFile *repos = g_file_new_for_path(gitg_repository_get_path(view->priv->repository));
	
	GtkTreeIter iter;
	gchar *rel = g_file_get_relative_path(repos, f);

	gtk_list_store_append(store, &iter);
	gtk_list_store_set(store, &iter, COLUMN_NAME, rel, COLUMN_FILE, file, -1);
	
	g_free(rel);
	g_object_unref(repos);
	g_object_unref(f);
}

/* Callbacks */
static gboolean
find_file_in_store(GtkListStore *store, GitgChangedFile *file, GtkTreeIter *iter)
{
	GtkTreeModel *model = GTK_TREE_MODEL(store);
	
	if (!gtk_tree_model_get_iter_first(model, iter))
		return FALSE;
		
	do
	{
		GitgChangedFile *other;
		gtk_tree_model_get(model, iter, COLUMN_FILE, &other, -1);
		gboolean ret = (other == file);
		
		g_object_unref(other);
		
		if (ret)
			return TRUE;
	} while (gtk_tree_model_iter_next(model, iter));
	
	return FALSE;
}

static void
model_row_changed(GtkListStore *store, GtkTreeIter *iter)
{
	GtkTreePath *path = gtk_tree_model_get_path(GTK_TREE_MODEL(store), iter);
	
	if (!path)
		return;
	
	gtk_tree_model_row_changed(GTK_TREE_MODEL(store), path, iter);
	gtk_tree_path_free(path);
}

static void
on_commit_file_changed(GitgChangedFile *file, GParamSpec *spec, GitgCommitView *view)
{
	GtkTreeIter staged;
	GtkTreeIter unstaged;
	
	gboolean isstaged = find_file_in_store(view->priv->store_staged, file, &staged);
	gboolean isunstaged = find_file_in_store(view->priv->store_unstaged, file, &unstaged);

	if (isstaged)
		model_row_changed(view->priv->store_staged, &staged);
	
	if (isunstaged)
		model_row_changed(view->priv->store_unstaged, &unstaged);

	GitgChangedFileChanges changes = gitg_changed_file_get_changes(file);
	
	if (changes & GITG_CHANGED_FILE_CHANGES_CACHED)
	{
		if (!isstaged)
			append_file(view->priv->store_staged, file, view);
	}
	else
	{
		if (isstaged)
			gtk_list_store_remove(view->priv->store_staged, &staged);
	}
	
	if (changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED)
	{
		if (!isunstaged)
			append_file(view->priv->store_unstaged, file, view);
	}
	else
	{
		if (isunstaged)
			gtk_list_store_remove(view->priv->store_unstaged, &unstaged);
	}
}

static void
on_commit_file_inserted(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view)
{
	GitgChangedFileChanges changes = gitg_changed_file_get_changes(file);
	
	if (changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED)
		append_file(view->priv->store_unstaged, file, view);
	
	if (changes & GITG_CHANGED_FILE_CHANGES_CACHED)
		append_file(view->priv->store_staged, file, view);
	
	g_signal_connect(file, "notify::changes", G_CALLBACK(on_commit_file_changed), view);
	g_signal_connect(file, "notify::status", G_CALLBACK(on_commit_file_changed), view);
}

static void
on_commit_file_removed(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view)
{
	GtkTreeIter iter;
	
	if (find_file_in_store(view->priv->store_staged, file, &iter))
		gtk_list_store_remove(view->priv->store_staged, &iter);
	
	if (find_file_in_store(view->priv->store_unstaged, file, &iter))
		gtk_list_store_remove(view->priv->store_unstaged, &iter);
}

static gboolean
column_icon_test(GtkTreeView *view, gdouble ex, gdouble ey, GitgChangedFile **file)
{
	GtkTreeViewColumn *column;
	gint x;
	gint y;
	
	gtk_tree_view_convert_widget_to_bin_window_coords(view, (gint)ex, (gint)ey, &x, &y);
	GtkTreePath *path;

	if (!gtk_tree_view_get_path_at_pos(view, x, y, &path, &column, NULL, NULL))
		return FALSE;
	
	if (column != gtk_tree_view_get_column(view, 0))
	{
		gtk_tree_path_free(path);
		return FALSE;
	}
	
	if (file)
	{
		GtkTreeModel *model = gtk_tree_view_get_model(view);
		GtkTreeIter iter;

		gtk_tree_model_get_iter(model, &iter, path);
		gtk_tree_model_get(model, &iter, COLUMN_FILE, file, -1);
	}
	
	gtk_tree_path_free(path);
	
	return TRUE;
}

static void
on_unstaged_button_press(GtkWidget *widget, GdkEventButton *event, GitgCommitView *view)
{
	GitgChangedFile *file;
	
	if (event->type != GDK_BUTTON_PRESS)
		return;

	if (event->button == 1 && column_icon_test(view->priv->tree_view_unstaged, event->x, event->y, &file))
	{
		gitg_commit_stage(view->priv->commit, file, NULL, NULL);
		g_object_unref(file);
	}
	else if (event->button == 3)
	{
		view->priv->context_type = CONTEXT_TYPE_FILE;
		popup_unstaged_menu(view, event);
	}
}

static void
on_staged_button_press(GtkWidget *widget, GdkEventButton *event, GitgCommitView *view)
{
	GitgChangedFile *file;
	
	if (event->type != GDK_BUTTON_PRESS)
		return;

	if (event->button == 1 && column_icon_test(view->priv->tree_view_staged, event->x, event->y, &file))
	{
		gitg_commit_unstage(view->priv->commit, file, NULL, NULL);
		g_object_unref(file);
	}
	else if (event->button == 3)
	{
		view->priv->context_type = CONTEXT_TYPE_FILE;
		popup_staged_menu(view, event);
	}
}

static gboolean
on_unstaged_motion(GtkWidget *widget, GdkEventMotion *event, GitgCommitView *view)
{
	if (column_icon_test(view->priv->tree_view_unstaged, event->x, event->y, NULL))
		gdk_window_set_cursor(widget->window, view->priv->hand);
	else
		gdk_window_set_cursor(widget->window, NULL);
	
	return FALSE;
}

static gboolean
on_staged_motion(GtkWidget *widget, GdkEventMotion *event, GitgCommitView *view)
{
	if (column_icon_test(view->priv->tree_view_staged, event->x, event->y, NULL))
		gdk_window_set_cursor(widget->window, view->priv->hand);
	else
		gdk_window_set_cursor(widget->window, NULL);

	return FALSE;
}

static gchar *
get_comment(GitgCommitView *view)
{
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(view->priv->comment_view);
	GtkTextIter start;
	GtkTextIter end;
	
	gtk_text_buffer_get_bounds(buffer, &start, &end);
	gchar *text = gtk_text_buffer_get_text(buffer, &start, &end, FALSE);
	gchar *ptr;
	
	for (ptr = text; *ptr; ptr = g_utf8_next_char(ptr))
		if (!g_unichar_isspace(g_utf8_get_char(ptr)))
			return text;
	
	g_free(text);
	return NULL;
}

static void
show_error(GitgCommitView *view, gchar const *error)
{
	GtkWidget *dlg = gtk_message_dialog_new(GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view))), GTK_DIALOG_MODAL | GTK_DIALOG_DESTROY_WITH_PARENT, GTK_MESSAGE_ERROR, GTK_BUTTONS_OK, "%s", error);

	gtk_dialog_run(GTK_DIALOG(dlg));
	gtk_widget_destroy(dlg);
}

static void 
on_commit_clicked(GtkButton *button, GitgCommitView *view)
{
	if (!gitg_commit_has_changes(view->priv->commit))
	{
		show_error(view, _("You must first stage some changes before committing"));
		return;
	}
	
	gchar *comment = get_comment(view);
	
	if (!comment)
	{
		show_error(view, _("Please enter a commit message before committing"));
		return;
	}
	
	gboolean signoff = gtk_toggle_button_get_active(GTK_TOGGLE_BUTTON(view->priv->check_button_signed_off_by));
	gboolean amend = gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (view->priv->check_button_amend));

	GError *error = NULL;
	
	if (!gitg_commit_commit(view->priv->commit, comment, signoff, amend, &error))
	{
		if (error && error->domain == GITG_COMMIT_ERROR && error->code == GITG_COMMIT_ERROR_SIGNOFF)
			show_error(view, _("Your user name or email could not be retrieved for use in the sign off message"));
		else
			show_error(view, _("Something went wrong while trying to commit"));
		
		if (error)
			g_error_free(error);
	}
	else
	{
		gtk_text_buffer_set_text(gtk_text_view_get_buffer(view->priv->comment_view), "", -1);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (view->priv->check_button_amend), FALSE);
		gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (view->priv->check_button_signed_off_by), FALSE);
	}
	
	g_free(comment);
}

static void 
on_context_value_changed(GtkHScale *scale, GitgCommitView *view)
{
	view->priv->context_size = (gint)gtk_range_get_value(GTK_RANGE(scale));
	
	if (view->priv->current_changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED)
		unstaged_selection_changed(gtk_tree_view_get_selection(view->priv->tree_view_unstaged), view);
	else if (view->priv->current_changes & GITG_CHANGED_FILE_CHANGES_CACHED)
		staged_selection_changed(gtk_tree_view_get_selection(view->priv->tree_view_staged), view);
}

static gboolean
set_unstaged_popup_status(GitgCommitView *view)
{
	GitgChangedFileChanges changes;
	GitgChangedFileStatus status;

	if (!get_selected_files(view->priv->tree_view_unstaged, NULL, NULL, &changes, &status))
		return FALSE;
	
	GtkAction *revert = gtk_ui_manager_get_action(view->priv->ui_manager, "/ui/popup_commit_stage/RevertChangesAction");
	GtkAction *ignore = gtk_ui_manager_get_action(view->priv->ui_manager, "/ui/popup_commit_stage/IgnoreFileAction");
	gboolean isnew = status == GITG_CHANGED_FILE_STATUS_NEW;

	gtk_action_set_visible(revert, !isnew);
	gtk_action_set_visible(ignore, isnew);
	
	return TRUE;
}

static gboolean
set_staged_popup_status(GitgCommitView *view)
{
	if (!get_selected_files(view->priv->tree_view_staged, NULL, NULL, NULL, NULL))
		return FALSE;
	
	return TRUE;	
}

static gboolean
popup_unstaged_menu(GitgCommitView *view, GdkEventButton *event)
{
	if (!set_unstaged_popup_status(view))
		return FALSE;

	GtkWidget *wd = gtk_ui_manager_get_widget(view->priv->ui_manager, "/ui/popup_commit_stage");
	
	view->priv->context_type = CONTEXT_TYPE_FILE;
	
	if (event)
	{
		gtk_menu_popup(GTK_MENU(wd), NULL, NULL, NULL, NULL, event->button, event->time);
	}
	else
	{
		gtk_menu_popup(GTK_MENU(wd), NULL, NULL, 
					   gitg_utils_menu_position_under_tree_view, 
					   view->priv->tree_view_staged, 0, 
					   gtk_get_current_event_time());
	}
		
	return TRUE;
}

static gboolean 
popup_staged_menu(GitgCommitView *view, GdkEventButton *event)
{
	if (!set_staged_popup_status(view))
		return FALSE;

	GtkWidget *wd = gtk_ui_manager_get_widget(view->priv->ui_manager, "/ui/popup_commit_unstage");
	
	view->priv->context_type = CONTEXT_TYPE_FILE;
	
	if (event)
	{
		gtk_menu_popup(GTK_MENU(wd), NULL, NULL, NULL, NULL, event->button, event->time);
	}
	else
	{
		gtk_menu_popup(GTK_MENU(wd), NULL, NULL, 
					   gitg_utils_menu_position_under_tree_view, 
					   view->priv->tree_view_unstaged, 0, 
					   gtk_get_current_event_time());
	}
		
	return TRUE;
}


static gboolean 
on_unstaged_popup_menu(GtkWidget *widget, GitgCommitView *view)
{
	return popup_unstaged_menu(view, NULL);
}

static gboolean 
on_staged_popup_menu(GtkWidget *widget, GitgCommitView *view)
{
	return popup_staged_menu(view, NULL);
}

static void 
on_stage_changes(GtkAction *action, GitgCommitView *view)
{
	if (view->priv->context_type == CONTEXT_TYPE_FILE)
	{
		GitgChangedFile *file = view->priv->current_file;
		
		if (!file)
			return;
		
		gitg_commit_stage(view->priv->commit, file, NULL, NULL);
	}
	else
	{
		handle_stage_unstage(view, &view->priv->context_iter);
	}
}

static void
do_revert_changes(GitgCommitView *view)
{
	gboolean ret;
	
	if (view->priv->context_type == CONTEXT_TYPE_FILE)
	{
		ret = gitg_commit_revert(view->priv->commit, view->priv->current_file, NULL, NULL);
	}
	else
	{
		GitgChangedFile *file = g_object_ref(view->priv->current_file);

		gchar *hunk = get_hunk_patch(view, &view->priv->context_iter);
		ret = gitg_commit_revert(view->priv->commit, view->priv->current_file, hunk, NULL);
		g_free(hunk);
		
		if (ret && view->priv->current_file == file)
			gitg_diff_view_remove_hunk(GITG_DIFF_VIEW(view->priv->changes_view), &view->priv->context_iter);
		
		g_object_unref(file);
	}
	
	if (!ret)
		show_error(view, _("Revert fail"));
}

static void 
on_revert_changes(GtkAction *action, GitgCommitView *view)
{
	GtkWidget *dialog = gtk_message_dialog_new(GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view))),
											   GTK_DIALOG_MODAL,
											   GTK_MESSAGE_QUESTION,
											   GTK_BUTTONS_YES_NO,
											   "%s",
											   _("Are you sure you want to revert these changes?"));

	gtk_message_dialog_format_secondary_text(GTK_MESSAGE_DIALOG(dialog), "%s", 
											 _("Reverting changes is permanent and cannot be undone"));

	gint response = gtk_dialog_run(GTK_DIALOG(dialog));
	
	if (response == GTK_RESPONSE_YES)
		do_revert_changes(view);
	
	gtk_widget_destroy(dialog);
}

static void 
on_ignore_file(GtkAction *action, GitgCommitView *view)
{
	gitg_commit_add_ignore(view->priv->commit, view->priv->current_file, NULL);
}

static void 
on_unstage_changes(GtkAction *action, GitgCommitView *view)
{
	if (view->priv->context_type == CONTEXT_TYPE_FILE)
	{
		GitgChangedFile *file = view->priv->current_file;
		
		if (!file)
			return;
		
		gitg_commit_unstage(view->priv->commit, file, NULL, NULL);
	}
	else
	{
		handle_stage_unstage(view, &view->priv->context_iter);
	}
}

GtkWidget *
create_context_menu_item(GitgCommitView *view, gchar const *action)
{
	GtkAction *ac = gtk_action_group_get_action(view->priv->group_context, action);
	return gtk_action_create_menu_item(ac);
}

static void 
on_changes_view_popup_menu(GtkTextView *textview, GtkMenu *menu, GitgCommitView *view)
{
	/* check the hunk */
	if (!get_hunk_at_pointer(view, &view->priv->context_iter, NULL))
		return;
	
	GtkWidget *separator = gtk_separator_menu_item_new();
	gtk_widget_show(separator);

	view->priv->context_type = CONTEXT_TYPE_HUNK;

	gtk_menu_shell_append(GTK_MENU_SHELL(menu), separator);
	
	if (view->priv->current_changes & GITG_CHANGED_FILE_CHANGES_CACHED)
	{
		GtkWidget *unstage = create_context_menu_item(view, "UnstageChangesAction");
		gtk_menu_shell_append(GTK_MENU_SHELL(menu), unstage);
	}
	else
	{
		GtkWidget *stage = create_context_menu_item(view, "StageChangesAction");
		GtkWidget *revert = create_context_menu_item(view, "RevertChangesAction");
		
		gtk_menu_shell_append(GTK_MENU_SHELL(menu), stage);
		gtk_menu_shell_append(GTK_MENU_SHELL(menu), revert);
	}
}

static void
on_check_button_amend_toggled (GtkToggleButton *button, GitgCommitView *view)
{
	gboolean active = gtk_toggle_button_get_active (button);
	GtkTextBuffer *buffer = gtk_text_view_get_buffer (view->priv->comment_view);
	GtkTextIter start;
	GtkTextIter end;
	
	gtk_text_buffer_get_bounds (buffer, &start, &end);
	
	if (active && gtk_text_iter_compare (&start, &end) == 0)
	{
		// Get last commit message
		gchar *message = gitg_commit_amend_message (view->priv->commit);
		
		if (message)
		{
			gtk_text_buffer_set_text (buffer, message, -1);
		}
		
		g_free (message);
	}
}
