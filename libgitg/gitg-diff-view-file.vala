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

	[GtkChild( name = "revealer_hunks" )]
	private Gtk.Revealer d_revealer_hunks;

	[GtkChild( name = "sourceview_hunks" )]
	private Gtk.SourceView d_sourceview_hunks;

	private uint d_added;
	private uint d_removed;
	private bool d_expanded;

	private DiffViewFileSelectable d_selectable;

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
		get { return d_sourceview_hunks.wrap_mode != Gtk.WrapMode.NONE; }
		set
		{
			if (value)
			{
				d_sourceview_hunks.wrap_mode = Gtk.WrapMode.WORD_CHAR;
			}
			else
			{
				d_sourceview_hunks.wrap_mode = Gtk.WrapMode.NONE;
			}
		}
	}

	public int tab_width
	{
		get { return (int)d_sourceview_hunks.tab_width; }
		set
		{
			if (value > 0)
			{
				d_sourceview_hunks.tab_width = (uint)value;
			}
		}
	}

	public int maxlines
	{
		get; set;
	}

	public bool has_selection
	{
		get;
		private set;
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

	private DiffViewLinesRenderer d_old_lines;
	private DiffViewLinesRenderer d_new_lines;
	private DiffViewLinesRenderer d_sym_lines;

	construct
	{
		var gutter = d_sourceview_hunks.get_gutter(Gtk.TextWindowType.LEFT);

		d_old_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.OLD);
		d_new_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.NEW);
		d_sym_lines = new DiffViewLinesRenderer(DiffViewLinesRenderer.Style.SYMBOL);

		this.bind_property("maxlines", d_old_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		this.bind_property("maxlines", d_new_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

		d_old_lines.xpad = 8;
		d_new_lines.xpad = 8;
		d_sym_lines.xpad = 6;

		gutter.insert(d_old_lines, 0);
		gutter.insert(d_new_lines, 1);
		gutter.insert(d_sym_lines, 2);

		d_sourceview_hunks.set_border_window_size(Gtk.TextWindowType.TOP, 1);

		var settings = Gtk.Settings.get_default();
		settings.notify["gtk-application-prefer-dark-theme"].connect(update_theme);

		update_theme();

		if (handle_selection)
		{
			d_selectable = new DiffViewFileSelectable(d_sourceview_hunks);

			d_selectable.notify["has-selection"].connect(() => {
				this.has_selection = d_selectable.has_selection;
			});
		}
	}

	private void update_theme()
	{
		var header_attributes = new Gtk.SourceMarkAttributes();
		var added_attributes = new Gtk.SourceMarkAttributes();
		var removed_attributes = new Gtk.SourceMarkAttributes();

		var settings = Gtk.Settings.get_default();

		if (settings.gtk_application_prefer_dark_theme)
		{
			header_attributes.background = Gdk.RGBA() { red = 224.0 / 255.0, green = 239.0 / 255.0, blue = 1.0, alpha = 1.0 };
			added_attributes.background = Gdk.RGBA() { red = 164.0 / 255.0, green = 0.0, blue = 0.0, alpha = 1.0 };
			removed_attributes.background = Gdk.RGBA() { red = 78.0 / 255.0, green = 154.0 / 255.0, blue = 6.0 / 255.0, alpha = 1.0 };
		}
		else
		{
			header_attributes.background = Gdk.RGBA() { red = 224.0 / 255.0, green = 239.0 / 255.0, blue = 1.0, alpha = 1.0 };
			added_attributes.background = Gdk.RGBA() { red = 220.0 / 255.0, green = 1.0, blue = 220.0 / 255.0, alpha = 1.0 };
			removed_attributes.background = Gdk.RGBA() { red = 1.0, green = 220.0 / 255.0, blue = 220.0 / 255.0, alpha = 1.0 };
		}

		d_sourceview_hunks.set_mark_attributes("header", header_attributes, 0);
		d_sourceview_hunks.set_mark_attributes("added", added_attributes, 0);
		d_sourceview_hunks.set_mark_attributes("removed", removed_attributes, 0);
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
		var buffer = d_sourceview_hunks.buffer as Gtk.SourceBuffer;

		/* Diff hunk */
		var h = hunk.get_header();
		var pos = h.last_index_of("@@");

		if (pos >= 0)
		{
			h = h.substring(pos + 2).chug();
		}

		h = h.chomp();

		Gtk.TextIter iter;
		buffer.get_end_iter(out iter);
		if (!iter.is_start())
		{
			buffer.insert(ref iter, "\n", 1);
		}

		iter.set_line_offset(0);
		buffer.create_source_mark(null, "header", iter);

		var header = @"@@ -$(hunk.get_old_start()),$(hunk.get_old_lines()) +$(hunk.get_new_start()),$(hunk.get_new_lines()) @@ $h\n";
		buffer.insert(ref iter, header, -1);

		/* Diff Content */
		var content = new StringBuilder();

		for (var i = 0; i < lines.size; i++)
		{
			var line = lines[i];
			var text = line.get_text();

			switch (line.get_origin())
			{
				case Ggit.DiffLineType.ADDITION:
					d_added++;
					break;
				case Ggit.DiffLineType.DELETION:
					d_removed++;
					break;
				case Ggit.DiffLineType.CONTEXT_EOFNL:
				case Ggit.DiffLineType.ADD_EOFNL:
				case Ggit.DiffLineType.DEL_EOFNL:
					text = text.substring(1);
					break;
			}

			if (i == lines.size - 1 && text.length > 0 && text[text.length - 1] == '\n')
			{
				text = text.slice(0, text.length - 1);
			}

			content.append(text);
		}

		int line_hunk_start = iter.get_line();

		buffer.insert(ref iter, (string)content.data, -1);

		d_old_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, lines);
		d_new_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, lines);
		d_sym_lines.add_hunk(line_hunk_start, iter.get_line(), hunk, lines);

		for (var i = 0; i < lines.size; i++)
		{
			var line = lines[i];
			string? category = null;

			switch (line.get_origin())
			{
				case Ggit.DiffLineType.ADDITION:
					category = "added";
					break;
				case Ggit.DiffLineType.DELETION:
					category = "removed";
					break;
			}

			if (category != null)
			{
				buffer.get_iter_at_line(out iter, line_hunk_start + i);
				buffer.create_source_mark(null, category, iter);
			}
		}

		d_diff_stat_file.added = d_added;
		d_diff_stat_file.removed = d_removed;

		sensitive = true;
	}
}

// ex:ts=4 noet
