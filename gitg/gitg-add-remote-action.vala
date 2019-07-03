namespace Gitg
{

class AddRemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	Gitg.Remote? d_remote;

	public AddRemoteAction(GitgExt.Application application)
	{
		Object(application: application);
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

	//TODO: This code is copy&paste fromGitg.RefActionFetch, would be better to
	//abstract the code to call it from both places 
	public async void fetch_remote(Gitg.Repository repo, string remote_name)
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

		try
		{
			yield d_remote.fetch(null, null);
		}
		catch (Error e)
		{
			try {
				repo.remove_remote(remote_name);
				notification.error(_("Failed to fetch from %s: %s").printf(d_remote.get_url(), e.message));

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
			((Gtk.ApplicationWindow)application).activate_action("reload", null);
		}
		else
		{
			add_remote();
		}
	}

	public void add_remote()
	{
		var dlg = new AddRemoteActionDialog((Gtk.Window)application);
		var remote_added = true;

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Remote? remote = null;
				d_remote = null;

				var repo = application.repository;
				var remote_name = dlg.remote_name;

				try
				{
					remote = repo.create_remote(remote_name,
					                            dlg.remote_url);
				}
				catch (Error e)
				{
					remote_added = false;
					add_remote();
					application.show_infobar(_("Failed to add remote"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				d_remote = application.remote_lookup.lookup(remote_name);

				if (remote != null)
				{
					fetch_remote.begin(repo, remote_name, (obj,res) => {
						fetch_remote.end(res);
					});
				}
			}

			dlg.destroy();
		});

		dlg.show();
	}

	public void activate()
	{
		add_remote();
	}
}

}

// ex:set ts=4 noet
