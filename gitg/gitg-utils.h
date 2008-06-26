#ifndef __GITG_UTILS_H__
#define __GITG_UTILS_H__

#include <glib.h>

void gitg_utils_sha1_to_hash(gchar const *sha, gchar *hash);
void gitg_utils_hash_to_sha1(gchar const *hash, gchar *sha);

gchar *gitg_utils_sha1_to_hash_new(gchar const *sha);
gchar *gitg_utils_hash_to_sha1_new(gchar const *hash);

gchar *gitg_utils_find_git(gchar const *path);
gchar *gitg_utils_dot_git_path(gchar const *path);

#endif /* __GITG_UTILS_H__ */
