#include "gitg-commit.h"
#include "gitg-runner.h"
#include "gitg-utils.h"
#include "gitg-changed-file.h"

#include <string.h>

#define GITG_COMMIT_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_COMMIT, GitgCommitPrivate))

#define CAN_DELETE_KEY "CanDeleteKey"

/* Properties */
enum
{
	PROP_0,
	PROP_REPOSITORY
};

/* Signals */
enum
{
	INSERTED,
	REMOVED,
	LAST_SIGNAL
};

struct _GitgCommitPrivate
{
	GitgRepository *repository;

	gchar *dotgit;
	GitgRunner *runner;

	guint update_id;
	guint end_id;
	
	GHashTable *files;
};

static guint commit_signals[LAST_SIGNAL] = { 0 };

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
		commit->priv->end_id = 0;
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
	
	g_hash_table_destroy(commit->priv->files);

	G_OBJECT_CLASS(gitg_commit_parent_class)->finalize(object);
}

static void
gitg_commit_dispose(GObject *object)
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
gitg_commit_constructor(GType type, guint n_construct_properties, GObjectConstructParam *construct_properties)
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

	object_class->dispose = gitg_commit_dispose;
	object_class->finalize = gitg_commit_finalize;
	object_class->constructor = gitg_commit_constructor;
	
	object_class->set_property = gitg_commit_set_property;
	object_class->get_property = gitg_commit_get_property;

	g_object_class_install_property(object_class, PROP_REPOSITORY,
					 g_param_spec_object("repository",
							      "REPOSITORY",
							      "Repository",
							      GITG_TYPE_REPOSITORY,
							      G_PARAM_READWRITE | G_PARAM_CONSTRUCT_ONLY));

	commit_signals[INSERTED] =
   		g_signal_new ("inserted",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgCommitClass, inserted),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__OBJECT,
			      G_TYPE_NONE,
			      1,
			      GITG_TYPE_CHANGED_FILE);

	commit_signals[REMOVED] =
   		g_signal_new ("removed",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgCommitClass, removed),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__OBJECT,
			      G_TYPE_NONE,
			      1,
			      GITG_TYPE_CHANGED_FILE);

	g_type_class_add_private(object_class, sizeof(GitgCommitPrivate));
}

static void
gitg_commit_init(GitgCommit *self)
{
	self->priv = GITG_COMMIT_GET_PRIVATE(self);
	
	self->priv->runner = gitg_runner_new(5000);
	self->priv->files = g_hash_table_new_full(g_file_hash, (GEqualFunc)g_file_equal, (GDestroyNotify)g_object_unref, (GDestroyNotify)g_object_unref);
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
add_files(GitgCommit *commit, gchar **buffer, gboolean cached)
{
	gchar *line;
	
	while (line = *buffer++)
	{
		gchar **parts = g_strsplit_set(line, " \t", 0);
		guint len = g_strv_length(parts);
		
		if (len < 6)
		{
			g_warning("Invalid line: %s (%d)", line, len);
			g_strfreev(parts);
			continue;
		}
		
		gchar const *mode = parts[0] + 1;
		gchar const *sha = parts[2];
		GSList *item;
		
		gchar *path = g_build_filename(gitg_repository_get_path(commit->priv->repository), parts[5], NULL);
		
		GFile *file = g_file_new_for_path(path);
		g_free(path);

		GitgChangedFile *f = GITG_CHANGED_FILE(g_hash_table_lookup(commit->priv->files, file));
		
		if (f)
		{
			GitgChangedFileChanges changes = gitg_changed_file_get_changes(f);
			
			g_object_set_data(G_OBJECT(f), CAN_DELETE_KEY, NULL);
			
			if (cached)
			{
				gitg_changed_file_set_sha(f, sha);
				gitg_changed_file_set_mode(f, sha);
				
				changes |= GITG_CHANGED_FILE_CHANGES_CACHED;
			}
			else
			{
				changes |= GITG_CHANGED_FILE_CHANGES_UNSTAGED;
			}
			
			gitg_changed_file_set_changes(f, changes);
			
			g_object_unref(file);
			g_strfreev(parts);
			continue;
		}
		
		f = gitg_changed_file_new(file);
		GitgChangedFileStatus status;
		
		if (strcmp(parts[4], "D") == 0)
			status = GITG_CHANGED_FILE_STATUS_DELETED;
		else if (strcmp(mode, "000000") == 0)
			status = GITG_CHANGED_FILE_STATUS_NEW;
		else
			status = GITG_CHANGED_FILE_STATUS_MODIFIED;
		
		gitg_changed_file_set_status(f, status);
		gitg_changed_file_set_sha(f, sha);
		gitg_changed_file_set_mode(f, mode);

		GitgChangedFileChanges changes;
		
		changes = cached ? GITG_CHANGED_FILE_CHANGES_CACHED : GITG_CHANGED_FILE_CHANGES_UNSTAGED;
		gitg_changed_file_set_changes(f, changes);
		
		g_hash_table_insert(commit->priv->files, file, f);
		g_signal_emit(commit, commit_signals[INSERTED], 0, f);

		g_strfreev(parts);
	}
}

static void
read_cached_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	add_files(commit, buffer, TRUE);
}

static gboolean
delete_file(GFile *key, GitgChangedFile *value, GitgCommit *commit)
{
	if (!g_object_get_data(G_OBJECT(value), CAN_DELETE_KEY))
		return FALSE;
	
	g_signal_emit(commit, commit_signals[REMOVED], 0, value);
	return TRUE;
}

static void
refresh_done(GitgRunner *runner, GitgCommit *commit)
{
	g_hash_table_foreach_remove(commit->priv->files, (GHRFunc)delete_file, commit);
}

static void
read_unstaged_files_end(GitgRunner *runner, GitgCommit *commit)
{
	/* FIXME: something with having no head ref... */
	static gchar const *argv[] = {"git", "--git-dir", NULL, "diff-index", "--cached", "HEAD", NULL};
	gitg_runner_cancel(runner);
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, G_CALLBACK(read_cached_files_update), G_CALLBACK(refresh_done));
	
	gitg_runner_run_working_directory(commit->priv->runner, argv, gitg_repository_get_path(commit->priv->repository), NULL);
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
	
	gitg_runner_run_working_directory(commit->priv->runner, argv, gitg_repository_get_path(commit->priv->repository), NULL);
}

static void
changed_file_new(GitgChangedFile *f)
{
	gitg_changed_file_set_status(f, GITG_CHANGED_FILE_STATUS_NEW);
	gitg_changed_file_set_changes(f, GITG_CHANGED_FILE_CHANGES_UNSTAGED);
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
		GitgChangedFile *f = g_hash_table_lookup(commit->priv->files, file);
		
		if (f)
		{
			changed_file_new(f);
			g_object_unref(file);
			continue;
		}
		
		f = gitg_changed_file_new(file);

		changed_file_new(f);		
		g_hash_table_insert(commit->priv->files, file, f);
		
		g_signal_emit(commit, commit_signals[INSERTED], 0, f);
	}
}

static void
update_index_end(GitgRunner *runner, GitgCommit *commit)
{
	static gchar const *argv[] = {"git", "--git-dir", NULL, "ls-files", "--others", "--exclude-standard", NULL};
	gitg_runner_cancel(runner);
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, G_CALLBACK(read_other_files_update), G_CALLBACK(read_other_files_end));
	
	gitg_runner_run_working_directory(commit->priv->runner, argv, gitg_repository_get_path(commit->priv->repository), NULL);
}

static void
update_index(GitgCommit *commit)
{
	static gchar const *argv[] = {"git", "--git-dir", NULL, "update-index", "-q", "--unmerged", "--ignore-missing", "--refresh", NULL};
	
	argv[2] = commit->priv->dotgit;
	runner_connect(commit, NULL, G_CALLBACK(update_index_end));
	
	gitg_runner_run_working_directory(commit->priv->runner, argv, gitg_repository_get_path(commit->priv->repository), NULL);
}

static void
set_can_delete(GFile *key, GitgChangedFile *value, GitgCommit *commit)
{
	g_object_set_data(G_OBJECT(value), CAN_DELETE_KEY, GINT_TO_POINTER(TRUE));
	gitg_changed_file_set_changes(value, GITG_CHANGED_FILE_CHANGES_NONE);
}

void
gitg_commit_refresh(GitgCommit *commit)
{
	g_return_if_fail(GITG_IS_COMMIT(commit));

	runner_cancel(commit);
	
	g_hash_table_foreach(commit->priv->files, (GHFunc)set_can_delete, commit);

	/* Read other files */
	if (commit->priv->repository)
		update_index(commit);
}

gboolean
apply_hunk(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, gboolean reverse, GError **error)
{
	if (error)
		*error = NULL;

	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), FALSE);
	
	g_return_val_if_fail(hunk != NULL, FALSE);
	
	GitgRunner *runner = gitg_runner_new_synchronized(1000);
	gchar const *repos = gitg_repository_get_path(commit->priv->repository);
	gchar *dotgit = gitg_utils_dot_git_path(repos);

	gchar const *argv[] = {"git", "--git-dir", dotgit, "apply", "--cached", NULL, NULL};
	
	if (reverse)
		argv[5] = "--reverse";
	
	gboolean ret = gitg_runner_run_with_arguments(runner, argv, repos, hunk, error);
	g_free(dotgit);
	
	if (ret)
	{
		/* FIXME: for sure we can do better */
		gitg_commit_refresh(commit);
	}
	
	return ret;
}

gboolean
gitg_commit_stage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error)
{
	if (hunk)
		return apply_hunk(commit, file, hunk, FALSE, error);
	
	/* Otherwise, stage whole file */
	GitgRunner *runner = gitg_runner_new_synchronized(1000);
	gchar *path;
	GFile *f;
	gchar const *repos = gitg_repository_get_path(commit->priv->repository);
	gchar *dotgit = gitg_utils_dot_git_path(repos);
	
	GFile *parent = g_file_new_for_path(repos);

	f = gitg_changed_file_get_file(file);
	path = g_file_get_relative_path(parent, f);

	g_object_unref(f);
	g_object_unref(parent);
	
	gchar const *argv[] = {"git", "--git-dir", dotgit, "update-index", "--add", "--remove", "--", path, NULL};
	gboolean ret = gitg_runner_run_working_directory(runner, argv, repos, error);
	
	g_free(dotgit);	
	g_free(path);

	if (ret)
	{
		gitg_changed_file_set_changes(file, GITG_CHANGED_FILE_CHANGES_CACHED);
		g_object_unref(runner);
	}
	else
	{
		g_error("Update index for stage failed");
	}

	return ret;
}

gboolean
gitg_commit_unstage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error)
{
	if (hunk)
		return apply_hunk(commit, file, hunk, TRUE, error);
	
	/* Otherwise, unstage whole file */
	GitgRunner *runner = gitg_runner_new_synchronized(1000);
	gchar *path;
	GFile *f;
	gchar const *repos = gitg_repository_get_path(commit->priv->repository);
	gchar *dotgit = gitg_utils_dot_git_path(repos);
	
	GFile *parent = g_file_new_for_path(repos);

	f = gitg_changed_file_get_file(file);
	path = g_file_get_relative_path(parent, f);

	g_object_unref(f);
	g_object_unref(parent);
	
	gchar const *argv[] = {"git", "--git-dir", dotgit, "update-index", "--index-info", NULL};
	
	gchar *input = g_strdup_printf("%s %s\t%s", gitg_changed_file_get_mode(file), gitg_changed_file_get_sha(file), path);
	gboolean ret = gitg_runner_run_with_arguments(runner, argv, repos, input, error);
	
	g_free(dotgit);	
	g_free(path);

	if (ret)
	{
		gitg_changed_file_set_changes(file, GITG_CHANGED_FILE_CHANGES_UNSTAGED);
		g_object_unref(runner);
	}
	else
	{
		g_error("Update index for unstage failed");
	}

	return ret;
}

static void
find_staged(GFile *key, GitgChangedFile *value, gboolean *result)
{
	if (*result)
		return;
	
	*result = (gitg_changed_file_get_changes(value) & GITG_CHANGED_FILE_CHANGES_CACHED);
}

gboolean
gitg_commit_has_changes(GitgCommit *commit)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	gboolean result = FALSE;
	
	g_hash_table_foreach(commit->priv->files, (GHFunc)find_staged, &result);
	return result;
}

static void
store_line(GitgRunner *runner, gchar **buffer, gchar **line)
{
	g_free(*line);
	*line = g_strdup(*buffer);
}

gboolean
gitg_commit_commit(GitgCommit *commit, gchar const *comment, GError **error)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	
	/* set subject to first line */
	gchar *ptr;
	gchar *subject;
	
	if (ptr = g_utf8_strchr(comment, g_utf8_strlen(comment, -1), '\n'))
	{
		subject = g_strndup(comment, ptr - comment);
	}
	else
	{
		subject = g_strdup(comment);
	}
	
	gchar *cm = g_strconcat("commit:", subject, NULL);
	g_free(subject);
	
	GitgRunner *runner = gitg_runner_new_synchronized(100);
	gchar const *repos = gitg_repository_get_path(commit->priv->repository);
	gchar *dotgit = gitg_utils_dot_git_path(repos);
	gchar const *argv[] = {"git", "--git-dir", dotgit, "write-tree", NULL, NULL, NULL, NULL};
	gchar *line = NULL;

	guint update_id = g_signal_connect(runner, "update", G_CALLBACK(store_line), &line);
	gboolean ret = gitg_runner_run_working_directory(runner, argv, repos, error);
	
	if (!ret || !line || strlen(line) != 40)
	{
		g_object_unref(runner);
		g_free(dotgit);
		g_free(line);
		g_free(cm);
		
		return FALSE;
	}
	
	gchar *tree = g_strdup(line);
	
	argv[3] = "commit-tree";
	argv[4] = tree;
	argv[5] = "-p";
	argv[6] = "HEAD";

	g_free(line);
	line = NULL;

	ret = gitg_runner_run_with_arguments(runner, argv, repos, comment, error);
	g_free(tree);
	
	if (!ret || !line || strlen(line) != 40)
	{
		g_object_unref(runner);
		g_free(dotgit);
		g_free(cm);
		g_free(line);
		
		return FALSE;
	}
	
	argv[1] = "update-ref";
	argv[2] = "-m";
	argv[3] = cm;
	argv[4] = "HEAD";
	argv[5] = line;
	
	g_signal_handler_disconnect(runner, update_id);
	ret = gitg_runner_run_working_directory(runner, argv, repos, error);
	
	g_object_unref(runner);
	g_free(dotgit);
	g_free(cm);
	g_free(line);
	
	gitg_repository_changed(commit->priv->repository);
	return ret;
}
