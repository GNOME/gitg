#include "gitg-revision-panel.h"

static void gitg_revision_panel_default_init (GitgRevisionPanelInterface *iface);

GType
gitg_revision_panel_get_type ()
{
	static GType gitg_revision_panel_type_id = 0;
	
	if (!gitg_revision_panel_type_id)
	{
		static const GTypeInfo g_define_type_info =
		{
			sizeof (GitgRevisionPanelInterface),
			(GBaseInitFunc) gitg_revision_panel_default_init,
			NULL,
			NULL,
			NULL,
			NULL,
			0,
			0,
			NULL
		};
		
		gitg_revision_panel_type_id = g_type_register_static (G_TYPE_INTERFACE,
		                                                      "GitgRevisionPanel",
		                                                      &g_define_type_info,
		                                                      0);
	}

	return gitg_revision_panel_type_id;
}

/* Default implementation */
static void
gitg_revision_panel_initialize_default (GitgRevisionPanel *panel,
                                        GitgWindow        *window)
{
	/* No default implementation */
}

static gchar *
gitg_revision_panel_get_id_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static gchar *
gitg_revision_panel_get_label_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static GtkWidget *
gitg_revision_panel_get_panel_default (GitgRevisionPanel *panel)
{
	g_return_val_if_reached (NULL);
}

static void
gitg_revision_panel_update_default (GitgRevisionPanel *panel,
                                    GitgRepository    *repository,
                                    GitgRevision      *revision)
{
	/* No default implementation */
}

static void
gitg_revision_panel_default_init (GitgRevisionPanelInterface *iface)
{
	static gboolean initialized = FALSE;

	iface->initialize = gitg_revision_panel_initialize_default;
	iface->get_id = gitg_revision_panel_get_id_default;
	iface->get_label = gitg_revision_panel_get_label_default;
	iface->get_panel = gitg_revision_panel_get_panel_default;
	iface->update = gitg_revision_panel_update_default;

	if (!initialized)
	{
		initialized = TRUE;
	}
}

gchar *
gitg_revision_panel_get_id (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_id (panel);
}

gchar *
gitg_revision_panel_get_label (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_label (panel);
}

GtkWidget *
gitg_revision_panel_get_panel (GitgRevisionPanel *panel)
{
	g_return_val_if_fail (GITG_IS_REVISION_PANEL (panel), NULL);

	return GITG_REVISION_PANEL_GET_INTERFACE (panel)->get_panel (panel);
}

void
gitg_revision_panel_update (GitgRevisionPanel *panel,
                            GitgRepository    *repository,
                            GitgRevision      *revision)
{
	g_return_if_fail (GITG_IS_REVISION_PANEL (panel));

	GITG_REVISION_PANEL_GET_INTERFACE (panel)->update (panel,
	                                                  repository,
	                                                  revision);
}

void
gitg_revision_panel_initialize (GitgRevisionPanel *panel,
                                GitgWindow        *window)
{
	g_return_if_fail (GITG_IS_REVISION_PANEL (panel));
	g_return_if_fail (GITG_IS_WINDOW (window));

	GITG_REVISION_PANEL_GET_INTERFACE (panel)->initialize (panel,
	                                                       window);
}

