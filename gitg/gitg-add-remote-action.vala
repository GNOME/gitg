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

class AddRemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	private Gitg.Remote? d_remote;
	private Gitg.Repository? repo;
	private string? remote_name;
	private string? remote_url;

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
		owned get { return _("Add a new remote…"); }
	}

	public string description
	{
		owned get { return _("Configure a new remote to add to the remotes list"); }
	}

	public async bool fetch()
	{
		var notification = new RemoteNotification(d_remote);
		application.notifications.add(notification);

		notification.text = _("Fetching from %s").printf(d_remote.get_url());

		var updates = new Gee.ArrayList<string>();

		var tip_updated_id = d_remote.tip_updated.connect((d_remote, name, a, b) => {
			/* Translators: new refers to a new remote reference having been fetched, */
			updates.add(@"%s (%s)".printf(name, _("new")));
		});

		try
		{
			yield d_remote.fetch(null, null);
		}
		catch (Error e)
		{
			try {
				notification.error(_("Failed to fetch from %s: %s").printf(d_remote.get_url(), e.message));
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

		((Gtk.ApplicationWindow)application).activate_action("reload", null);
		if (updates.size != 0)
		{
			notification.success(_("Fetched from %s: %s").printf(d_remote.get_url(), string.joinv(", ", updates.to_array())));
		}
		else
		{
			add_remote(remote_name, remote_url);

			return false;
		}

		return true;
	}

	public void add_remote(owned string? name = "", owned string? url = "")
	{
		var dlg = new AddRemoteActionDialog((Gtk.Window)application);

		remote_name = name;
		remote_url = url;
		dlg.remote_name = remote_name;
		dlg.remote_url = remote_url;

		dlg.response.connect((d, resp) => {
			if (resp != Gtk.ResponseType.OK)
			{
				dlg.destroy();
				return;
			}

			Ggit.Remote? remote = null;
			d_remote = null;

			repo = application.repository;
			remote_name = dlg.remote_name;
			remote_url = dlg.remote_url;

			try
			{
				remote = repo.create_remote(remote_name,
				                            remote_url);
			}
			catch (Error e)
			{
				application.show_infobar(_("Failed to add remote"),
				                         e.message,
				                         Gtk.MessageType.ERROR);
				return;
			}

			d_remote = application.remote_lookup.lookup(remote_name);

			if (remote != null)
			{
				fetch.begin((obj,res) => {
					fetch.end(res);
				});
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
