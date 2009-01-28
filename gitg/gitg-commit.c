#include "gitg-commit.h"
#include "gitg-runner.h"
#include "gitg-utils.h"

#define GITG_COMMIT_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_COMMIT, GitgCommitPrivate))

/* Properties */
enum
{
	PROP_0,
	PROP_REPOSITORY
};

struct _GitgCommitPrivate
{
	GitgRepository *repository;
	GitgRunner *runner;
	guint update_id;
	guint end_id;
	gchar *dotgit;
};

G_DEFINE_TYPE(GitgCommit, gitg_commit, G_TYPE_OBJECT)

static void
runner_cancel(GitgCommit *commit)
{
	if (commit->priv->update_id)
	{
		g_signal_handler_disconnect(commit->priv->runner, commit->priv->update_id);
		commit->priv->update_id = 0;
	}

	if (commit->priv->end_id)
	{
		g_signal_handler_disconnect(commit->priv->runner, commit->priv->end_id);
		commit->priv->update_id = 0;
	}

	gitg_runner_cancel(commit->priv->runner);
}

static void
gitg_commit_finalize(GObject *object)
{
	GitgCommit *commit = GITG_COMMIT(object);
	
	runner_cancel(commit);
	g_object_unref(commit->priv->runner);

	g_free(commit->priv->dotgit);
	
	G_OBJECT_CLASS(gitg_commit_parent_class)->finalize(object);
}

static void
gitg_commit_dispose(GtkObject *object)
{
	GitgCommit *self = GITG_COMMIT(object);
	
	if (self->priv->repository)
	{
		g_object_unref(self->priv->repository);
		self->priv->repository = NULL;
	}
}

static void
gitg_commit_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgCommit *self = GITG_COMMIT(object);

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
gitg_commit_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgCommit *self = GITG_COMMIT(object);
	
	switch (prop_id)
	{
		case PROP_REPOSITORY:
			self->priv->repository = g_value_get_object(value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static GObject * 
gitg_constructor(GType type, guint n_construct_properties, GObjectConstructParam *construct_properties)
{
	GObject *ret = G_OBJECT_CLASS(gitg_commit_parent_class)->constructor(type, n_construct_properties, construct_properties);
	GitgCommit *commit = GITG_COMMIT(ret);
	
	commit->priv->dotgit = gitg_utils_dot_git_path(gitg_repository_get_path(commit->priv->repository));

	return ret;
}

static void
gitg_commit_class_init(GitgCommitClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);

	widget_class->destroy = gitg_commit_dispose;
	object_class->finalize = gitg_commit_finalize;
	object_class->constructor = gitg_constructor;

	g_object_class_install_property(object_class, PROP_REPOSITORY,
					 g_param_spec_object("repository",
							      "REPOSITORY",
							      "Repository",
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));

	g_type_class_add_private(object_class, sizeof(GitgCommitPrivate));
}

static void
gitg_commit_init(GitgCommit *self)
{
	self->priv = GITG_COMMIT_GET_PRIVATE(self);
	
	self->priv->runner = gitg_runner_new(5000);
}

GitgCommit *
gitg_commit_new(GitgRepository *repository)
{
	return g_object_new(GITG_TYPE_COMMIT, "repository", repository, NULL);
}

static void
runner_connect(GitgCommit *commit, GCallback updatefunc, GCallback endfunc)
{
	if (commit->priv->update_id)
	{
		g_signal_handler_disconnect(commit->priv->runner, commit->priv->update_id);
		commit->priv->update_id = 0;
	}
	
	if (commit->priv->end_id)
	{
		g_signal_handler_disconnect(commit->priv->runner, commit->priv->end_id);
		commit->priv->end_id = 0;
	}

	if (updatefunc)
		commit->priv->update_id = g_signal_connect(commit->priv->runner, "update", updatefunc, commit);
	
	if (endfunc)
		commit->priv->end_id = g_signal_connect(commit->priv->runner, "end-loading", endfunc, commit);
}

static void
gitg_changed_file_free(GitgChangedFile *f)
{
	g_free(f->commit_blob_mode);
	g_free(f->commit_blob_sha);
	g_object_unref(f->file);
	
	g_slice_free(GitgChangedFile, f);
}

static GitgChangedFile *
gitg_changed_file_new(GFile *file)
{
	GitgChangedFile *f = g_slice_alloc0(GitgChangedFile);
	
	f->file = g_object_ref(file);
	return f;
}

static void
add_files(GitgCommit *commit, gchar **buffer, gboolean cached)
{
	gchar *line;
	
	while (line = *buffer++)
	{
		gchar **parts = g_strsplit(line, " ", 0);
		
		gchar const *mode = parts[0] + 1;
		gchar const *sha = parts[2];
		GSList *item;
		
		bool new = TRUE;
		gchar *path = g_build_filename(gitg_repository_get_path(commit->priv->repository), line, NULL);
		
		GFile *file = g_file_new_for_path(path);
		g_free(path);

		for (item = commit->priv->files; item; item = item->next)
		{
			GitgChangedFile *f = (GitgChangedFile *)item->data;
			
			if (g_file_equal(f->file, file))
			{
				f->deleted = FALSE;
				
				if (cached)
				{
					g_free (f->commit_blob_sha);
					g_free (f->commit_blob_mode);
					
					f->commit_blob_sha = g_strdup(sha);
					f->commit_blob_mode = g_strdup(mode);
					
					f->cached_changes = TRUE;
				}
				else
				{
					f->unstanged_changes = TRUE;
				}
				
				new = FALSE;
				break;
			}
		}
		
		if (!new)
		{
			g_object_unref(file);
			g_strfreev(parts);
			continue;
		}
		
		GitgChangedFile *f = gitg_changed_file_new(file);
		g_object_unref(file);
		
		if (strcmp(parts[4], "M") == 0)
			f->status = GITG_CHANGED_FILE_STATUS_DELETED;
		else if (strcmp(mode, "000000") == 0)
			f->status = GITG_CHANGED_FILE_STATUS_NEW;
		else
			f->status = GITG_CHANGED_FILE_STATUS_MODIFIED;

		f->commit_blob_sha = g_strdup(sha);
		f->commit_blob_mode = g_strdup(mode);
		
		f->cached_changes = cached;
		f->unstanged_changes = !cached;
		
		commit->priv->files = g_slist_prepend(commit->priv->files, f);
		g_strfreev(parts);
	}
}

static void
read_cached_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	add_files(commit, buffer, TRUE);
}

static void
read_unstaged_files_end(GitgRunner *runner, GitgCommit *commit)
{
	/* FIXME: something with having no head ref... */
	static gchar const *argv[] = {"git", "--git-dir", NULL, "diff-index", "--cached", "HEAD", NULL};
	gitg_runner_cancel(runner);
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, G_CALLBACK(read_cached_files_update), NULL);
	
	gitg_runner_run(commit->priv->runner, argv, NULL);
}

static void
read_unstaged_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	add_files(commit, buffer, FALSE);
}

static void
read_other_files_end(GitgRunner *runner, GitgCommit *commit)
{
	static gchar const *argv[] = {"git", "--git-dir", NULL, "diff-files", NULL};
	gitg_runner_cancel(runner);
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, G_CALLBACK(read_unstaged_files_update), G_CALLBACK(read_unstaged_files_end));
	
	gitg_runner_run(commit->priv->runner, argv, NULL);
}

static void
changed_file_new(GitgChangedFile *f)
{
	f->deleted = FALSE;
	f->status = GITG_CHANGED_FILE_STATUS_NEW;
	f->cached_changes = FALSE;
	f->unstanged_changes = TRUE;
}

static void
read_other_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	gchar *line;

	while ((line = *buffer++))
	{
		/* Skip empty lines */
		if (!*line)
			continue;
			
		/* Check if file is already in our index */
		gboolean added = FALSE;
		GSList *item;
		gchar *path = g_build_filename(gitg_repository_get_path(commit->priv->repository), line, NULL);
		
		GFile *file = g_file_new_for_path(path);
		g_free(path);
		
		for (item = commit->priv->files; item; item = item->next)
		{
			GitgChangedFile *f = (GitgChangedFile *)item->data;

			if (g_file_equal(f->file, file))
			{
				added = TRUE;
				changed_file_new(f);
				continue;
			}
		}
		
		if (added)
		{
			g_object_unref(file);
			continue;
		}
		
		GitgChangedFile *f = gitg_changed_file_new(file);

		changed_file_new(f);
		g_object_unref(file);
		
		commit->priv->files = g_slist_prepend(commit->priv->files, f);
	}
}

static void
update_index_end(GitgRunner *runner, GitgCommit *commit)
{
	static gchar const *argv[] = {"git", "--git-dir", NULL, "ls-files", "--others", "--exclude-standard", NULL};
	gitg_runner_cancel(runner);
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, G_CALLBACK(read_other_files_update), G_CALLBACK(read_other_files_end));
	
	gitg_runner_run(commit->priv->runner, argv, NULL);
}

static void
update_index(GitgCommit *commit)
{
	static gchar const *argv[] = {"git", "--git-dir", NULL, "update-index", "-q", "--unmerged", "--ignore-missing", "--refresh", NULL};
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, NULL, G_CALLBACK(update_index_end));
	
	gitg_runner_run(commit->priv->runner, argv, NULL);
}

void
gitg_commit_refresh(GitgCommit *commit)
{
	runner_cancel(commit);
	
	/* Read other files */
	update_index(commit);
}

void 
gitg_commit_stage(GitgCommit *commit)
{

}

void
gitg_commit_unstage(GitgCommit *commit)
{

}
