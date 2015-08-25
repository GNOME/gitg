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

	public int maxlines
	{
		get; set;
	}

	public Ggit.DiffDelta delta
	{
		get;
		construct set;
	}

	public DiffViewFile(Ggit.DiffDelta delta)
	{
		Object(delta: delta);
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

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		var widget = new Gitg.DiffViewHunk(hunk, lines);
		widget.show();

		d_diff_stat_file.added += widget.added;
		d_diff_stat_file.removed += widget.removed;

		d_grid_hunks.add(widget);

		this.bind_property("maxlines", widget, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

		sensitive = true;
	}
}

// ex:ts=4 noet
