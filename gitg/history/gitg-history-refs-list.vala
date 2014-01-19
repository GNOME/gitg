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

namespace GitgHistory
{

private int ref_type_sort_order(Gitg.RefType ref_type)
{
	switch (ref_type)
	{
		case Gitg.RefType.NONE:
			return 0;
		case Gitg.RefType.BRANCH:
			return 1;
		case Gitg.RefType.REMOTE:
			return 2;
		case Gitg.RefType.TAG:
			return 3;
	}

	return 4;
}

private enum RefAnimation
{
	NONE,
	ANIMATE
}

private interface RefTyped : Object
{
	public abstract Gitg.RefType ref_type { get; }
}

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-history-ref-row.ui")]
private class RefRow : RefTyped, Gtk.ListBoxRow
{
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private Gtk.Image d_icon;

	[GtkChild]
	private Gtk.Label d_label;

	[GtkChild]
	private Gtk.Box d_box;

	[GtkChild]
	private Gtk.Revealer d_revealer;

	public Gitg.Ref? reference { get; set; }

	private Gtk.Entry? d_editing_entry;
	private uint d_idle_finish;

	private GitgExt.RefNameEditingDone? d_edit_done_callback;

	public Gitg.RefType ref_type
	{
		get { return reference != null ? reference.parsed_name.rtype : Gitg.RefType.NONE; }
	}

	public RefRow(Gitg.Ref? reference, RefAnimation animation = RefAnimation.NONE)
	{
		this.reference = reference;

		if (animation == RefAnimation.ANIMATE)
		{
			d_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
		}
		else
		{
			d_revealer.set_reveal_child(true);
		}

		d_label.label = label_text();

		if (is_head)
		{
			d_icon.icon_name = "object-select-symbolic";
			d_icon.show();
		}

		if (reference != null)
		{
			margin_left += 12;
		}

		if (ref_type == Gitg.RefType.REMOTE)
		{
			margin_left += 12;
		}

		d_revealer.notify["child-revealed"].connect(on_child_revealed);
	}

	private void on_child_revealed(Object obj, ParamSpec spec)
	{
		if (!d_revealer.child_revealed)
		{
			Gtk.Allocation alloc;
			d_revealer.get_allocation(out alloc);

			destroy();
		}
	}

	protected override void map()
	{
		base.map();

		d_revealer.set_reveal_child(true);
	}

	private string label_text()
	{
		if (reference == null)
		{
			return _("All commits");
		}

		var pn = reference.parsed_name;

		if (pn.rtype == Gitg.RefType.REMOTE)
		{
			return pn.remote_branch;
		}

		return pn.shortname;
	}

	private bool is_head
	{
		get
		{
			if (reference == null)
			{
				return false;
			}

			var branch = reference as Ggit.Branch;

			if (branch != null)
			{
				try
				{
					return branch.is_head();
				} catch { return false; }
			}

			return false;
		}
	}

	private int compare_type(RefRow other)
	{
		var pnme = reference.parsed_name;
		var pnot = other.reference.parsed_name;

		if (pnme.rtype != pnot.rtype)
		{
			var i1 = ref_type_sort_order(pnme.rtype);
			var i2 = ref_type_sort_order(pnot.rtype);

			return i1 < i2 ? -1 : (i1 > i2 ? 1 : 0);
		}

		if (pnme.rtype == Gitg.RefType.REMOTE)
		{
			return pnme.remote_name.casefold().collate(pnot.remote_name.casefold());
		}

		return 0;
	}

	public int compare_to(RefRow other)
	{
		if (reference == null)
		{
			return -1;
		}

		if (other.reference == null)
		{
			return 1;
		}

		var ct = compare_type(other);

		if (ct != 0)
		{
			return ct;
		}

		var t1 = label_text();
		var t2 = other.label_text();

		var hassep1 = t1.index_of_char('/');
		var hassep2 = t2.index_of_char('/');

		if ((hassep1 >= 0) != (hassep2 >= 0))
		{
			return hassep1 >= 0 ? 1 : -1;
		}

		return t1.casefold().collate(t2.casefold());
	}

	public void begin_editing(owned GitgExt.RefNameEditingDone done)
	{
		if (d_editing_entry != null)
		{
			return;
		}

		d_editing_entry = new Gtk.Entry();
		d_editing_entry.set_width_chars(1);
		d_editing_entry.get_style_context().add_class("ref_editing_entry");
		d_editing_entry.show();

		d_editing_entry.set_text(label_text());

		d_edit_done_callback = (owned)done;

		d_label.hide();
		d_box.pack_start(d_editing_entry);

		d_editing_entry.grab_focus();
		d_editing_entry.select_region(0, -1);

		d_editing_entry.focus_out_event.connect(on_editing_focus_out);
		d_editing_entry.key_press_event.connect(on_editing_key_press);
	}

	public override void dispose()
	{
		if (d_idle_finish != 0)
		{
			Source.remove(d_idle_finish);
			d_idle_finish = 0;
		}

		base.dispose();
	}

	private void finish_editing(bool cancelled)
	{
		if (d_idle_finish != 0)
		{
			return;
		}

		d_editing_entry.focus_out_event.disconnect(on_editing_focus_out);
		d_editing_entry.key_press_event.disconnect(on_editing_key_press);

		d_idle_finish = Idle.add(() => {
			d_idle_finish = 0;

			var new_text = d_editing_entry.text;

			d_editing_entry.destroy();
			d_editing_entry = null;

			d_label.show();

			d_edit_done_callback(new_text, cancelled);
			d_edit_done_callback = null;
			return false;
		});
	}

	private bool on_editing_focus_out(Gtk.Widget widget, Gdk.EventFocus event)
	{
		finish_editing(false);
		return false;
	}

	private bool on_editing_key_press(Gtk.Widget widget, Gdk.EventKey event)
	{
		if (event.keyval == Gdk.Key.Escape)
		{
			finish_editing(true);
			return true;
		}
		else if (event.keyval == Gdk.Key.KP_Enter ||
		         event.keyval == Gdk.Key.Return)
		{
			finish_editing(false);
			return true;
		}

		return false;
	}

	public void unreveal()
	{
		d_revealer.transition_type = Gtk.RevealerTransitionType.SLIDE_DOWN;
		d_revealer.set_reveal_child(false);
	}
}

private class RefHeader : RefTyped, Gtk.ListBoxRow
{
	private Gitg.RefType d_rtype;
	private bool d_is_sub_header_remote;
	private string d_name;
	private Gtk.Label d_label;

	public Gitg.RefType ref_type
	{
		get { return d_rtype; }
	}

	public RefHeader(Gitg.RefType rtype, string name)
	{
		d_label = new Gtk.Label(null);
		d_label.show();

		add(d_label);

		var escaped = Markup.escape_text(name);

		d_label.set_markup(@"<b>$escaped</b>");
		d_label.xalign = 0;

		d_name = name;
		d_rtype = rtype;

		d_label.margin_top = 3;
		d_label.margin_bottom = 3;
		d_label.margin_left = 16;
	}

	public RefHeader.remote(string name)
	{
		this(Gitg.RefType.REMOTE, name);

		d_is_sub_header_remote = true;
		d_label.margin_left += 12;
	}

	public bool is_sub_header_remote
	{
		get { return d_is_sub_header_remote; }
	}

	public int compare_to(RefHeader other)
	{
		// Both are headers of remote type
		if (d_is_sub_header_remote != other.d_is_sub_header_remote)
		{
			return d_is_sub_header_remote ? 1 : -1;
		}

		return d_name.casefold().collate(other.d_name.casefold());
	}
}

public class RefsList : Gtk.ListBox
{
	private Gitg.Repository? d_repository;
	private Gee.HashMap<Gitg.Ref, RefRow> d_ref_map;

	private class RemoteHeader
	{
		public RefHeader header;
		public Gee.HashSet<Gitg.Ref> references;

		public RemoteHeader(RefHeader h)
		{
			header = h;
			references = new Gee.HashSet<Gitg.Ref>();
		}
	}

	private Gee.HashMap<string, RemoteHeader> d_header_map;

	public Gitg.Repository? repository
	{
		get { return d_repository; }
		set
		{
			if (d_repository != value)
			{
				d_repository = value;
			}

			refresh();
		}
	}

	construct
	{
		d_header_map = new Gee.HashMap<string, RemoteHeader>();
		d_ref_map = new Gee.HashMap<Gitg.Ref, RefRow>();
		selection_mode = Gtk.SelectionMode.BROWSE;

		row_selected.connect(on_row_selected);

		set_sort_func(sort_rows);
	}

	private int sort_rows(Gtk.ListBoxRow row1, Gtk.ListBoxRow row2)
	{
		var r1 = ((RefTyped)row1).ref_type;
		var r2 = ((RefTyped)row2).ref_type;

		// Compare types first
		var rs1 = ref_type_sort_order(r1);
		var rs2 = ref_type_sort_order(r2);

		if (rs1 != rs2)
		{
			return rs1 < rs2 ? -1 : 1;
		}

		var head1 = row1 as RefHeader;
		var ref1 = row1 as RefRow;

		var head2 = row2 as RefHeader;
		var ref2 = row2 as RefRow;

		if ((head1 == null) != (head2 == null))
		{
			// Only one is a header
			return head1 != null ? -1 : 1;
		}
		else if (head1 != null && head2 != null)
		{
			return head1.compare_to(head2);
		}
		else
		{
			return ref1.compare_to(ref2);
		}
	}

	private void clear()
	{
		d_header_map = new Gee.HashMap<string, RemoteHeader>();
		d_ref_map = new Gee.HashMap<Gitg.Ref, RefRow>();

		foreach (var child in get_children())
		{
			child.destroy();
		}
	}

	private void add_header(Gitg.RefType ref_type, string name)
	{
		var header = new RefHeader(ref_type, name);
		header.show();

		add(header);
	}

	private void add_remote_header(string name)
	{
		var header = new RefHeader.remote(name);
		header.show();

		d_header_map[name] = new RemoteHeader(header);
		add(header);
	}

	private void add_ref_row(Gitg.Ref? reference, RefAnimation animation = RefAnimation.NONE)
	{
		var row = new RefRow(reference, animation);
		row.show();

		add(row);

		if (reference != null)
		{
			d_ref_map[reference] = row;
		}
	}

	private void add_ref_internal(Gitg.Ref reference, RefAnimation animation = RefAnimation.NONE)
	{
		if (d_ref_map.has_key(reference))
		{
			return;
		}

		if (reference.parsed_name.rtype == Gitg.RefType.REMOTE)
		{
			var remote = reference.parsed_name.remote_name;

			if (!d_header_map.has_key(remote))
			{
				add_remote_header(remote);
			}

			d_header_map[remote].references.add(reference);
		}

		add_ref_row(reference, animation);
	}

	public void add_ref(Gitg.Ref reference)
	{
		add_ref_internal(reference, RefAnimation.ANIMATE);
	}

	public void replace_ref(Gitg.Ref old_ref, Gitg.Ref new_ref)
	{
		bool select = false;

		if (d_ref_map.has_key(old_ref))
		{
			select = (get_selected_row() == d_ref_map[old_ref]);
		}

		remove_ref_internal(old_ref, RefAnimation.ANIMATE);
		add_ref_internal(new_ref, RefAnimation.ANIMATE);

		if (select)
		{
			select_row(d_ref_map[new_ref]);
		}
	}

	// Checks if the provided reference is a symbolic ref with the name HEAD.
	private bool ref_is_a_symbolic_head(Gitg.Ref reference)
	{
		if (reference.get_reference_type() != Ggit.RefType.SYMBOLIC)
		{
			return false;
		}

		string name;

		if (reference.parsed_name.rtype == Gitg.RefType.REMOTE)
		{
			name = reference.parsed_name.remote_branch;
		}
		else
		{
			name = reference.parsed_name.shortname;
		}

		return name == "HEAD";
	}

	private void remove_ref_internal(Gitg.Ref reference, RefAnimation animation = RefAnimation.NONE)
	{
		if (!d_ref_map.has_key(reference))
		{
			return;
		}

		var row = d_ref_map[reference];

		if (animation == RefAnimation.NONE)
		{
			row.destroy();
		}
		else
		{
			row.unreveal();
		}

		d_ref_map.unset(reference);

		if (reference.parsed_name.rtype == Gitg.RefType.REMOTE)
		{
			var remote = reference.parsed_name.remote_name;
			var remote_header = d_header_map[remote];

			remote_header.references.remove(reference);

			if (remote_header.references.is_empty)
			{
				remote_header.header.destroy();
				d_header_map.unset(remote);
			}
		}
	}

	public void remove_ref(Gitg.Ref reference)
	{
		remove_ref_internal(reference);
	}

	public void refresh()
	{
		clear();

		if (d_repository == null)
		{
			return;
		}

		add_ref_row(null);

		add_header(Gitg.RefType.BRANCH, _("Branches"));
		add_header(Gitg.RefType.REMOTE, _("Remotes"));
		add_header(Gitg.RefType.TAG, _("Tags"));

		try
		{
			d_repository.references_foreach_name((nm) => {
				Gitg.Ref? r;

				try
				{
					r = d_repository.lookup_reference(nm);
				} catch { return 0; }

				// Skip symbolic refs named HEAD since they aren't really
				// useful to show (we get these for remotes for example)
				if (ref_is_a_symbolic_head(r))
				{
					return 0;
				}

				add_ref_internal(r);
				return 0;
			});
		} catch {}
	}

	private RefRow? get_ref_row(Gtk.ListBoxRow? row)
	{
		if (row == null)
		{
			return null;
		}

		return row as RefRow;
	}

	private RefHeader? get_ref_header(Gtk.ListBoxRow row)
	{
		return row as RefHeader;
	}

	public Gee.List<Gitg.Ref> all
	{
		owned get
		{
			var ret = new Gee.LinkedList<Gitg.Ref>();

			foreach (var child in get_children())
			{
				var r = get_ref_row(child as Gtk.ListBoxRow);

				if (r != null && r.reference != null)
				{
					ret.add(r.reference);
				}
			}

			try
			{
				if (d_repository.is_head_detached())
				{
					ret.add(d_repository.get_head());
				}
			} catch {}

			return ret;
		}
	}

	[Notify]
	public Gee.List<Gitg.Ref> selection
	{
		owned get
		{
			var row = get_selected_row();

			if (row == null)
			{
				return all;
			}

			var ref_row = get_ref_row(row);
			var ret = new Gee.LinkedList<Gitg.Ref>();

			if (ref_row != null)
			{
				if (ref_row.reference == null)
				{
					return all;
				}
				else
				{
					ret.add(ref_row.reference);
				}
			}
			else
			{
				var ref_header = get_ref_header(row);
				bool found = false;

				foreach (var child in get_children())
				{
					if (found)
					{
						var nrow = child as Gtk.ListBoxRow;
						var nref_row = get_ref_row(nrow);

						if (nref_row == null)
						{
							var nref_header = get_ref_header(nrow);

							if (ref_header.is_sub_header_remote ||
								nref_header.ref_type != ref_header.ref_type)
							{
								break;
							}
						}
						else
						{
							ret.add(nref_row.reference);
						}
					}
					else if (child == row)
					{
						found = true;
					}
				}
			}

			return ret;
		}
	}

	private void on_row_selected(Gtk.ListBoxRow? row)
	{
		notify_property("selection");
	}

	public void edit(Gitg.Ref reference, owned GitgExt.RefNameEditingDone done)
	{
		if (!d_ref_map.has_key(reference))
		{
			done("", true);
			return;
		}

		var row = d_ref_map[reference];
		row.begin_editing((owned)done);
	}
}

}

// ex: ts=4 noet
