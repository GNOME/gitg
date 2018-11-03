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

class Gitg.DiffViewLinesRenderer : Gtk.SourceGutterRendererText
{
	public enum Style
	{
		OLD,
		NEW,
		SYMBOL
	}

	private int d_num_digits;
	private string d_num_digits_fill;

	private ulong d_view_style_updated_id;

	private struct HunkInfo
	{
		int start;
		int end;
		int hunk_line;
		Ggit.DiffHunk hunk;
		string[] line_infos;
	}

	private Gee.ArrayList<HunkInfo?> d_hunks_list;

	public Style style
	{
		get; construct set;
	}

	private int d_maxlines;

	public int maxlines
	{
		get { return d_maxlines; }
		set
		{
			if (value > d_maxlines)
			{
				d_maxlines = value;

				calculate_num_digits();
				recalculate_size();
			}
		}
	}

	public DiffViewLinesRenderer(Style style)
	{
		Object(style: style);
	}

	construct
	{
		d_hunks_list = new Gee.ArrayList<HunkInfo?>();

		set_alignment(1.0f, 0.5f);
		calculate_num_digits();
	}

	protected Gtk.TextBuffer buffer
	{
		get { return get_view().buffer; }
	}

	protected override void query_data(Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state)
	{
		var line = start.get_line();
		bool is_hunk = false;
		HunkInfo? info = null;

		foreach (var i in d_hunks_list)
		{
			if (line == i.hunk_line)
			{
				is_hunk = true;
				break;
			}
			else if (line >= i.start && line <= i.end)
			{
				info = i;
				break;
			}
		}

		if (info == null || (line - info.start) >= info.line_infos.length)
		{
			if (is_hunk && style != Style.SYMBOL)
			{
				set_text("...", -1);
			}
			else
			{
				set_text("", -1);
			}
		}
		else
		{
			set_text(info.line_infos[start.get_line() - info.start], -1);
		}
	}

	private void on_view_style_updated()
	{
		recalculate_size();
	}

	protected override void change_view(Gtk.TextView? old_view)
	{
		if (old_view != null)
		{
			old_view.disconnect(d_view_style_updated_id);
			d_view_style_updated_id = 0;
		}

		var view = get_view();

		if (view != null)
		{
			d_view_style_updated_id = view.style_updated.connect(on_view_style_updated);
			recalculate_size();
		}

		base.change_view(old_view);
	}

	private void recalculate_size()
	{
		int size = 0;
		int height = 0;

		measure(@"$d_num_digits_fill", out size, out height);
		set_size(size);
	}

	private void calculate_num_digits()
	{
		int num_digits;

		if (style == Style.OLD || style == Style.NEW)
		{
			num_digits = 3;

			foreach (var info in d_hunks_list)
			{
				var oldn = info.hunk.get_old_start() + info.hunk.get_old_lines();
				var newn = info.hunk.get_new_start() + info.hunk.get_new_lines();

				var num = int.max(int.max(oldn, newn), d_maxlines);

				var hunk_digits = 0;
				while (num > 0)
				{
					++hunk_digits;
					num /= 10;
				}

				num_digits = int.max(num_digits, hunk_digits);
			}
		}
		else
		{
			num_digits = 1;
		}

		d_num_digits = num_digits;
		d_num_digits_fill = string.nfill(num_digits, ' ');
	}

	private string[] precalculate_line_strings(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		var oldn = hunk.get_old_start();
		var newn = hunk.get_new_start();

		var lns = lines;

		var line_infos = new string[lns.size];

		for (var i = 0; i < lns.size; i++)
		{
			var line = lns[i];
			var origin = line.get_origin();

			string ltext = "";

			switch (style)
			{
			case Style.NEW:
				if (origin == Ggit.DiffLineType.CONTEXT || origin == Ggit.DiffLineType.ADDITION)
				{
					ltext = "%*d".printf(d_num_digits, newn);
					newn++;
				}
				break;
			case Style.OLD:
				if (origin == Ggit.DiffLineType.CONTEXT || origin == Ggit.DiffLineType.DELETION)
				{
					ltext = "%*d".printf(d_num_digits, oldn);
					oldn++;
				}
				break;
			case Style.SYMBOL:
				if (origin == Ggit.DiffLineType.ADDITION)
				{
					ltext = "+";
				}
				else if (origin == Ggit.DiffLineType.DELETION)
				{
					ltext = "-";
				}
				break;
			}

			line_infos[i] = ltext;
		}

		return line_infos;
	}

	public void add_hunk(int buffer_line_start, int buffer_line_end, Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		HunkInfo info = HunkInfo();

		calculate_num_digits();

		info.start = buffer_line_start;
		info.end = buffer_line_end;
		info.hunk_line = buffer_line_start - 1;
		info.hunk = hunk;
		info.line_infos = precalculate_line_strings(hunk, lines);

		d_hunks_list.add(info);

		recalculate_size();
	}
}

// ex:ts=4 noet
