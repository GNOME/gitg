#include <string.h>
#include <glib.h>

#include "gitg-utils.h"

inline static guint8
atoh(gchar c)
{
	if (c >= 'a')
		return c - 'a' + 10;
	if (c >= 'A')
		return c - 'A' + 10;
	
	return c - '0';
}

void
gitg_utils_sha1_to_hash(gchar const *sha, gchar *hash)
{
	int i;

	for (i = 0; i < 20; ++i)
		hash[i] = (atoh(*sha++) << 4) | atoh(*sha++);	
}

void
gitg_utils_hash_to_sha1(gchar const *hash, gchar *sha)
{
	char const *repr = "0123456789abcdef";
	int i;
	int pos = 0;

	for (i = 0; i < 20; ++i)
	{
		sha[pos++] = repr[(hash[i] >> 4) & 0x0f];
		sha[pos++] = repr[(hash[i] & 0x0f)];
	}
}

gchar *
gitg_utils_hash_to_sha1_new(gchar const *hash)
{
	gchar *ret = g_new(gchar, 41);
	gitg_utils_hash_to_sha1(hash, ret);
	
	ret[40] = '\0';
	return ret;
}

gchar *
gitg_utils_sha1_to_hash_new(gchar const *sha1)
{
	gchar *ret = g_new(gchar, 20);
	gitg_utils_sha1_to_hash(sha1, ret);
	
	return ret;
}

static gchar *
find_dot_git(gchar *path)
{
	while (strcmp(path, ".") != 0)
	{
		gchar *res = g_build_filename(path, ".git", NULL);
		
		if (g_file_test(res, G_FILE_TEST_IS_DIR))
		{
			g_free(res);
			return path;
		}
		
		gchar *tmp = g_path_get_dirname(path);
		g_free(path);
		path = tmp;
		
		g_free(res);
	}
	
	return NULL;
}

gchar *
gitg_utils_find_git(gchar const *path)
{
	gchar const *find = G_DIR_SEPARATOR_S ".git";
	gchar *dir;
	
	if (strstr(path, find) == path + strlen(path) - strlen(find))
		dir = g_strndup(path, strlen(path) - strlen(find));
	else
		dir = g_strdup(path);
	
	return find_dot_git(dir);
}

gchar *
gitg_utils_dot_git_path(gchar const *path)
{
	gchar const *find = G_DIR_SEPARATOR_S ".git";
	
	if (strstr(path, find) == path + strlen(path) - strlen(find))
		return g_strdup(path);
	else
		return g_build_filename(path, ".git", NULL);
}
