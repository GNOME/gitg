/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file.ui")]
class Gitg.DiffViewFile : Gtk.Grid
{
	[GtkChild( name = "expander" )]
	private Gtk.Expander d_expander;

	[GtkChild( name = "label_file_header" )]
	private Gtk.Label d_label_file_header;

	[GtkChild( name = "grid_hunks" )]
	private Gtk.Grid d_grid_hunks;

	[GtkChild( name = "diff_stat_file" )]
	private DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_hunks" )]
	private Gtk.Revealer d_revealer_hunks;

	private bool d_expanded;

	public bool expanded
	{
		get
		{
			return d_expanded;
		}

		set
		{
			if (d_expanded != value)
			{
				d_expanded = value;
				d_revealer_hunks.reveal_child = d_expanded;

				var ctx = get_style_context();

				if (d_expanded)
				{
					ctx.add_class("expanded");
				}
				else
				{
					ctx.remove_class("expanded");
				}
			}
		}
	}

	public bool wrap
	{
		get; set;
	}

	public int tab_width
	{
		get; set;
	}

	public int maxlines
	{
		get; set;
	}

	private bool d_has_selection;

	public bool has_selection
	{
		get { return d_has_selection; }
	}

	public Ggit.DiffDelta delta
	{
		get;
		construct set;
	}

	public bool handle_selection
	{
		get;
		construct set;
	}

	public DiffViewFile(Ggit.DiffDelta delta, bool handle_selection)
	{
		Object(delta: delta, handle_selection: handle_selection);
	}

	protected override void constructed()
	{
		base.constructed();

		var oldfile = delta.get_old_file();
		var newfile = delta.get_new_file();

		var oldpath = (oldfile != null ? oldfile.get_path() : null);
		var newpath = (newfile != null ? newfile.get_path() : null);

		if (delta.get_similarity() > 0)
		{
			d_label_file_header.label = @"$(newfile.get_path()) ← $(oldfile.get_path())";
		}
		else if (newpath != null)
		{
			d_label_file_header.label = newpath;
		}
		else
		{
			d_label_file_header.label = oldpath;
		}

		d_expander.bind_property("expanded", this, "expanded", BindingFlags.BIDIRECTIONAL);
	}

	private void on_selection_changed()
	{
		bool something_selected = false;

		foreach (var child in d_grid_hunks.get_children())
		{
			if ((child as Gitg.DiffViewHunk).has_selection)
			{
				something_selected = true;
				break;
			}
		}

		if (d_has_selection != something_selected)
		{
			d_has_selection = something_selected;
			notify_property("has-selection");
		}
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		var widget = new Gitg.DiffViewHunk(hunk, lines, handle_selection);
		widget.show();

		d_diff_stat_file.added += widget.added;
		d_diff_stat_file.removed += widget.removed;

		d_grid_hunks.add(widget);

		this.bind_property("maxlines", widget, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		this.bind_property("wrap", widget, "wrap", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		this.bind_property("tab-width", widget, "tab-width", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

		widget.notify["has-selection"].connect(on_selection_changed);

		sensitive = true;
	}
}

// ex:ts=4 noet
