/*
 * This file is part of gitg
 *
 * Copyright (C) 2025 - Alberto Fanjul
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-push-dialog.ui")]
class PushDialog : Gtk.Dialog
{
	[GtkChild]
	private unowned Gtk.Button d_button_push;

	[GtkChild]
	private unowned Gtk.Entry d_local_ref;

	[GtkChild]
	private unowned Gtk.ComboBoxText d_remote_name;

	[GtkChild]
	private unowned Gtk.ComboBoxText d_remote_ref_name;

	[GtkChild]
	private unowned Gtk.RadioButton d_local_ref_tag;

	[GtkChild]
	private unowned Gtk.RadioButton d_local_ref_branch;

	[GtkChild]
	private unowned Gtk.RadioButton d_local_ref_commit;

	[GtkChild]
	private unowned Gtk.RadioButton d_remote_ref_tag;

	[GtkChild]
	private unowned Gtk.RadioButton d_remote_ref_branch;

	[GtkChild]
	private unowned Gtk.RadioButton d_remote_ref_custom;

	[GtkChild]
	private unowned Gtk.CheckButton d_force;

	[GtkChild]
	private unowned Gtk.CheckButton d_upstream;

	[GtkChild]
	private unowned Gtk.CheckButton d_smart;

	[GtkChild]
	private unowned Gtk.Button d_button_restart;

	private Gitg.Repository d_repository;
	private Object d_reference;
	private Gitg.Ref? d_remote_reference;
	public bool smart {get { return d_smart.active;} set {d_smart.active = value;}}

	construct
	{
		d_remote_name.changed.connect(input_changed);
		d_remote_ref_name.changed.connect(input_changed);

		d_remote_name.changed.connect(update_remote_ref_entries);

		d_remote_ref_branch.toggled.connect(update_remote_ref_entries);
		d_remote_ref_tag.toggled.connect(update_remote_ref_entries);
		d_remote_ref_custom.toggled.connect(update_remote_ref_entries);
		d_button_restart.clicked.connect(update_remote_entries);
		d_force.toggled.connect(update_force);

		set_default(d_button_push);
		set_default_response(Gtk.ResponseType.OK);
	}

	private void input_changed () {
		var full_info_filled = (remote_name != null) && (remote_ref_name != "");
		set_response_sensitive(Gtk.ResponseType.OK, full_info_filled);
		var push_from_to_branches = d_local_ref_branch.active && d_remote_ref_branch.active;
		if (push_from_to_branches) {
			var remote_is_upstream_branch = false;
			var r = d_reference as Gitg.Ref;
			if (r != null)
			{
				if (r.is_branch())
				{
					var branch = r as Gitg.Branch;
					try
					{
						var upstream = branch.get_upstream();
						remote_is_upstream_branch = upstream.parsed_name.remote_branch == remote_ref_name;
					} catch {}
				}
			}
			d_upstream.sensitive = full_info_filled && !remote_is_upstream_branch;
		}
	}

	public PushDialog(Gtk.Window? parent, Gitg.Repository? repository, Object reference, bool smart = false)
	{
		Object(use_header_bar : 1, smart : smart);

		if (parent != null)
		{
			set_transient_for(parent);
		}

		if (repository != null)
		{
			d_repository = repository;
		}

		d_reference = reference;

		var r = d_reference as Gitg.Ref;
		if (r != null)
		{
			d_local_ref.set_text(r.parsed_name.shortname);
			if (r.is_branch())
			{
				var branch = r as Gitg.Branch;
				try
				{
					var upstream = branch.get_upstream();
					d_remote_reference = upstream;
				} catch {}
				d_local_ref_branch.active = true;
			} else if (r.is_tag())
			{
				d_local_ref_tag.active = true;
			} else
			{
				d_local_ref_commit.active = true;
			}
		}
		else
		{
			var commit = d_reference as Gitg.Commit;
			d_local_ref.set_text(commit.get_id().to_string());
			d_local_ref_commit.active = true;
		}
		//Avoid to trigger smart load until all info is collected
		d_smart.toggled.connect(update_smart);
	}

	public string local_ref
	{
		owned get
		{
			return d_local_ref.text.strip();
		}
	}

	public string remote_name
	{
		owned get
		{
			return d_remote_name.get_active_text();
		}
	}

	public string remote_ref_name
	{
		owned get
		{
			return d_remote_ref_name.get_active_text();
		}
	}

	public string remote_ref
	{
		owned get
		{
			var prefix = "";
			var remote_name = d_remote_ref_name.get_active_text();
			if (d_remote_ref_branch.active)
			{
				prefix = "refs/heads/";
			}
			else if (d_remote_ref_tag.active)
			{
				prefix = "refs/tags/";
			}
			//else if (d_remote_ref_custom.active)
			return @"$prefix$remote_name";
		}
	}

	public bool force
	{
		get
		{
			return d_force.active;
		}
	}

	public bool set_upstream
	{
		get
		{
			return d_upstream.active;
		}
	}
	public override void show()
	{
		base.show();

		update_remote_entries();
	}

	private void update_force()
	{
		var ctx = d_button_push.get_style_context();
		if (d_force.active) {
			ctx.remove_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
			ctx.add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
		} else {
			ctx.remove_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
			ctx.add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
		}
	}

	private void update_smart()
	{
		update_remote_entries();
	}

	private void update_remote_entries()
	{
		var r = d_reference as Gitg.Ref;
		if (r != null)
		{
			if (r.is_branch())
			{
				d_remote_ref_branch.active = true;
			}
			else if (r.is_tag())
			{
				d_remote_ref_tag.active = true;
			}
			else
			{
				d_remote_ref_custom.active = true;
			}
		}
		else
		{
			d_remote_ref_custom.active = true;
		}
		d_remote_name.remove_all();
		var remotes =d_repository.list_remotes();
		foreach (var remote_name in remotes) {
			d_remote_name.append(remote_name, remote_name);
		}

		if(d_remote_reference != null)
			d_remote_name.set_active_id(d_remote_reference.parsed_name.remote_name);
		else if (smart && remotes.length == 1)
			d_remote_name.set_active_id(remotes[0]);
		else if (smart && remotes.length > 1)
			try {
				var main_remote = Gitg.Utils.get_config_value(d_repository, "gitg.main-remote", "origin");
				var gremotes = new Gee.ArrayList<string>.wrap(remotes);
				if (gremotes.contains(main_remote))
					d_remote_name.set_active_id(main_remote);
			} catch {}
	}

	private void update_remote_ref_entries()
	{
		d_remote_ref_name.remove_all();
		var entry = d_remote_ref_name.get_child () as Gtk.Entry;
		entry.set_text("");
		var remote_selected = d_remote_name.get_active_id();
		if (remote_selected == null)
			return;

		try
		{
			d_repository.references_foreach_name((name) => {
				Gitg.Ref? reference;
				try
				{
					reference = d_repository.lookup_reference(name);
					var type = reference.get_reference_type();
				} catch { return 0; }

				if (d_remote_ref_branch.active)
				{
					if (!reference.is_remote()
						|| (reference.get_reference_type() == Ggit.RefType.SYMBOLIC)
						|| (reference.parsed_name.remote_name != remote_selected))
					{
						return 0;
					}
					var remote_ref = reference.parsed_name.remote_branch;
					d_remote_ref_name.append(remote_ref, remote_ref);
				}
				if (d_remote_ref_tag.active && reference.is_tag())
				{
					var remote_ref = reference.parsed_name.shortname;
					d_remote_ref_name.append(remote_ref, remote_ref);
				}
				return 0;

			});
		} catch {}

		if(d_remote_reference != null)
			d_remote_ref_name.set_active_id(d_remote_reference.parsed_name.remote_branch);
		else if (smart) {
			var r = d_reference as Gitg.Ref;
			if (r != null)
				if (r.is_branch() || r.is_tag())
					entry.set_text(r.parsed_name.shortname);
		}
	}
}

}

// ex: ts=4 noet
