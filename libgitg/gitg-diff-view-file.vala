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

	[GtkChild( name = "diff_stat_file" )]
	private DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_content" )]
	private Gtk.Revealer d_revealer_content;

	private bool d_expanded;

	private Binding? d_vexpand_binding;

	public DiffViewFileRenderer? renderer
	{
		owned get
		{
			return d_revealer_content.get_child() as DiffViewFileRenderer;
		}

		construct set
		{
			var current = this.renderer;

			if (current != value)
			{
				if (d_vexpand_binding != null)
				{
					d_vexpand_binding.unbind();
					d_vexpand_binding = null;
				}

				if (current != null)
				{
					d_revealer_content.remove(current);
				}

				d_revealer_content.add(value);
				d_vexpand_binding = this.bind_property("vexpand", value, "vexpand", BindingFlags.SYNC_CREATE);
			}
		}
	}

	public bool new_is_workdir { get; construct set; }

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
				d_revealer_content.reveal_child = d_expanded;

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

	public Ggit.DiffDelta? delta { get; construct set; }
	public Repository repository { get; construct set; }

	public DiffViewFile(Repository repository, Ggit.DiffDelta delta)
	{
		Object(repository: repository, delta: delta);
	}

	public DiffViewFile.text(Repository repository, Ggit.DiffDelta delta, bool new_is_workdir, bool handle_selection)
	{
		this(repository, delta);

		this.renderer = new DiffViewFileRendererText(repository, delta, new_is_workdir, handle_selection);
		this.renderer.show();

		this.renderer.bind_property("added", d_diff_stat_file, "added");
		this.renderer.bind_property("removed", d_diff_stat_file, "removed");
	}

	public DiffViewFile.binary(Repository repository, Ggit.DiffDelta delta)
	{
		this(repository, delta);
	}

	public DiffViewFile.image(Repository repository, Ggit.DiffDelta delta)
	{
		this(repository, delta);
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
		this.renderer.add_hunk(hunk, lines);
	}
}

// ex:ts=4 noet
