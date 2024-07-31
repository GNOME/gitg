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

class RefActionFetch : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	private Gitg.Ref? d_remote_ref;
	private Gitg.Remote? d_remote;
	string remote_name;

	public RefActionFetch(GitgExt.Application        application,
	                      GitgExt.RefActionInterface action_interface,
	                      Gitg.Ref?                   reference, string? remote_name = null)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);

		if (reference != null)
		{
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
				this.remote_name = d_remote_ref.parsed_name.remote_name;
			}
		}
		else
		{
			this.remote_name = remote_name;
		}
		d_remote = application.remote_lookup.lookup(this.remote_name);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/fetch"; }
	}

	public string display_name
	{
		owned get
		{
			if (d_remote != null)
			{
				return _("Fetch from %s").printf(remote_name);
			}
			else
			{
				return "";
			}
		}
	}

	public string description
	{
		owned get { return _("Fetch remote objects from %s").printf(remote_name); }
	}

	public bool available
	{
		get { return d_remote != null; }
	}

	public async bool fetch()
	{
		var notification = new RemoteNotification(d_remote);
		application.notifications.add(notification);

		notification.text = _("Fetching from <a href='%s'>%s</a>").printf(d_remote.get_url(), d_remote.get_name());

		var updates = new Gee.ArrayList<string>();

		var tip_updated_id = d_remote.tip_updated.connect((d_remote, name, a, b) => {
			if (a.is_zero())
			{
				/* Translators: new refers to a new remote reference having been fetched, */
				updates.add(@"%s (%s)".printf(name, _("new")));
			}
			else
			{
				/* Translators: updated refers to a remote reference having been updated, */
				updates.add(@"%s (%s)".printf(name, _("updated")));
			}
		});

		try
		{
			yield d_remote.fetch(null, null);
		}
		catch (Error e)
		{
			notification.error(_("Failed to fetch from <a href='%s'>%s</a>: <b>%s</b>").printf(d_remote.get_url(), d_remote.get_name(), e.message));
			stderr.printf("Failed to fetch: %s\n", e.message);

			return false;
		}
		finally
		{
			((Object)d_remote).disconnect(tip_updated_id);
		}

		if (updates.size == 0)
		{
			/* Translators: the %s will get replaced with the remote url, */
			notification.success(_("Fetched from <a href='%s'>%s</a>: <b>everything is up to date</b>").printf(d_remote.get_url(), d_remote.get_name()));
		}
		else
		{
			/* Translators: the first %s is the remote url to fetch from,
			 * the second is a list of references that got updated. */
			notification.success(_("Fetched from %s: %s").printf(d_remote.get_url(), string.joinv(", ", updates.to_array())));
		}

		return true;
	}

	public void activate()
	{
		fetch.begin((obj, res) => {
			fetch.end(res);
		});
	}
}

}

// ex:set ts=4 noet
