namespace Gitg
{

class RefActionAddRemote : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }
	Gitg.Ref? d_remote_ref;
	Gitg.Remote? d_remote;

	public RefActionAddRemote(GitgExt.Application        application,
							  GitgExt.RefActionInterface action_interface,
							  Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
			   reference:        reference);

		var branch = reference as Ggit.Branch;

		if (branch != null)
		{
			try
			{
				d_remote_ref = branch.get_upstream() as Gitg.Ref;
			} catch {}
		}
		else if (reference.parsed_name.remote_name != null)
		{
			d_remote_ref = reference;
		}

		if (d_remote_ref != null)
		{
			d_remote = application.remote_lookup.lookup(d_remote_ref.parsed_name.remote_name);
		}
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

	public bool available
	{
		get { return d_remote != null; }
	}

	public void activate()
	{
		var dlg = new AddRemoteDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Remote? remote = null;
				d_remote = null;

				var repo = application.repository;

				try
				{
					remote = repo.create_remote(dlg.new_remote_name,
												dlg.new_remote_url);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to add remote"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				d_remote = application.remote_lookup.lookup(dlg.new_remote_name);

				d_remote.fetch.begin (null, null, (obj, res) => {
					try
					{
						d_remote.fetch.end(res);
						((Gtk.ApplicationWindow)application).activate_action("reload", null);
					}
					catch (Error e)
					{
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
