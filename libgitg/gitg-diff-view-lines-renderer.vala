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
	private string d_num_digits_fmts;
	private string d_num_digits_fill;

	private ulong d_view_style_updated_id;

	private string[] d_line_infos;

	public Ggit.DiffHunk hunk
	{
		get; construct set;
	}

	public Gee.ArrayList<Ggit.DiffLine> lines
	{
		get; construct set;
	}

	public Style style
	{
		get; construct set;
	}

	public DiffViewLinesRenderer(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines, Style style)
	{
		Object(hunk: hunk, lines: lines, style: style);
	}

	protected override void constructed()
	{
		calulate_num_digits();
		precalculate_line_strings();
	}

	private void precalculate_line_strings()
	{
		var oldn = hunk.get_old_start();
		var newn = hunk.get_new_start();

		var lns = lines;

		d_line_infos = new string[lns.size];

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
					ltext = d_num_digits_fmts.printf(newn);
					newn++;
				}
				break;
			case Style.OLD:
				if (origin == Ggit.DiffLineType.CONTEXT || origin == Ggit.DiffLineType.DELETION)
				{
					ltext = d_num_digits_fmts.printf(oldn);
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

			d_line_infos[i] = ltext;
		}
	}

	protected Gtk.TextBuffer buffer
	{
		get { return get_view().buffer; }
	}

	protected override void query_data(Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state)
	{
		var line = start.get_line();

		if (line >= d_line_infos.length)
		{
			set_text("", -1);
		}
		else
		{
			set_text(d_line_infos[start.get_line()], -1);
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

	private void calulate_num_digits()
	{
		var num_digits = 0;

		if (style == Style.OLD || style == Style.NEW)
		{
			var oldn = hunk.get_old_start() + hunk.get_old_lines();
			var newn = hunk.get_new_start() + hunk.get_new_lines();

			var num = int.max(oldn, newn);

			while (num > 0)
			{
				++num_digits;
				num /= 10;
			}

			d_num_digits = int.max(2, num_digits);
		}
		else
		{
			num_digits = 1;
		}

		d_num_digits_fmts = @"%$(num_digits)d";
		d_num_digits_fill = string.nfill(num_digits, ' ');
	}
}

// ex:ts=4 noet
