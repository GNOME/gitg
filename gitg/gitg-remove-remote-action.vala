/*
 * This file is part of gitg
 *
 * Copyright (C) 2022 - Adwait Rawat
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

class RemoveRemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	string remote_name;
	Gitg.Remote? d_remote;

	public RemoveRemoteAction(GitgExt.Application        application,
				  GitgExt.RefActionInterface action_interface,
				  string                     remote_name)
	{
		Object(application:      application,
		       action_interface: action_interface);
                this.remote_name = remote_name;
		d_remote = application.remote_lookup.lookup(remote_name);
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

	public void activate()
	{
        var query = new GitgExt.UserQuery();

		query.title = _("Confirm remote deletion");
		query.message = (_("Are you sure that you want to remove the remote <b><i>“%s”</i></b>?")).printf(remote_name);
		query.message_use_markup = true;

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
			repo.remove_remote(remote_name);
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
