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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-hunk.ui")]
class Gitg.DiffViewHunk : Gtk.Grid
{
	private Gtk.Label d_label_hunk;

	[GtkChild( name = "sourceview_hunk" )]
	private Gtk.SourceView d_sourceview_hunk;

	public Ggit.DiffHunk hunk
	{
		get;
		construct set;
	}

	public Gee.ArrayList<Ggit.DiffLine> lines
	{
		get;
		construct set;
	}

	public DiffViewHunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		Object(hunk: hunk, lines: lines);
	}

	private uint d_added;

	public uint added
	{
		get { return d_added; }
	}

	private uint d_removed;

	public uint removed
	{
		get { return d_removed; }
	}

	public int maxlines
	{
		get; set;
	}

	private DiffViewLinesRenderer d_old_lines;
	private DiffViewLinesRenderer d_new_lines;
	private DiffViewLinesRenderer d_sym_lines;

	construct
	{
		var gutter = d_sourceview_hunk.get_gutter(Gtk.TextWindowType.LEFT);

		d_old_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.OLD);
		d_new_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.NEW);
		d_sym_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.SYMBOL);

		this.bind_property("maxlines", d_old_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		this.bind_property("maxlines", d_new_lines, "maxlines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

		d_old_lines.xpad = 8;
		d_new_lines.xpad = 8;
		d_sym_lines.xpad = 6;

		gutter.insert(d_old_lines, 0);
		gutter.insert(d_new_lines, 1);
		gutter.insert(d_sym_lines, 2);

		d_old_lines.notify["size"].connect(update_top_window_size);
		d_new_lines.notify["size"].connect(update_top_window_size);
		d_sym_lines.notify["size"].connect(update_top_window_size);

		update_hunk_label();
		update_lines();

		d_sourceview_hunk.set_border_window_size(Gtk.TextWindowType.TOP, 1);
		d_sourceview_hunk.add_child_in_window(d_label_hunk, Gtk.TextWindowType.TOP, 0, 0);

		d_label_hunk.style_updated.connect(update_top_window_size);
		update_top_window_size();
	}

	private void update_top_window_size()
	{
		int minheight, natheight;
		d_label_hunk.get_preferred_height(out minheight, out natheight);

		if (natheight > 0)
		{
			d_sourceview_hunk.set_border_window_size(Gtk.TextWindowType.TOP, natheight);
		}

		var wx = d_new_lines.size +
		         d_new_lines.xpad * 2 +
		         d_old_lines.size +
		         d_old_lines.xpad * 2 +
		         d_sym_lines.size +
		         d_sym_lines.xpad * 2;

		d_sourceview_hunk.move_child(d_label_hunk, -wx, 0);
	}

	protected override bool map_event(Gdk.EventAny event)
	{
		var ret = base.map_event(event);
		update_top_window_size();
		return ret;
	}

	private void update_hunk_label()
	{
		var h = hunk.get_header();
		var pos = h.last_index_of("@@");

		if (pos >= 0)
		{
			h = h.substring(pos + 2).chug();
		}

		h = h.chomp();
		d_label_hunk = new Gtk.Label(@"@@ -$(hunk.get_old_start()),$(hunk.get_old_lines()) +$(hunk.get_new_start()),$(hunk.get_new_lines()) @@ $h");
		d_label_hunk.halign = Gtk.Align.START;
		d_label_hunk.xalign = 0;
		d_label_hunk.selectable = false;
		d_label_hunk.can_focus = false;
		d_label_hunk.margin_top = 6;
		d_label_hunk.margin_bottom = 6;
		d_label_hunk.show();
	}

	private void update_lines()
	{
		var content = new StringBuilder();

		for (var i = 0; i < lines.size; i++)
		{
			var line = lines[i];
			var text = line.get_text();

			switch (line.get_origin())
			{
				case Ggit.DiffLineType.ADDITION:
					++d_added;
				break;
				case Ggit.DiffLineType.DELETION:
					++d_removed;
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

		var buffer = d_sourceview_hunk.buffer as Gtk.SourceBuffer;

		buffer.set_text((string)content.data);

		var added_attributes = new Gtk.SourceMarkAttributes();
		added_attributes.background = Gdk.RGBA() { red = 220.0 / 255.0, green = 1.0, blue = 220.0 / 255.0, alpha = 1.0 };

		var removed_attributes = new Gtk.SourceMarkAttributes();
		removed_attributes.background = Gdk.RGBA() { red = 1.0, green = 220.0 / 255.0, blue = 220.0 / 255.0, alpha = 1.0 };

		d_sourceview_hunk.set_mark_attributes("added", added_attributes, 0);
		d_sourceview_hunk.set_mark_attributes("removed", removed_attributes, 0);

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
				Gtk.TextIter iter;

				buffer.get_iter_at_line(out iter, i);
				buffer.create_source_mark(null, category, iter);
			}
		}

		notify_property("added");
		notify_property("removed");
	}
}

// ex:ts=4 noet
