#include "gitg-uri.h"

#include <string.h>

gboolean
gitg_uri_parse (gchar const  *uri,
                gchar       **work_tree,
                gchar       **selection,
                gchar       **activatable,
                gchar       **action)
{
	gchar *selection_sep;
	gchar *activatable_sep;
	gchar *action_sep;
	gchar *dupped;

	if (uri == NULL)
	{
		return FALSE;
	}

	if (!g_str_has_prefix (uri, "gitg://"))
	{
		return FALSE;
	}

	if (work_tree)
	{
		*work_tree = NULL;
	}

	if (selection)
	{
		*selection = NULL;
	}

	if (activatable)
	{
		*activatable = NULL;
	}

	if (action)
	{
		*action = NULL;
	}

	dupped = g_strdup (uri + 7);
	selection_sep = strchr (dupped, ':');

	if (selection_sep)
	{
		*selection_sep = '\0';
	}

	if (work_tree)
	{
		*work_tree = g_strdup (dupped);
	}

	if (!selection_sep)
	{
		g_free (dupped);
		return TRUE;
	}

	activatable_sep = strchr (selection_sep + 1, '/');

	if (activatable_sep)
	{
		*activatable_sep = '\0';
	}

	if (selection)
	{
		*selection = g_strdup (selection_sep + 1);
	}

	if (!activatable_sep)
	{
		g_free (dupped);
		return TRUE;
	}

	action_sep = strchr (activatable_sep + 1, '/');

	if (action_sep)
	{
		*action_sep = '\0';
	}

	if (activatable)
	{
		*activatable = g_strdup (activatable_sep + 1);
	}

	if (action_sep && action)
	{
		*action = g_strdup (action_sep + 1);
	}

	g_free (dupped);
	return TRUE;
}
