namespace Gitg
{

class RemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	Gitg.Remote? d_remote;

	public RemoteAction(GitgExt.Application        application)
	{
		Object(application:      application);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/add-remote"; }
	}

	public string display_name
	{
		owned get { return _("Add Remote"); }
	}

	public string description
	{
		owned get { return _("Adds remote to the remotes list"); }
	}

	public void activate()
	{
		var dlg = new RemoteActionDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Remote? remote = null;
				d_remote = null;

				var repo = application.repository;
				var new_remote_name = dlg.new_remote_name;

				try
				{
					remote = repo.create_remote(new_remote_name,
												dlg.new_remote_url);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to add remote"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				d_remote = application.remote_lookup.lookup(new_remote_name);

				d_remote.fetch.begin (null, null, (obj, res) => {
					try
					{
						d_remote.fetch.end(res);
						((Gtk.ApplicationWindow)application).activate_action("reload", null);
					}
					catch (Error e)
					{
						try {
							repo.remove_remote(new_remote_name);
						}
						catch {}
						application.show_infobar(_("Failed to fetch added remote"),
												e.message,
												Gtk.MessageType.ERROR);
					}
				});
			}

			dlg.destroy();
		});

		dlg.show();
	}
}

}

// ex:set ts=4 noet
