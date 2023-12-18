/*
 * This file is part of gitg
 *
 * Copyright (C) 2017 - Ignazio Sgalmuzzo
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

class RefActionPush : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	private Gitg.Remote? d_remote;

	public RefActionPush(GitgExt.Application        application,
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
				var d_remote_ref = branch.get_upstream() as Gitg.Ref;
				d_remote = application.remote_lookup.lookup(d_remote_ref.parsed_name.remote_name);
			} catch {}
		}
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/push"; }
	}

	public string display_name
	{
		owned get
		{
			if (d_remote != null)
			{
				return _("Push to %s").printf(d_remote.get_name());
			}
			else
			{
				return "";
			}
		}
	}

	public string description
	{
		owned get { return _("Push branch to %s").printf(d_remote.get_name()); }
	}

	public bool available
	{
		get
		{
			return (d_remote != null) && reference.is_branch() && ((Gitg.Branch)reference).get_upstream() != null;
		}
	}

	public async bool push(string branch)
	{
		var notification = new RemoteNotification(d_remote);
		application.notifications.add(notification);

		notification.text = _("Pushing to %s").printf(d_remote.get_url());

		try
		{
			yield d_remote.push(branch, null);
			((Gtk.ApplicationWindow)application).activate_action("reload", null);
		}
		catch (Error e)
		{
			notification.error(_("Failed to push to %s: %s").printf(d_remote.get_url(), e.message));
			stderr.printf("Failed to push: %s\n", e.message);

			return false;
		}

		/* Translators: the %s will get replaced with the remote url, */
		notification.success(_("Pushed to %s").printf(d_remote.get_url()));

		return true;
	}

	public void activate()
	{
		var query = new GitgExt.UserQuery();

		var branch_name = reference.get_shorthand();

		query.title = (_("Push branch %s")).printf(branch_name);
		query.message = (_("Are you sure that you want to push the branch %s?")).printf(branch_name);

		query.set_responses(new GitgExt.UserQueryResponse[] {
			new GitgExt.UserQueryResponse(_("Cancel"), Gtk.ResponseType.CANCEL),
			new GitgExt.UserQueryResponse(_("Push"), Gtk.ResponseType.OK)
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

		var branch_name = reference.get_shorthand();

		push.begin(branch_name, (obj, res) => {
			push.end(res);
		});

		return true;
	}
}

}

// ex:set ts=4 noet
