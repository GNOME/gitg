namespace Gitg
{

class RefActionCreateTag : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionCreateTag(GitgExt.Application        application,
	                             GitgExt.RefActionInterface action_interface,
	                             Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/create-tag"; }
	}

	public string display_name
	{
		owned get { return _("Create tag"); }
	}

	public string description
	{
		owned get { return _("Create a new tag at the selected commit"); }
	}

	public void activate()
	{
		var dlg = new CreateTagDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.OId? tagid = null;

				var repo = application.repository;

				var msg = Ggit.message_prettify(dlg.new_tag_message, false, '#');
                var name = dlg.new_tag_name;

                Commit commit;

                try
				{
					commit = reference.resolve().lookup() as Gitg.Commit;
				}
				catch (Error e)
				{
                    application.show_infobar (_("Failed to lookup commit"),
                                                e.message,
                                                Gtk.MessageType.ERROR);
					return;
				}

				try
				{
					if (msg.length == 0)
					{
						tagid = repo.create_tag_lightweight(name,
						                                    commit,
						                                    Ggit.CreateFlags.NONE);
					}
					else
					{
						Ggit.Signature? author = null;

						try
						{
							author = repo.get_signature_with_environment(application.environment);
						} catch {}

						tagid = repo.create_tag(name, commit, author, msg, Ggit.CreateFlags.NONE);
					}
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to create tag"),
					                         e.message,
					                         Gtk.MessageType.ERROR);

					tagid = null;
				}

				Ggit.Ref? tag = null;

				if (tagid != null)
				{
					try
					{
						tag = repo.lookup_reference(@"refs/tags/$name");
					}
					catch (Error e)
					{
						application.show_infobar(_("Failed to lookup tag"),
						                         e.message,
						                         Gtk.MessageType.ERROR);
					}
				}

				if (tag != null)
				{
					action_interface.add_ref((Gitg.Ref)tag);
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
