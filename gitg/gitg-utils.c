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
	{
		gchar h = atoh(*(sha++)) << 4;
		hash[i] = h | atoh(*(sha++));
	}
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
	while (strcmp(path, ".") != 0 && strcmp(path, "/") != 0)
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

static void
append_escape(GString *gstr, gchar const *item)
{
	gchar *escape = g_shell_quote(item);
	
	g_string_append_printf(gstr, " %s", escape);
}

gboolean 
gitg_utils_export_files(GitgRepository *repository, GitgRevision *revision,
gchar const *todir, gchar * const *paths)
{	
	GString *gstr = g_string_new("sh -c \"git --git-dir");
	
	// Append the git path
	gchar *gitpath = gitg_utils_dot_git_path(gitg_repository_get_path(repository));
	append_escape(gstr, gitpath);
	g_free(gitpath);

	// Append the revision
	gchar *sha = gitg_revision_get_sha1(revision);
	g_string_append_printf(gstr, " archive --format=tar %s", sha);
	g_free(sha);
	
	// Append the files
	while (*paths)
	{
		append_escape(gstr, *paths);
		paths++;
	}

	g_string_append(gstr, " | tar -xC");
	append_escape(gstr, todir);
	g_string_append(gstr, "\"");
	
	GError *error = NULL;
	gint status;

	gboolean ret = g_spawn_command_line_sync(gstr->str, NULL, NULL, &status, &error);
	
	if (!ret)
	{
		g_warning("Export failed:\n%s\n%s", gstr->str, error->message);
		g_error_free(error);
	}

	g_string_free(gstr, TRUE);
	return ret;
}

gchar *
convert_fallback(gchar const *text, gchar const *fallback)
{
	gchar *res;
	gsize read, written;
	GString *str = g_string_new("");
	
	while ((res = g_convert(text, -1, "UTF-8", "ASCII", &read, &written, NULL))
			== NULL) {
		res = g_convert(text, read, "UTF-8", "ASCII", NULL, NULL, NULL);
		str = g_string_append(str, res);
		
		str = g_string_append(str, fallback);
		text = text + read + 1;
	}
	
	str = g_string_append(str, res);
	g_free(res);
	
	res = str->str;
	g_string_free(str, FALSE);
	return res;
}

gchar *
gitg_utils_convert_utf8(gchar const *str)
{
	static gchar *encodings[] = {
		"ISO-8859-15",
		"ASCII"
	};
	
	if (g_utf8_validate(str, -1, NULL))
		return g_strdup(str);
	
	int i;
	for (i = 0; i < sizeof(encodings) / sizeof(gchar *); ++i)
	{
		gsize read;
		gsize written;

		gchar *ret = g_convert(str, -1, "UTF-8", encodings[i], &read, &written, NULL);
		
		if (ret)
			return ret;
	}
	
	return convert_fallback(str, "?");
}

guint
gitg_utils_hash_hash(gconstpointer v)
{
	/* 31 bit hash function, copied from g_str_hash */
	const signed char *p = v;
	guint32 h = *p;
	int i;
	
	for (i = 1; i < 20; ++i)
		h = (h << 5) - h + p[i];

	return h;
}

gboolean 
gitg_utils_hash_equal(gconstpointer a, gconstpointer b)
{
	return memcmp(a, b, 20) == 0;
}

gint
gitg_utils_null_length(gconstpointer *ptr)
{
	gint ret = 0;
	
	while (*ptr++)
		++ret;
	
	return ret;
}
