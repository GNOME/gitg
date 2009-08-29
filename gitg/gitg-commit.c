/*
 * gitg-commit.c
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

#include "gitg-commit.h"
#include "gitg-runner.h"
#include "gitg-utils.h"
#include "gitg-changed-file.h"
#include "gitg-config.h"

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
	GitgRunner *runner;

	guint update_id;
	guint end_id;
	
	GHashTable *files;
};

static guint commit_signals[LAST_SIGNAL] = { 0 };

G_DEFINE_TYPE(GitgCommit, gitg_commit, G_TYPE_OBJECT)

static void on_changed_file_changed(GitgChangedFile *file, GitgCommit *commit);

GQuark
gitg_commit_error_quark()
{
	static GQuark quark = 0;

	if (G_UNLIKELY(quark == 0))
		quark = g_quark_from_string ("gitg_commit_error");

	return quark;
}

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
	
	g_hash_table_destroy(commit->priv->files);

	G_OBJECT_CLASS(gitg_commit_parent_class)->finalize(object);
}

static void
gitg_commit_dispose(GObject *object)
{
	GitgCommit *self = GITG_COMMIT(object);
	
	if (self->priv->repository)
	{
		g_signal_handlers_disconnect_by_func(self->priv->repository, G_CALLBACK(gitg_commit_refresh), self);

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
		{
			if (self->priv->repository)
				g_object_unref(self->priv->repository);

			self->priv->repository = g_value_dup_object(value);
			g_signal_connect_swapped(self->priv->repository, "load", G_CALLBACK(gitg_commit_refresh), self);
		}
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_commit_class_init(GitgCommitClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);

	object_class->dispose = gitg_commit_dispose;
	object_class->finalize = gitg_commit_finalize;
	
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
	
	self->priv->runner = gitg_runner_new(10000);
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
update_changed_file_status(GitgChangedFile *file, char const *action, gchar const *mode)
{
	GitgChangedFileStatus status;
	
	if (strcmp(action, "D") == 0)
		status = GITG_CHANGED_FILE_STATUS_DELETED;
	else if (strcmp(mode, "000000") == 0)
		status = GITG_CHANGED_FILE_STATUS_NEW;
	else
		status = GITG_CHANGED_FILE_STATUS_MODIFIED;
	
	gitg_changed_file_set_status(file, status);
}

static void
add_files(GitgCommit *commit, gchar **buffer, gboolean cached)
{
	gchar *line;
	
	while ((line = *buffer++) != NULL)
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
		
		gchar *path = g_build_filename(gitg_repository_get_path(commit->priv->repository), parts[5], NULL);
		
		GFile *file = g_file_new_for_path(path);
		g_free(path);

		GitgChangedFile *f = GITG_CHANGED_FILE(g_hash_table_lookup(commit->priv->files, file));
		
		if (f)
		{
			GitgChangedFileChanges changes = gitg_changed_file_get_changes(f);

			g_object_set_data(G_OBJECT(f), CAN_DELETE_KEY, NULL);
			update_changed_file_status(f, parts[4], mode);
			
			if (cached)
			{
				gitg_changed_file_set_sha(f, sha);
				gitg_changed_file_set_mode(f, mode);
				
				changes |= GITG_CHANGED_FILE_CHANGES_CACHED;
			}
			else
			{
				changes |= GITG_CHANGED_FILE_CHANGES_UNSTAGED;
			}
			
			gitg_changed_file_set_changes(f, changes);
			
			if ((changes & GITG_CHANGED_FILE_CHANGES_CACHED) && (changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED))
				gitg_changed_file_set_status(f, GITG_CHANGED_FILE_STATUS_MODIFIED);
			
			g_object_unref(file);
			g_strfreev(parts);
			continue;
		}
		
		f = gitg_changed_file_new(file);
		update_changed_file_status(f, parts[4], mode);

		gitg_changed_file_set_sha(f, sha);
		gitg_changed_file_set_mode(f, mode);

		GitgChangedFileChanges changes;
		
		changes = cached ? GITG_CHANGED_FILE_CHANGES_CACHED : GITG_CHANGED_FILE_CHANGES_UNSTAGED;
		gitg_changed_file_set_changes(f, changes);
		
		g_hash_table_insert(commit->priv->files, file, f);
		
		g_signal_connect(f, "changed", G_CALLBACK(on_changed_file_changed), commit);
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
refresh_done(GitgRunner *runner, gboolean cancelled, GitgCommit *commit)
{
	g_hash_table_foreach_remove(commit->priv->files, (GHRFunc)delete_file, commit);
}

static void
read_unstaged_files_end(GitgRunner *runner, gboolean cancelled, GitgCommit *commit)
{
	gchar *head = gitg_repository_parse_head(commit->priv->repository);
	gitg_runner_cancel(runner);

	runner_connect(commit, G_CALLBACK(read_cached_files_update), G_CALLBACK(refresh_done));	
	gitg_repository_run_commandv(commit->priv->repository, commit->priv->runner, NULL, "diff-index", "--cached", head, NULL);
	g_free(head);
}

static void
read_unstaged_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	add_files(commit, buffer, FALSE);
}

static void
read_other_files_end(GitgRunner *runner, gboolean cancelled, GitgCommit *commit)
{
	gitg_runner_cancel(runner);
	
	runner_connect(commit, G_CALLBACK(read_unstaged_files_update), G_CALLBACK(read_unstaged_files_end));
	gitg_repository_run_commandv(commit->priv->repository,commit->priv->runner, NULL, "diff-files", NULL);
}

static void
changed_file_new(GitgChangedFile *f)
{
	gitg_changed_file_set_status(f, GITG_CHANGED_FILE_STATUS_NEW);
	gitg_changed_file_set_changes(f, GITG_CHANGED_FILE_CHANGES_UNSTAGED);
	
	g_object_set_data(G_OBJECT(f), CAN_DELETE_KEY, NULL);
}

static void
read_other_files_update(GitgRunner *runner, gchar **buffer, GitgCommit *commit)
{
	gchar *line;

	while ((line = *buffer++) != NULL)
	{
		/* Skip empty lines */
		if (!*line)
			continue;
			
		/* Check if file is already in our index */
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
update_index_end(GitgRunner *runner, gboolean cancelled, GitgCommit *commit)
{
	gitg_runner_cancel(runner);
	runner_connect(commit, G_CALLBACK(read_other_files_update), G_CALLBACK(read_other_files_end));
	
	gitg_repository_run_commandv(commit->priv->repository, commit->priv->runner, NULL, "ls-files", "--others", "--exclude-standard", NULL);
}

static void
update_index(GitgCommit *commit)
{
	runner_connect(commit, NULL, G_CALLBACK(update_index_end));
	gitg_repository_run_commandv(commit->priv->repository, commit->priv->runner, NULL, "update-index", "-q", "--unmerged", "--ignore-missing", "--refresh", NULL);
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
	else
		refresh_done(commit->priv->runner, FALSE, commit);
}

static void
update_index_staged(GitgCommit *commit, GitgChangedFile *file)
{
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	gchar *head = gitg_repository_parse_head(commit->priv->repository);

	gchar **ret = gitg_repository_command_with_outputv(commit->priv->repository, NULL, "diff-index", "--cached", head, "--", path, NULL);
	
	g_free(path);
	g_free(head);
	g_object_unref(f);
	
	if (!ret)
		return;
	
	gchar **parts = *ret ? g_strsplit_set(*ret, " \t", 0) : NULL;
	g_strfreev(ret);
	
	if (parts && g_strv_length(parts) > 2)
	{
		gitg_changed_file_set_mode(file, parts[0] + 1);
		gitg_changed_file_set_sha(file, parts[2]);
		
		gitg_changed_file_set_changes(file, gitg_changed_file_get_changes(file) | GITG_CHANGED_FILE_CHANGES_CACHED);
		update_changed_file_status(file, parts[4], parts[0] + 1);
	}
	else
	{
		gitg_changed_file_set_changes(file, gitg_changed_file_get_changes(file) & ~GITG_CHANGED_FILE_CHANGES_CACHED);
	}
	
	if (parts)
		g_strfreev(parts);
}

static void
update_index_unstaged(GitgCommit *commit, GitgChangedFile *file)
{
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	gchar **ret = gitg_repository_command_with_outputv(commit->priv->repository, NULL, "diff-files", "--", path, NULL);
	g_free(path);
	g_object_unref(f);
	
	if (ret && *ret)
	{
		gitg_changed_file_set_changes(file, gitg_changed_file_get_changes(file) | GITG_CHANGED_FILE_CHANGES_UNSTAGED);
	}
	else
	{
		gitg_changed_file_set_changes(file, gitg_changed_file_get_changes(file) & ~GITG_CHANGED_FILE_CHANGES_UNSTAGED);
	}
	
	if (ret)
		g_strfreev(ret);
}

static void
update_index_file(GitgCommit *commit, GitgChangedFile *file)
{
	/* update the index */
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	g_object_unref(f);

	gitg_repository_commandv(commit->priv->repository, NULL, "update-index", "-q", "--unmerged", "--ignore-missing", "--refresh", NULL);
	
	g_free(path);
}

static void
refresh_changes(GitgCommit *commit, GitgChangedFile *file)
{
	/* update the index */
	update_index_file(commit, file);

	/* Determine if it still has staged/unstaged changes */
	update_index_staged(commit, file);
	update_index_unstaged(commit, file);
	
	GitgChangedFileChanges changes = gitg_changed_file_get_changes(file);
	GitgChangedFileStatus status = gitg_changed_file_get_status(file);

	if (changes == GITG_CHANGED_FILE_CHANGES_NONE && status == GITG_CHANGED_FILE_CHANGES_NONE)
		gitg_changed_file_set_status(file, GITG_CHANGED_FILE_STATUS_NEW);
	else if ((changes & GITG_CHANGED_FILE_CHANGES_CACHED) && (changes & GITG_CHANGED_FILE_CHANGES_UNSTAGED))
		gitg_changed_file_set_status(file, GITG_CHANGED_FILE_STATUS_MODIFIED);
	
	if (status == GITG_CHANGED_FILE_STATUS_NEW &&
	    !(changes & GITG_CHANGED_FILE_CHANGES_CACHED))
	{
		gitg_changed_file_set_changes(file, GITG_CHANGED_FILE_CHANGES_UNSTAGED);
	}
}

gboolean
apply_hunk(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, gboolean reverse, GError **error)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), FALSE);
	
	g_return_val_if_fail(hunk != NULL, FALSE);
	
	gboolean ret = gitg_repository_command_with_inputv(commit->priv->repository, hunk, error, "apply", "--cached", reverse ? "--reverse" : NULL, NULL);
	
	if (ret)
		refresh_changes(commit, file);
	
	return ret;
}

gboolean
gitg_commit_stage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error)
{
	if (hunk)
		return apply_hunk(commit, file, hunk, FALSE, error);
	
	/* Otherwise, stage whole file */
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	g_object_unref(f);
	
	gboolean ret = gitg_repository_commandv(commit->priv->repository, NULL, "update-index", "--add", "--remove", "--", path, NULL);
	g_free(path);
	
	if (ret)
		refresh_changes(commit, file);
	else
		g_error("Update index for stage failed");

	return ret;
}

gboolean
gitg_commit_unstage(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error)
{
	if (hunk)
		return apply_hunk(commit, file, hunk, TRUE, error);
	
	/* Otherwise, unstage whole file */
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	g_object_unref(f);

	gchar *input = g_strdup_printf("%s %s\t%s\n", gitg_changed_file_get_mode(file), gitg_changed_file_get_sha(file), path);
	gboolean ret = gitg_repository_command_with_inputv(commit->priv->repository, input, error, "update-index", "--index-info", NULL);
	g_free(input);
	
	if (ret)
		refresh_changes(commit, file);
	else
		g_error("Update index for unstage failed");
	
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

static gchar *
comment_parse_subject(gchar const *comment)
{
	gchar *ptr;
	gchar *subject;
	
	if ((ptr = g_utf8_strchr(comment, g_utf8_strlen(comment, -1), '\n')) != NULL)
	{
		subject = g_strndup(comment, ptr - comment);
	}
	else
	{
		subject = g_strdup(comment);
	}
	
	gchar *commit = g_strconcat("commit:", subject, NULL);
	g_free(subject);
	
	return commit;
}

static gboolean
write_tree(GitgCommit *commit, gchar **tree, GError **error)
{
	gchar const *argv[] = {"write-tree", NULL};
	gchar **lines = gitg_repository_command_with_output(commit->priv->repository, argv, error);
	
	if (!lines || strlen(*lines) != HASH_SHA_SIZE)
	{
		g_strfreev(lines);
		return FALSE;
	}
	
	*tree = g_strdup(*lines);
	g_strfreev(lines);
	
	return TRUE;
}

static gchar *
get_signed_off_line(GitgCommit *commit)
{
	gchar **user = gitg_repository_command_with_outputv(commit->priv->repository, NULL, "config", "--get", "user.name", NULL);
	
	if (!user)
		return NULL;
	
	if (!*user || !**user)
	{
		g_strfreev(user);
		return NULL;
	}
	
	gchar **email = gitg_repository_command_with_outputv(commit->priv->repository, NULL, "config", "--get", "user.email", NULL);
	
	if (!email)
	{
		g_strfreev(user);
		return NULL;
	}
	
	if (!*email || !**email)
	{
		g_strfreev(user);
		g_strfreev(email);
		
		return NULL;
	}
	
	gchar *ret = g_strdup_printf("Signed-off-by: %s <%s>", *user, *email);
	g_strfreev(user);
	g_strfreev(email);
	
	return ret;
}

static void
on_commit_tree_update (GitgRunner *runner, gchar **lines, GString *buffer)
{
	while (lines && *lines)
	{
		if (buffer->len != 0)
		{
			g_string_append_c (buffer, '\n');
		}
		
		g_string_append (buffer, *lines);
		++lines;
	}
}

static void
set_amend_environment (GitgCommit *commit, GitgRunner *runner)
{
	gchar **out;
	
	out = gitg_repository_command_with_outputv (commit->priv->repository,
	                                            NULL,
	                                            "cat-file",
	                                            "commit",
	                                            "HEAD",
	                                            NULL);

	// Parse author
	GRegex *r = g_regex_new ("^author (.*) <([^>]*)> ([0-9]+.*)$",
	                         G_REGEX_CASELESS,
	                         0,
	                         NULL);

	GMatchInfo *info = NULL;
	gchar **ptr = out;
	
	while (ptr && *ptr)
	{
		if (g_regex_match (r, *ptr, 0, &info))
		{
			gchar *name = g_match_info_fetch (info, 1);
			gchar *email = g_match_info_fetch (info, 2);
			gchar *date = g_match_info_fetch (info, 3);

			gitg_runner_add_environment (runner, "GIT_AUTHOR_NAME", name);
			gitg_runner_add_environment (runner, "GIT_AUTHOR_EMAIL", email);
			gitg_runner_add_environment (runner, "GIT_AUTHOR_DATE", date);
			
			g_free (name);
			g_free (email);
			g_free (date);
		
			break;
		}
		
		++ptr;
	}
	
	g_strfreev (out);
}

static gchar *
convert_commit_encoding (GitgCommit *commit, gchar const *s)
{
	GitgConfig *config;
	gchar *encoding;
	gchar *ret;

	config = gitg_config_new (commit->priv->repository);
	encoding = gitg_config_get_value (config, "i18n.commitencoding");
	
	if (!encoding || !*encoding)
	{
		g_object_unref (config);
		g_free (encoding);

		config = gitg_config_new (NULL);
		
		encoding = gitg_config_get_value (config, "i18n.commitencoding");
	}
	
	g_object_unref (config);
	
	if (!encoding || !*encoding || g_ascii_strcasecmp (encoding, "UTF-8") == 0)
	{
		g_free (encoding);
		return g_strdup (s);
	}
	
	// Try to convert from UTF-8 to 'encoding'
	ret = g_convert (s, -1, encoding, "UTF-8", NULL, NULL, NULL);
	
	if (!ret)
	{
		// Just use 's' then, even if it is UTF-8...
		ret = g_strdup (s);
	}

	g_free (encoding);
	return ret;
}

static gboolean 
commit_tree(GitgCommit *commit, gchar const *tree, gchar const *comment, gboolean signoff, gboolean amend, gchar **ref, GError **error)
{
	gchar *fullcomment;
	
	if (signoff)
	{
		gchar *line = get_signed_off_line(commit);
		
		if (!line)
		{
			if (error)
				g_set_error(error, GITG_COMMIT_ERROR, GITG_COMMIT_ERROR_SIGNOFF, "Could not retrieve user name or email for signoff message");
			
			return FALSE;
		}

		fullcomment = g_strconcat(comment, "\n\n", line, NULL);
	}
	else
	{
		fullcomment = g_strdup(comment);
	}
	
	gchar *head;
	
	if (amend)
	{
		head = gitg_repository_parse_ref(commit->priv->repository, "HEAD^");
	}
	else
	{
		head = gitg_repository_parse_ref(commit->priv->repository, "HEAD");
	}
	
	GitgRunner *runner = gitg_runner_new_synchronized (1000);
	GString *buffer = g_string_new ("");
	
	if (amend)
	{
		set_amend_environment (commit, runner);
	}
	
	gchar *converted = convert_commit_encoding (commit, fullcomment);
	
	g_signal_connect (runner, "update", G_CALLBACK (on_commit_tree_update), buffer);
	gitg_repository_run_command_with_inputv (commit->priv->repository,
	                                         runner,
	                                         converted,
	                                         error,
	                                         "commit-tree",
	                                         tree,
	                                         head ? "-p" : NULL,
	                                         head,
	                                         NULL);

	g_free(head);
	g_free(fullcomment);
	g_free(converted);
	g_object_unref (runner);

	if (buffer->len != HASH_SHA_SIZE)
	{
		g_string_free(buffer, TRUE);
		return FALSE;
	}
	
	*ref = g_string_free (buffer, FALSE);
	return TRUE;
}

static gboolean
update_ref(GitgCommit *commit, gchar const *ref, gchar const *subject, GError **error)
{
	gchar *converted = convert_commit_encoding (commit, subject);
	gchar const *argv[] = {"update-ref", "-m", converted, "HEAD", ref, NULL};
	
	gboolean ret = gitg_repository_command(commit->priv->repository, argv, error);
	g_free (converted);
	
	return ret;
}

gboolean
gitg_commit_commit(GitgCommit *commit, gchar const *comment, gboolean signoff, gboolean amend, GError **error)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	
	gchar *tree;

	if (!write_tree(commit, &tree, error))
		return FALSE;
	
	gchar *path = g_build_filename (gitg_repository_get_path (commit->priv->repository),
	                                ".git",
	                                "COMMIT_EDITMSG",
	                                NULL);
	g_file_set_contents (path, comment, -1, NULL);\
	g_free (path);
	
	gchar *ref;
	gboolean ret = commit_tree(commit, tree, comment, signoff, amend, &ref, error);
	g_free(tree);
	
	if (!ret)
		return FALSE;

	gchar *subject = comment_parse_subject(comment);
	ret = update_ref(commit, ref, subject, error);
	g_free(subject);
	
	if (!ret)
		return FALSE;
	
	gitg_repository_reload(commit->priv->repository);
	return TRUE;
}

static void
remove_file(GitgCommit *commit, GitgChangedFile *file)
{
	GFile *f = gitg_changed_file_get_file(file);

	g_hash_table_remove(commit->priv->files, f);
	g_object_unref(f);

	g_signal_emit(commit, commit_signals[REMOVED], 0, file);
}

gboolean
gitg_commit_revert(GitgCommit *commit, GitgChangedFile *file, gchar const *hunk, GError **error)
{
	gboolean ret;
	
	if (!hunk)
	{
		GFile *f = gitg_changed_file_get_file(file);
		gchar *path = gitg_repository_relative(commit->priv->repository, f);
	
		ret = gitg_repository_command_with_inputv(commit->priv->repository, path, error, "checkout-index", "--index", "--quiet", "--force", "--stdin", NULL);
		
		g_free(path);
		
		update_index_file(commit, file);
		update_index_unstaged(commit, file);
		g_object_unref(f);
	}
	else
	{
		GitgRunner *runner = gitg_runner_new_synchronized(1000);
		gchar const *argv[] = {"patch", "-p1", "-R", NULL};
		
		ret = gitg_runner_run_with_arguments(runner, argv, gitg_repository_get_path(commit->priv->repository), hunk, NULL); 
	
		update_index_file(commit, file);
		update_index_unstaged(commit, file);
		
		g_object_unref(runner);
	}
	
	return ret;
}

gboolean 
gitg_commit_add_ignore(GitgCommit *commit, GitgChangedFile *file, GError **error)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), FALSE);
	g_return_val_if_fail(GITG_IS_CHANGED_FILE(file), FALSE);
	
	GFile *f = gitg_changed_file_get_file(file);
	gchar *path = gitg_repository_relative(commit->priv->repository, f);
	
	gchar *ignore = g_strdup_printf("%s/.gitignore", gitg_repository_get_path(commit->priv->repository));
	GFile *ig = g_file_new_for_path(ignore);
	
	GFileOutputStream *stream = g_file_append_to(ig, G_FILE_CREATE_NONE, NULL, error);
	gboolean ret = FALSE;
	
	if (stream)
	{
		gchar *line = g_strdup_printf("/%s\n", path);
		ret = g_output_stream_write_all(G_OUTPUT_STREAM(stream), line, strlen(line), NULL, NULL, error);
		g_output_stream_close(G_OUTPUT_STREAM(stream), NULL, NULL);

		g_object_unref(stream);
		g_free(line);
	}
	
	if (ret)
		remove_file(commit, file);

	g_object_unref(f);	
	g_free(ignore);
	g_free(path);

	return ret;
}

static void
on_changed_file_changed(GitgChangedFile *file, GitgCommit *commit)
{
	refresh_changes(commit, file);
}

GitgChangedFile *
gitg_commit_find_changed_file(GitgCommit *commit, GFile *file)
{
	g_return_val_if_fail(GITG_IS_COMMIT(commit), NULL);
	g_return_val_if_fail(G_IS_FILE(file), NULL);
	
	GitgChangedFile *f = g_hash_table_lookup(commit->priv->files, file);
	
	if (f != NULL)
	{
		return g_object_ref(f);
	}
	else
	{
		return NULL;
	}
}

gchar *
gitg_commit_amend_message (GitgCommit *commit)
{
	g_return_val_if_fail (GITG_IS_COMMIT (commit), NULL);
	
	gchar **out;
	
	out = gitg_repository_command_with_outputv (commit->priv->repository,
	                                            NULL,
	                                            "cat-file",
	                                            "commit",
	                                            "HEAD",
	                                            NULL);

	gchar *ret = NULL;
	
	if (out)
	{
		gchar **ptr = out;
		
		while (*ptr)
		{
			if (!**ptr)
			{
				++ptr;
				break;
			}
			
			++ptr;
		}
		
		if (*ptr && **ptr)
		{
			GString *buffer = g_string_new ("");
			
			while (*ptr)
			{
				if (buffer->len != 0)
				{
					g_string_append_c (buffer, '\n');
				}
				
				g_string_append (buffer, *ptr);
				++ptr;
			}
			
			ret = g_string_free (buffer, FALSE);
		}
	}
	
	g_strfreev (out);
	return ret;
}
