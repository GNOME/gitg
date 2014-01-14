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

private interface RefTyped : Object
{
	public abstract Gitg.RefType ref_type { get; }
}

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-history-ref-row.ui")]
private class RefRow : RefTyped, Gtk.Box
{
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private Gtk.Image d_icon;

	[GtkChild]
	private Gtk.Label d_label;

	public Gitg.Ref? reference { get; set; }

	public Gitg.RefType ref_type
	{
		get { return reference != null ? reference.parsed_name.rtype : Gitg.RefType.NONE; }
	}

	public RefRow(Gitg.Ref? reference)
	{
		Object(orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);

		this.reference = reference;

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
}

private class RefHeader : RefTyped, Gtk.Label
{
	private Gitg.RefType d_rtype;
	private bool d_is_sub_header_remote;
	private string d_name;

	public Gitg.RefType ref_type
	{
		get { return d_rtype; }
	}

	public RefHeader(Gitg.RefType rtype, string name)
	{
		var escaped = Markup.escape_text(name);

		set_markup(@"<b>$escaped</b>");
		xalign = 0;

		d_name = name;
		d_rtype = rtype;

		margin_top = 3;
		margin_bottom = 3;
		margin_left = 16;
	}

	public RefHeader.remote(string name)
	{
		this(Gitg.RefType.REMOTE, name);
		d_is_sub_header_remote = true;
		margin_left += 12;
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
	public signal void edited(Gitg.Ref reference, Gtk.TreePath path, string text);
	public signal void ref_activated(Gitg.Ref? r);

	private Gitg.Repository? d_repository;
	private Gee.HashMap<string, RefHeader> d_remote_headers;

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
		d_remote_headers = new Gee.HashMap<string, RefHeader>();
		set_sort_func(sort_rows);
	}

	private int sort_rows(Gtk.ListBoxRow row1, Gtk.ListBoxRow row2)
	{
		var c1 = row1.get_child();
		var c2 = row2.get_child();

		var r1 = ((RefTyped)c1).ref_type;
		var r2 = ((RefTyped)c2).ref_type;

		// Compare types first
		var rs1 = ref_type_sort_order(r1);
		var rs2 = ref_type_sort_order(r2);

		if (rs1 != rs2)
		{
			return rs1 < rs2 ? -1 : 1;
		}

		var head1 = c1 as RefHeader;
		var ref1 = c1 as RefRow;

		var head2 = c2 as RefHeader;
		var ref2 = c2 as RefRow;

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
		d_remote_headers = new Gee.HashMap<string, RefHeader>();

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

	private RefHeader add_remote_header(string name)
	{
		var header = new RefHeader.remote(name);
		header.show();

		add(header);

		return header;
	}

	private void add_ref(Gitg.Ref? reference)
	{
		var row = new RefRow(reference);
		row.show();

		add(row);
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

	public void refresh()
	{
		clear();

		if (d_repository == null)
		{
			return;
		}

		add_ref(null);

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

				if (r.parsed_name.rtype == Gitg.RefType.REMOTE)
				{
					var remote = r.parsed_name.remote_name;

					if (!d_remote_headers.has_key(remote))
					{
						d_remote_headers[remote] = add_remote_header(remote);
					}
				}

				add_ref(r);
				return 0;
			});
		} catch {}
	}

	private RefRow? get_ref_row(Gtk.ListBoxRow row)
	{
		return row.get_child() as RefRow;
	}

	protected override void row_activated(Gtk.ListBoxRow row)
	{
		var r = get_ref_row(row);

		if (r != null)
		{
			ref_activated(r.reference);
		}
	}
}

}

// ex: ts=4 noet
