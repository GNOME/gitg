#include <gtksourceview/gtksourceview.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <string.h>

#include "gitg-revision-view.h"
#include "gitg-runner.h"
#include "gitg-utils.h"

#define GITG_REVISION_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_REVISION_VIEW, GitgRevisionViewPrivate))

/* Signals */
enum
{
	PARENT_ACTIVATED,
	NUM_SIGNALS
};

static guint signals[NUM_SIGNALS];

struct _GitgRevisionViewPrivate
{
	GtkLabel *sha;
	GtkLabel *author;
	GtkLabel *date;
	GtkLabel *subject;
	GtkVBox *parents;
	GtkSourceView *diff;
	
	GitgRunner *diff_runner;
};

static void gitg_revision_view_buildable_iface_init(GtkBuildableIface *iface);

G_DEFINE_TYPE_EXTENDED(GitgRevisionView, gitg_revision_view, GTK_TYPE_VBOX, 0,
	G_IMPLEMENT_INTERFACE(GTK_TYPE_BUILDABLE, gitg_revision_view_buildable_iface_init));

static GtkBuildableIface parent_iface = {0,};

static void
update_markup(GObject *object)
{
	GtkLabel *label = GTK_LABEL(object);
	gchar const *text = gtk_label_get_text(label);
	
	gchar *newtext = g_strconcat("<span weight='bold' foreground='#777'>", text, "</span>", NULL);

	gtk_label_set_markup(label, newtext);
	g_free(newtext);
}

static void
gitg_revision_view_parser_finished(GtkBuildable *buildable, GtkBuilder *builder)
{
	if (parent_iface.parser_finished)
		parent_iface.parser_finished(buildable, builder);

	GitgRevisionView *rvv = GITG_REVISION_VIEW(buildable);

	rvv->priv->sha = GTK_LABEL(gtk_builder_get_object(builder, "label_sha"));
	rvv->priv->author = GTK_LABEL(gtk_builder_get_object(builder, "label_author"));
	rvv->priv->date = GTK_LABEL(gtk_builder_get_object(builder, "label_date"));
	rvv->priv->subject = GTK_LABEL(gtk_builder_get_object(builder, "label_subject"));
	rvv->priv->parents = GTK_VBOX(gtk_builder_get_object(builder, "vbox_parents"));
	rvv->priv->diff = GTK_SOURCE_VIEW(gtk_builder_get_object(builder, "revision_diff"));
	
	GtkSourceLanguageManager *manager = gtk_source_language_manager_get_default();
	GtkSourceLanguage *language = gtk_source_language_manager_get_language(manager, "diff");
	GtkSourceBuffer *buffer = gtk_source_buffer_new_with_language(language);
	g_object_unref(language);
	
	gtk_text_view_set_buffer(GTK_TEXT_VIEW(rvv->priv->diff), GTK_TEXT_BUFFER(buffer));

	gchar const *lbls[] = {
		"label_subject_lbl",
		"label_author_lbl",
		"label_sha_lbl",
		"label_date_lbl",
		"label_parent_lbl"
	};
	
	int i;
	for (i = 0; i < sizeof(lbls) / sizeof(gchar *); ++i)
		update_markup(gtk_builder_get_object(builder, lbls[i]));
}

static void
gitg_revision_view_buildable_iface_init(GtkBuildableIface *iface)
{
	parent_iface = *iface;
	
	iface->parser_finished = gitg_revision_view_parser_finished;
}

static void
gitg_revision_view_finalize(GObject *object)
{
	GitgRevisionView *self = GITG_REVISION_VIEW(object);
	
	gitg_runner_cancel(self->priv->diff_runner);
	g_object_unref(self->priv->diff_runner);

	G_OBJECT_CLASS(gitg_revision_view_parent_class)->finalize(object);
}

static void
gitg_revision_view_class_init(GitgRevisionViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_revision_view_finalize;
	
	signals[PARENT_ACTIVATED] =
		g_signal_new("parent-activated",
			G_OBJECT_CLASS_TYPE (object_class),
			G_SIGNAL_RUN_LAST,
			G_STRUCT_OFFSET (GitgRevisionViewClass, parent_activated),
			NULL, NULL,
			g_cclosure_marshal_VOID__POINTER,
			G_TYPE_NONE,
			1, G_TYPE_POINTER);
	
	g_type_class_add_private(object_class, sizeof(GitgRevisionViewPrivate));
}

static void
on_diff_begin_loading(GitgRunner *runner, GitgRevisionView *self)
{
	GdkCursor *cursor = gdk_cursor_new(GDK_WATCH);
	gdk_window_set_cursor(GTK_WIDGET(self->priv->diff)->window, cursor);
	gdk_cursor_unref(cursor);
}

static void
on_diff_end_loading(GitgRunner *runner, GitgRevisionView *self)
{
	gdk_window_set_cursor(GTK_WIDGET(self->priv->diff)->window, NULL);
}

static void
on_diff_update(GitgRunner *runner, gchar **buffer, GitgRevisionView *self)
{
	gchar *line;
	GtkTextBuffer *buf = gtk_text_view_get_buffer(GTK_TEXT_VIEW(self->priv->diff));
	GtkTextIter iter;
	
	gtk_text_buffer_get_end_iter(buf, &iter);
	
	while ((line = *buffer++))
		gtk_text_buffer_insert(buf, &iter, line, -1);
}

static void
gitg_revision_view_init(GitgRevisionView *self)
{
	self->priv = GITG_REVISION_VIEW_GET_PRIVATE(self);
	
	self->priv->diff_runner = gitg_runner_new(2000);
	
	g_signal_connect(self->priv->diff_runner, "begin-loading", G_CALLBACK(on_diff_begin_loading), self);
	g_signal_connect(self->priv->diff_runner, "update", G_CALLBACK(on_diff_update), self);
	g_signal_connect(self->priv->diff_runner, "end-loading", G_CALLBACK(on_diff_end_loading), self);
}

#define HASH_KEY "GitgRevisionViewHashKey"

static gboolean
on_parent_clicked(GtkWidget *ev, GdkEventButton *event, gpointer userdata)
{
	if (event->button != 1)
		return FALSE;
	
	GitgRevisionView *rvv = GITG_REVISION_VIEW(userdata);
	
	gchar *hash = (gchar *)g_object_get_data(G_OBJECT(ev), HASH_KEY);
	g_signal_emit(rvv, signals[PARENT_ACTIVATED], 0, hash);

	return FALSE;
}

static GtkWidget *
make_parent_label(GitgRevisionView *self, gchar *hash)
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
	
	g_object_set_data_full(G_OBJECT(ev), HASH_KEY, (gpointer)gitg_utils_sha1_to_hash_new(hash), (GDestroyNotify)g_free);
	g_signal_connect(ev, "button-release-event", G_CALLBACK(on_parent_clicked), self);

	return ev;
}

static void
update_parents(GitgRevisionView *self, GitgRevision *revision)
{
	GList *children = gtk_container_get_children(GTK_CONTAINER(self->priv->parents));
	GList *item;
	
	for (item = children; item; item = item->next)
		gtk_container_remove(GTK_CONTAINER(self->priv->parents), GTK_WIDGET(item->data));
	
	g_list_free(children);
	
	if (!revision)
		return;
	
	gchar **parents = gitg_revision_get_parents(revision);
	gchar **ptr;
	
	for (ptr = parents; *ptr; ++ptr)
	{
		GtkWidget *widget = make_parent_label(self, *ptr);
		gtk_box_pack_start(GTK_BOX(self->priv->parents), widget, FALSE, TRUE, 0);
		
		gtk_widget_realize(widget);
		GdkCursor *cursor = gdk_cursor_new(GDK_HAND1);
		gdk_window_set_cursor(widget->window, cursor);
		gdk_cursor_unref(cursor);
	}
	
	g_strfreev(parents);	
}

static void
update_diff(GitgRevisionView *self, GitgRepository *repository, GitgRevision *revision)
{	
	// First cancel a possibly still running diff
	gitg_runner_cancel(self->priv->diff_runner);
	
	// Clear the buffer
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(self->priv->diff));
	gtk_text_buffer_set_text(buffer, "", 0);
	
	if (!revision)
		return;

	gchar *hash = gitg_revision_get_sha1(revision);

	gchar *argv[] = {
		"git",
		"--git-dir",
		gitg_utils_dot_git_path(gitg_repository_get_path(repository)),
		"show",
		"--pretty=format:%s%n%n%b",
		"--encoding=UTF-8",
		hash,
		NULL
	};
	
	gitg_runner_run(self->priv->diff_runner, argv, NULL);

	g_free(hash);
	g_free(argv[2]);
}

static gchar *
format_date(GitgRevision *revision)
{
	guint64 timestamp = gitg_revision_get_timestamp(revision);
	char *ptr = ctime((time_t *)&timestamp);
	
	// Remove newline?
	ptr[strlen(ptr) - 1] = '\0';
	
	return ptr;
}

void
gitg_revision_view_update(GitgRevisionView *self, GitgRepository *repository, GitgRevision *revision)
{
	g_return_if_fail(GITG_IS_REVISION_VIEW(self));

	// Update labels
	if (revision)
	{
		gtk_label_set_text(self->priv->author, gitg_revision_get_author(revision));

		gchar *subject = g_strconcat("<b>", gitg_revision_get_subject(revision), "</b>", NULL);
		gtk_label_set_markup(self->priv->subject, subject);
		g_free(subject);

		gtk_label_set_text(self->priv->date, format_date(revision));
	
		gchar *sha = gitg_revision_get_sha1(revision);
		gtk_label_set_text(self->priv->sha, sha);
		g_free(sha);
	}
	else
	{
		gtk_label_set_text(self->priv->author, "");
		gtk_label_set_text(self->priv->subject, "");
		gtk_label_set_text(self->priv->date, "");
		gtk_label_set_text(self->priv->sha, "");
	}
	
	// Update parents
	update_parents(self, revision);
	
	// Update diff
	update_diff(self, repository, revision);
}
