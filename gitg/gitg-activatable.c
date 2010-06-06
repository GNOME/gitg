#include "gitg-activatable.h"

G_DEFINE_INTERFACE (GitgActivatable, gitg_activatable, G_TYPE_INVALID)

/* Default implementation */
static gchar *
gitg_activatable_get_id_default (GitgActivatable *panel)
{
	g_return_val_if_reached (NULL);
}

static gboolean
gitg_activatable_activate_default (GitgActivatable *panel,
                                      gchar const       *cmd)
{
	return FALSE;
}

static void
gitg_activatable_default_init (GitgActivatableInterface *iface)
{
	static gboolean initialized = FALSE;

	iface->get_id = gitg_activatable_get_id_default;
	iface->activate = gitg_activatable_activate_default;

	if (!initialized)
	{
		initialized = TRUE;
	}
}

gchar *
gitg_activatable_get_id (GitgActivatable *panel)
{
	g_return_val_if_fail (GITG_IS_ACTIVATABLE (panel), NULL);

	return GITG_ACTIVATABLE_GET_INTERFACE (panel)->get_id (panel);
}

gboolean
gitg_activatable_activate (GitgActivatable *panel,
                           gchar const     *action)
{
	g_return_val_if_fail (GITG_IS_ACTIVATABLE (panel), FALSE);

	return GITG_ACTIVATABLE_GET_INTERFACE (panel)->activate (panel, action);
}
