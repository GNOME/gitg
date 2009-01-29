#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <glib/gi18n.h>

#include "gitg-commit-view.h"
#include "gitg-commit.h"
#include "gitg-utils.h"

#define GITG_COMMIT_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_COMMIT_VIEW, GitgCommitViewPrivate))
#define CATEGORY_HUNK "CategoryHunk"

/* Properties */
enum
{
	PROP_0,
	PROP_REPOSITORY
};

enum
{
	COLUMN_NAME = 0,
	COLUMN_FILE,
	N_COLUMNS
};

struct _GitgCommitViewPrivate
{
	GitgCommit *commit;
	GitgRepository *repository;
	
	GtkListStore *store_unstaged;
	GtkListStore *store_staged;
	
	GtkSourceView *changes_view;
	GtkTextView *comment_view;
	
	GitgRunner *runner;
	guint update_id;
	gboolean is_diff;
	
	GtkTextTag *hunk_tag;
	GdkCursor *hand;
};

static void gitg_commit_view_buildable_iface_init(GtkBuildableIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgCommitView, gitg_commit_view, GTK_TYPE_HPANED, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, gitg_commit_view_buildable_iface_init));

static GtkBuildableIface parent_iface;

static void on_commit_file_inserted(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view);
static void on_commit_file_removed(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view);

static void
gitg_commit_view_finalize(GObject *object)
{
	GitgCommitView *view = GITG_COMMIT_VIEW(object);
	
	if (view->priv->update_id)
		g_signal_handler_disconnect(view->priv->runner, view->priv->update_id);
	
	gitg_runner_cancel(view->priv->runner);
	g_object_unref(view->priv->runner);
	
	G_OBJECT_CLASS(gitg_commit_view_parent_class)->finalize(object);
}

static void
icon_data_func(GtkTreeViewColumn *column, GtkCellRenderer *renderer, GtkTreeModel *model, GtkTreeIter *iter, GitgCommitView *view)
{
	GitgChangedFile *file;
	
	gtk_tree_model_get(model, iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	GitgChangedFileChanges changes = gitg_changed_file_get_changes(file);
	
	gboolean staged = changes == GITG_CHANGED_FILE_CHANGES_CACHED;
	
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
}

static void
set_diff_language(GitgCommitView *view)
{
	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default();
	GtkSourceLanguage *language = gtk_source_language_manager_get_language(manager, "diff");

	set_language(view, language);
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
			gtk_source_buffer_create_source_mark(GTK_SOURCE_BUFFER(buf), NULL, CATEGORY_HUNK, &iter);
			gtk_text_buffer_insert_with_tags_by_name(buf, &iter, line, -1, "hunk", NULL);
		}
		else
		{
			gtk_text_buffer_insert(buf, &iter, line, -1);
		}
		
		gtk_text_buffer_insert(buf, &iter, "\n", -1);
	}
}

static void
run_changes_command(GitgCommitView *view, gchar const **argv, gchar const *wd)
{
	view->priv->update_id = g_signal_connect(view->priv->runner, "update", G_CALLBACK(on_changes_update), view);
	gitg_runner_run_working_directory(view->priv->runner, argv, wd, NULL);
}

static gboolean
check_selection(GtkTreeSelection *selection, GtkTreeModel **model, GtkTreeIter *iter, GitgCommitView *view)
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
	gtk_source_buffer_remove_source_marks(GTK_SOURCE_BUFFER(buffer), &start, &end, CATEGORY_HUNK);
	gtk_text_buffer_set_text(gtk_text_view_get_buffer(tv), "", -1);
	
	if (!gtk_tree_selection_get_selected(selection, model, iter))
		return FALSE;
	
	return TRUE;
}

static void
unstaged_selection_changed(GtkTreeSelection *selection, GitgCommitView *view)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	
	if (!check_selection(selection, &model, &iter, view))
		return;
	
	GitgChangedFile *file;
	
	gtk_tree_model_get(model, &iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	GFile *f = gitg_changed_file_get_file(file);

	if (status == GITG_CHANGED_FILE_STATUS_NEW)
	{
		gchar *content_type = gitg_utils_get_content_type(f);
		
		if (!content_type)
		{
			gtk_text_buffer_set_text(gtk_text_view_get_buffer(GTK_TEXT_VIEW(view->priv->changes_view)), _("Cannot display file content as text"), -1);
		}
		else
		{
			gchar *path = g_file_get_path(f);	

			/* This is really ugly! */
			gchar const *argv[] = {"cat", path, NULL};
			GtkSourceLanguage *language = gitg_utils_get_language(content_type);
			
			set_language(view, language);
			view->priv->is_diff = FALSE;
			run_changes_command(view, argv, NULL);
			
			g_free(path);
		}
	}
	else
	{
		gchar const *repos = gitg_repository_get_path(view->priv->repository);
		GFile *parent = g_file_new_for_path(repos);
		gchar *rel = g_file_get_relative_path(parent, f);
		g_object_unref(parent);
		
		gchar *dotgit = gitg_utils_dot_git_path(repos);
		set_diff_language(view);
		view->priv->is_diff = TRUE;

		gchar const *argv[] = {"git", "--git-dir", dotgit, "diff", "--", rel, NULL};
		run_changes_command(view, argv, repos);
		
		g_free(dotgit);
		g_free(rel);
	}

	g_object_unref(f);	
	g_object_unref(file);	
}

static void
staged_selection_changed(GtkTreeSelection *selection, GitgCommitView *view)
{
	GtkTreeModel *model;
	GtkTreeIter iter;
	
	if (!check_selection(selection, &model, &iter, view))
		return;
	
	GitgChangedFile *file;
	
	gtk_tree_model_get(model, &iter, COLUMN_FILE, &file, -1);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);
	GFile *f = gitg_changed_file_get_file(file);

	gchar *dotgit = gitg_utils_dot_git_path(gitg_repository_get_path(view->priv->repository));
	gchar *path = g_file_get_path(f);
	g_object_unref(f);
	
	set_diff_language(view);
	
	if (status == GITG_CHANGED_FILE_STATUS_NEW)
	{
		gchar *indexpath = g_strconcat(":0:", path, NULL);
		gchar const *argv[] = {"git", "--git-dir", dotgit, "show", indexpath, NULL};
		view->priv->is_diff = FALSE;
		
		run_changes_command(view, argv, NULL);
		g_free(indexpath);
	}
	else
	{
		gchar const *argv[] = {"git", "--git-dir", dotgit, "diff-index", "-U3", "--cached", "HEAD", "--", path, NULL};
		view->priv->is_diff = TRUE;

		run_changes_command(view, argv, gitg_repository_get_path(view->priv->repository));
	}

	g_free(path);	
	g_free(dotgit);
	
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
view_event(GtkWidget *widget, GdkEventMotion *event, GitgCommitView *view)
{
	GtkTextWindowType type;
	GtkTextIter iter;
	GdkWindow *win;
	gint x, y, buf_x, buf_y;

	type = gtk_text_view_get_window_type(GTK_TEXT_VIEW(widget), event->window);

	if (type != GTK_TEXT_WINDOW_TEXT)
		return FALSE;

	if (event->type != GDK_MOTION_NOTIFY)
		return FALSE;

	/* Get where the pointer really is. */
	win = gtk_text_view_get_window(GTK_TEXT_VIEW(widget), type);
	gdk_window_get_pointer(win, &x, &y, NULL);

	/* Get the iter where the cursor is at */
	gtk_text_view_window_to_buffer_coords(GTK_TEXT_VIEW(widget), type, x, y, &buf_x, &buf_y);
	gtk_text_view_get_iter_at_location(GTK_TEXT_VIEW(widget), &iter, buf_x, buf_y);

	if (gtk_text_iter_backward_line(&iter))
		gtk_text_iter_forward_line(&iter);

	gboolean has_tag = gtk_text_iter_has_tag(&iter, view->priv->hunk_tag);
		
	if (has_tag && !view->priv->hand)
	{
		view->priv->hand = gdk_cursor_new(GDK_HAND1);
		gdk_window_set_cursor(win, view->priv->hand);
	} 
	else if (!has_tag && view->priv->hand)
	{
		gdk_window_set_cursor(win, NULL);
		gdk_cursor_unref(view->priv->hand);
		
		view->priv->hand = NULL;
	}

	return FALSE;
}

static gboolean
hunk_tag_event(GtkTextTag *tag, GObject *object, GdkEvent *event, GtkTextIter *iter, GitgCommitView *view)
{
	return FALSE;
}

static GtkTextBuffer *
initialize_buffer(GitgCommitView *view)
{
	GtkTextBuffer *buffer = GTK_TEXT_BUFFER(gtk_source_buffer_new(NULL));
	
	view->priv->hunk_tag = gtk_text_buffer_create_tag(buffer, "hunk", "paragraph-background", "#FF0", "background-full-height", TRUE, NULL);
	
	g_signal_connect(view->priv->hunk_tag, "event", G_CALLBACK(hunk_tag_event), view);
	return buffer;
}

static void
gitg_commit_view_parser_finished(GtkBuildable *buildable, GtkBuilder *builder)
{
	if (parent_iface.parser_finished)
		parent_iface.parser_finished(buildable, builder);

	/* Store widgets */
	GitgCommitView *self = GITG_COMMIT_VIEW(buildable);
	
	GtkTreeView *tree_view_unstaged = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_unstaged"));
	GtkTreeView *tree_view_staged = GTK_TREE_VIEW(gtk_builder_get_object(builder, "tree_view_staged"));
	
	self->priv->store_unstaged = gtk_list_store_new(N_COLUMNS, G_TYPE_STRING, GITG_TYPE_CHANGED_FILE);
	self->priv->store_staged = gtk_list_store_new(N_COLUMNS, G_TYPE_STRING, GITG_TYPE_CHANGED_FILE);
	
	set_sort_func(self->priv->store_unstaged);
	set_sort_func(self->priv->store_staged);
	
	self->priv->changes_view = GTK_SOURCE_VIEW(gtk_builder_get_object(builder, "source_view_changes"));
	self->priv->comment_view = GTK_TEXT_VIEW(gtk_builder_get_object(builder, "text_view_comment"));
	
	GtkIconTheme *theme = gtk_icon_theme_get_default();
	GdkPixbuf *pixbuf = gtk_icon_theme_load_icon(theme, GTK_STOCK_ADD, 12, GTK_ICON_LOOKUP_USE_BUILTIN, NULL);
	
	if (pixbuf)
	{
		gtk_source_view_set_mark_category_pixbuf(self->priv->changes_view, CATEGORY_HUNK, pixbuf);
		g_object_unref(pixbuf);
		
		gtk_source_view_set_show_line_marks(self->priv->changes_view, TRUE);
	}
	
	GtkTextBuffer *buffer = initialize_buffer(self);
	gtk_text_view_set_buffer(GTK_TEXT_VIEW(self->priv->changes_view), buffer);
	g_signal_connect(self->priv->changes_view, "event", G_CALLBACK(view_event), self);
	
	gtk_tree_view_set_model(tree_view_unstaged, GTK_TREE_MODEL(self->priv->store_unstaged));
	gtk_tree_view_set_model(tree_view_staged, GTK_TREE_MODEL(self->priv->store_staged));
	
	set_icon_data_func(self, tree_view_unstaged, GTK_CELL_RENDERER(gtk_builder_get_object(builder, "unstaged_cell_renderer_icon")));
	set_icon_data_func(self, tree_view_staged, GTK_CELL_RENDERER(gtk_builder_get_object(builder, "staged_cell_renderer_icon")));
	
	g_signal_connect(gtk_tree_view_get_selection(tree_view_unstaged), "changed", G_CALLBACK(unstaged_selection_changed), self);
	g_signal_connect(gtk_tree_view_get_selection(tree_view_staged), "changed", G_CALLBACK(staged_selection_changed), self);
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

	g_type_class_add_private(object_class, sizeof(GitgCommitViewPrivate));
}

static void
gitg_commit_view_init(GitgCommitView *self)
{
	self->priv = GITG_COMMIT_VIEW_GET_PRIVATE(self);
	
	self->priv->runner = gitg_runner_new(100);
}

void 
gitg_commit_view_set_repository(GitgCommitView *view, GitgRepository *repository)
{
	g_return_if_fail(GITG_IS_COMMIT_VIEW(view));
	g_return_if_fail(GITG_IS_REPOSITORY(repository));

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
static void
on_commit_file_inserted(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view)
{
	if (gitg_changed_file_get_changes(file) & GITG_CHANGED_FILE_CHANGES_UNSTAGED)
	{
		append_file(view->priv->store_unstaged, file, view);
	}
	else
	{
		append_file(view->priv->store_staged, file, view);
	}
}

static void
on_commit_file_removed(GitgCommit *commit, GitgChangedFile *file, GitgCommitView *view)
{
}

