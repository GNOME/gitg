/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitg
{

class CommitActionCreateTag : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }

	public CommitActionCreateTag(GitgExt.Application        application,
	                             GitgExt.RefActionInterface action_interface,
	                             Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);
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
