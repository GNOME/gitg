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
	[GtkChild( name = "label_hunk" )]
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

	construct
	{
		var gutter = d_sourceview_hunk.get_gutter(Gtk.TextWindowType.LEFT);

		var old_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.OLD);
		var new_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.NEW);
		var sym_lines = new DiffViewLinesRenderer(hunk, lines, DiffViewLinesRenderer.Style.SYMBOL);

		old_lines.xpad = 8;
		new_lines.xpad = 8;
		sym_lines.xpad = 6;

		gutter.insert(old_lines, 0);
		gutter.insert(new_lines, 1);
		gutter.insert(sym_lines, 2);

		update_hunk_label();
		update_lines();
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
		d_label_hunk.label = @"@@ -$(hunk.get_old_start()),$(hunk.get_old_lines()) +$(hunk.get_new_start()),$(hunk.get_new_lines()) @@ $h";
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

		d_sourceview_hunk.buffer.set_text((string)content.data);

		notify_property("added");
		notify_property("removed");
	}
}

// ex:ts=4 noet
