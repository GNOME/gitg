namespace Gitg
{

class RefActionCreateBranch : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionCreateBranch(GitgExt.Application        application,
	                             GitgExt.RefActionInterface action_interface,
	                             Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/create-branch"; }
	}

	public string display_name
	{
		owned get { return _("Create branch"); }
	}

	public string description
	{
		owned get { return _("Create a new branch at the selected reference"); }
	}

	public void activate()
	{
		var dlg = new CreateBranchDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Branch? branch = null;

                var repo = application.repository;

                Commit commit;

                try
				{
					commit = reference.resolve().lookup() as Gitg.Commit;
				}
				catch (Error e)
				{
                    application.show_infobar (_("Failed to lookup reference"),
                                                e.message,
                                                Gtk.MessageType.ERROR);
					return;
				}

				try
				{
					branch = repo.create_branch(dlg.new_branch_name,
					                            commit,
					                            Ggit.CreateFlags.NONE);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to create branch"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				if (branch != null)
				{
					action_interface.add_ref((Gitg.Ref)branch);
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
