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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-add-remote-action-dialog.ui")]
class AddRemoteActionDialog : Gtk.Dialog
{
	[GtkChild]
	private unowned Gtk.Button d_button_create;

	[GtkChild]
	private unowned Gtk.Entry d_entry_remote_name;

	[GtkChild]
	private unowned Gtk.Entry d_entry_remote_url;

	construct
	{
		d_entry_remote_name.changed.connect(input_changed);
		d_entry_remote_url.changed.connect(input_changed);

		set_default(d_button_create);
		set_default_response(Gtk.ResponseType.OK);
	}

	private void input_changed () {
		bool is_name_valid = d_entry_remote_name.text != "";
		bool is_url_valid = d_entry_remote_url.text != "";

		set_response_sensitive(Gtk.ResponseType.OK, is_name_valid && is_url_valid);
	}

	public AddRemoteActionDialog(Gtk.Window? parent)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
	}

	public string remote_name
	{
		owned get
		{
			return d_entry_remote_name.text.strip();
		}

		set
		{
		   d_entry_remote_name.text = value.strip();
		}
	}

	public string remote_url
	{
		owned get
		{
			return d_entry_remote_url.text.strip();
		}

		set
		{
		   d_entry_remote_url.text = value.strip();
		}
	}
}

}

// ex: ts=4 noet
