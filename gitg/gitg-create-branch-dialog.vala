/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-create-branch-dialog.ui")]
class CreateBranchDialog : Gtk.Dialog
{
	[GtkChild]
	private Gtk.Button d_button_create;

	[GtkChild]
	private Gtk.Entry d_entry_branch_name;

	construct
	{
		d_entry_branch_name.changed.connect(() => {
			d_button_create.sensitive = (new_branch_name.length != 0);
		});

		set_default(d_button_create);
		set_default_response(Gtk.ResponseType.OK);
	}

	public CreateBranchDialog(Gtk.Window? parent)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
	}

	public string new_branch_name
	{
		owned get
		{
			return d_entry_branch_name.text.strip();
		}
	}
}

}

// ex: ts=4 noet
