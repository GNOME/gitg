namespace Gitg
{

class RefActionAddRemote : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionAddRemote(GitgExt.Application        application,
							  	 GitgExt.RefActionInterface action_interface,
							  	 Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
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
		var dlg = new AddRemoteDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Remote? remote = null;

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
			}

			dlg.destroy();
			finished();
		});

		dlg.show();
	}
}

}

// ex:set ts=4 noet
