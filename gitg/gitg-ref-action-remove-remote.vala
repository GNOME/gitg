namespace Gitg
{

class RefActionRemoveRemote : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }
	Gitg.Ref? d_remote_ref;
	Gitg.Remote? d_remote;

	public RefActionRemoveRemote(GitgExt.Application        application,
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
		owned get { return "/org/gnome/gitg/ref-actions/remove-remote"; }
	}

	public string display_name
	{
		owned get { return _("Remove remote"); }
	}

	public string description
	{
		owned get { return _("Removes remote from the remotes list"); }
	}

	public bool available
	{
		get { return d_remote != null; }
	}

	public void activate()
	{
        var query = new GitgExt.UserQuery();

		var remote_name = d_remote_ref.parsed_name.remote_name;

		query.title = (_("Delete remote %s")).printf(remote_name);
		query.message = (_("Are you sure that you want to remove the remote %s?")).printf(remote_name);

		query.set_responses(new GitgExt.UserQueryResponse[] {
			new GitgExt.UserQueryResponse(_("Cancel"), Gtk.ResponseType.CANCEL),
			new GitgExt.UserQueryResponse(_("Remove"), Gtk.ResponseType.OK)
        });

        query.default_response = Gtk.ResponseType.OK;
		query.response.connect(on_response);

		action_interface.application.user_query(query);
    }

	private bool on_response(Gtk.ResponseType response)
	{
		if (response != Gtk.ResponseType.OK)
		{
			return true;
		}

		var repo = application.repository;

		try
		{
			repo.remove_remote(d_remote.get_name());
		}
		catch (Error e)
		{
			application.show_infobar(_("Failed to remove remote"),
			                    	 e.message,
			                         Gtk.MessageType.ERROR);
		}

		((Gtk.ApplicationWindow)application).activate_action("reload", null);
		return true;
	}
}

}

// ex:set ts=4 noet
