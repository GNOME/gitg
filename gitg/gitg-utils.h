#ifndef __GITG_UTILS_H__
#define __GITG_UTILS_H__

#include <glib.h>
#include "gitg-repository.h"
#include "gitg-revision.h"

void gitg_utils_sha1_to_hash(gchar const *sha, gchar *hash);
void gitg_utils_hash_to_sha1(gchar const *hash, gchar *sha);

gchar *gitg_utils_sha1_to_hash_new(gchar const *sha);
gchar *gitg_utils_hash_to_sha1_new(gchar const *hash);

gchar *gitg_utils_find_git(gchar const *path);
gchar *gitg_utils_dot_git_path(gchar const *path);

gboolean gitg_utils_export_files(GitgRepository *repository, GitgRevision *revision,
gchar const *todir, gchar * const *paths);

gchar *gitg_utils_convert_utf8(gchar const *str);

#endif /* __GITG_UTILS_H__ */
