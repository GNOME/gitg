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

class EditRemoteAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	string remote_name;
	Gitg.Remote? d_remote;

	public EditRemoteAction(GitgExt.Application        application,
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
		owned get { return "/org/gnome/gitg/ref-actions/edit-remote"; }
	}

	public string display_name
	{
		owned get { return _("Edit remote…"); }
	}

	public string description
	{
		owned get { return _("Reconfigure this remote's name or URL"); }
	}

	public void activate()
	{
		var dlg = new EditRemoteDialog((Gtk.Window)application);

		dlg.new_remote_name = remote_name;
		var old_name = remote_name;
		dlg.new_remote_url = d_remote.get_url();

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				d_remote = null;

				var repo = application.repository;

				try
				{
					if (old_name != dlg.new_remote_name)
						repo.rename_remote(old_name, dlg.new_remote_name);
					repo.set_remote_url(dlg.new_remote_name, dlg.new_remote_url);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to edit remote"),
											 e.message,
					                         Gtk.MessageType.ERROR);
				}

				((Gtk.ApplicationWindow)application).activate_action("reload", null);
			}

			dlg.destroy();
		});

		dlg.show();
	}
}

}

// ex:set ts=4 noet
