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
