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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-set-upstream-branch-dialog.ui")]
class SetUpstreamBranchDialog : Gtk.Dialog
{
	[GtkChild]
	private unowned Gtk.Button d_button_set_upstream;

	[GtkChild]
	private unowned Gtk.Entry d_branch_name;

	[GtkChild]
	private unowned Gtk.ComboBoxText d_remote_branch_name;

	private Gitg.Repository d_repository;
	private Ggit.Ref? d_remote_reference;
	private Ggit.Branch d_branch;

	public string branch_name;

	construct
	{
		set_default(d_button_set_upstream);
		set_default_response(Gtk.ResponseType.OK);
		d_remote_branch_name.changed.connect(input_changed);
	}

	private void input_changed () {
		var upstream_name = "";
		try
		{
			var upstream = d_branch.get_upstream();
			if (upstream != null)
				upstream_name = upstream.get_shorthand();
		} catch {}
		set_response_sensitive(Gtk.ResponseType.OK, upstream_name != d_remote_branch_name.get_active_text());
	}


	public SetUpstreamBranchDialog(Gtk.Window? parent, Gitg.Repository? repository, Gitg.Ref reference)
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

		d_branch_name.set_text(reference.get_shorthand());

		try
		{
			d_branch = reference as Gitg.Branch;
			d_remote_reference = d_branch.get_upstream();
		}
		catch (Error e)
		{
		}
	}

	public string remote_branch_name
	{
		owned get
		{
			return d_remote_branch_name.get_active_text();
		}
	}

	public override void show()
	{
		base.show();

		update_entries();
	}

	private void update_entries()
	{
		try
		{
			d_remote_branch_name.append("", "");
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
			if (d_remote_reference != null) {
				d_remote_branch_name.set_active_id(d_remote_reference.get_shorthand());
			}

		} catch {}
	}
}

}

// ex: ts=4 noet
