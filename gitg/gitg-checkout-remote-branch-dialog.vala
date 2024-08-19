/*
 * This file is part of gitg
 *
 * Copyright (C) 2020 - Armandas Jarušauskas
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-checkout-remote-branch-dialog.ui")]
class CheckoutRemoteBranchDialog : Gtk.Dialog
{
	[GtkChild]
	private unowned Gtk.Button d_button_create;

	[GtkChild]
	private unowned Gtk.Entry d_branch_name;

	[GtkChild]
	private unowned Gtk.ComboBoxText d_remote_branch_name;

	[GtkChild]
	private unowned Gtk.CheckButton d_track_remote;

	private Gitg.Repository d_repository;
	private Gitg.Ref d_remote_reference;

	construct
	{
		d_branch_name.changed.connect(input_changed);
		d_remote_branch_name.changed.connect(input_changed);

		set_default(d_button_create);
		set_default_response(Gtk.ResponseType.OK);
	}

	private void input_changed () {
		set_response_sensitive(Gtk.ResponseType.OK, (new_branch_name != "") && (d_remote_branch_name.get_active_text() != null));
	}

	public CheckoutRemoteBranchDialog(Gtk.Window? parent, Gitg.Repository? repository, Gitg.Ref reference)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}

		if (repository != null)
		{
			d_repository = repository;
		}

		if (reference.is_remote())
		{
			d_remote_reference = reference;
		}
	}

	public string new_branch_name
	{
		owned get
		{
			return d_branch_name.text.strip();
		}
	}

	public string remote_branch_name
	{
		owned get
		{
			return d_remote_branch_name.get_active_text();
		}
	}

	public bool track_remote
	{
		get
		{
			return d_track_remote.active;
		}
	}

	public override void show()
	{
		base.show();

		update_entries();
	}

	private void update_entries()
	{
		d_branch_name.set_text(d_remote_reference.parsed_name.remote_branch);

		try
		{
			d_repository.references_foreach_name((name) => {
				Gitg.Ref? reference;
				try
				{
					reference = d_repository.lookup_reference(name);
				} catch { return 0; }

				if (!reference.is_remote() || (reference.get_reference_type() == Ggit.RefType.SYMBOLIC))
				{
					return 0;
				}

				d_remote_branch_name.append(reference.parsed_name.shortname, reference.parsed_name.shortname);

				return 0;
			});
		} catch {}

		d_remote_branch_name.set_active_id(d_remote_reference.parsed_name.shortname);
	}
}

}

// ex: ts=4 noet
