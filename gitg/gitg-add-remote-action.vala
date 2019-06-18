namespace Gitg
{

class AddRemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	Gitg.Remote? d_remote;

	public AddRemoteAction(GitgExt.Application        application)
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
		var dlg = new AddRemoteActionDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Remote? remote = null;
				d_remote = null;

				var repo = application.repository;
				var new_remote_name = dlg.new_remote_name;
				var remote_added = true;

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

					remote_added = false;
				}

				d_remote = application.remote_lookup.lookup(new_remote_name);

				if (remote_added)
				{
					var notification = new RemoteNotification(d_remote);
					application.notifications.add(notification);

					notification.text = _("Fetching from %s").printf(d_remote.get_url());

					var updates = new Gee.ArrayList<string>();

					var tip_updated_id = d_remote.tip_updated.connect((d_remote, name, a, b) => {
						/* Translators: new refers to a new remote reference having been fetched, */
						updates.add(@"%s (%s)".printf(name, _("new")));
					});

					var fetched = true;

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
								notification.error(_("Failed to fetch from %s: %s").printf(d_remote.get_url(), e.message));
								stderr.printf("Failed to fetch: %s\n", e.message);

								fetched = false;
							}
							catch {}
							application.show_infobar(_("Failed to fetch added remote"),
													e.message,
													Gtk.MessageType.ERROR);
						}
						finally
						{
							((Object)d_remote).disconnect(tip_updated_id);
						}

						if (fetched)
						{
							notification.success(_("Fetched from %s: %s").printf(d_remote.get_url(), string.joinv(", ", updates.to_array())));
						}
					});
				}
			}

			dlg.destroy();
		});

		dlg.show();
	}
}

}

// ex:set ts=4 noet
