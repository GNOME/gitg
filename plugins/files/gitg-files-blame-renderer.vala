/*
 * This file is part of gitg
 *
 * Copyright (C) 2024 - Alberto Fanjul
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

class GitgFiles.BlameRenderer : Gtk.SourceGutterRendererText
{
	private Ggit.Blame? d_blame;
	private Ggit.OId? d_last_oid;
	private int d_max_author_len;
	private uint32 d_max_line;
	private Gee.HashMap<string, double?> d_commit_hues;

	public signal void commit_clicked(Ggit.OId oid);

	construct
	{
		set_alignment(0.0f, 0.5f);
		d_max_author_len = 0;
		d_max_line = 0;
		d_commit_hues = new Gee.HashMap<string, double?>();
	}

	private static void hsl_to_rgb(double h, double s, double l, out double r, out double g, out double b)
	{
		if (s == 0)
		{
			r = g = b = l;
			return;
		}

		double q = l < 0.5 ? l * (1 + s) : l + s - l * s;
		double p = 2 * l - q;

		r = hue_to_rgb(p, q, h + 1.0 / 3.0);
		g = hue_to_rgb(p, q, h);
		b = hue_to_rgb(p, q, h - 1.0 / 3.0);
	}

	private static double hue_to_rgb(double p, double q, double t)
	{
		if (t < 0) t += 1;
		if (t > 1) t -= 1;
		if (t < 1.0 / 6.0) return p + (q - p) * 6 * t;
		if (t < 1.0 / 2.0) return q;
		if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6;
		return p;
	}

	public void set_blame(Ggit.Blame? blame)
	{
		d_blame = blame;
		d_last_oid = null;
		d_max_author_len = 0;
		d_max_line = 0;
		d_commit_hues.clear();

		if (blame != null)
		{
			var count = blame.get_hunk_count();
			double golden_ratio = 0.618033988749895;
			double hue = 0.0;

			for (uint32 i = 0; i < count; i++)
			{
				var hunk = blame.get_hunk_by_index(i);
				var sig = hunk.get_final_signature();
				if (sig != null)
				{
					var name = sig.get_name();
					if (name != null && name.length > d_max_author_len)
					{
						d_max_author_len = name.length;
					}
				}

				uint32 hunk_end = (uint32)hunk.get_final_start_line_number() + (uint32)hunk.get_lines_in_hunk() - 1;
				if (hunk_end > d_max_line)
				{
					d_max_line = hunk_end;
				}

				var oid = hunk.get_final_commit_id();
				if (oid != null)
				{
					var oid_str = oid.to_string();
					if (!d_commit_hues.has_key(oid_str))
					{
						d_commit_hues[oid_str] = hue;
						hue += golden_ratio;
						if (hue > 1.0) hue -= 1.0;
					}
				}
			}
			if (d_max_author_len > 20)
			{
				d_max_author_len = 20;
			}
		}

		recalculate_size();
		queue_draw();
	}

	private void recalculate_size()
	{
		if (d_blame == null)
		{
			set_size(0);
			return;
		}

		// "abc1234 Author Name  2024-01-01"
		var sample = string.nfill(8 + 1 + d_max_author_len + 2 + 10, 'W');
		int width = 0;
		int height = 0;
		measure(sample, out width, out height);
		set_size(width);
	}

	private string get_commit_color(string oid_str)
	{
		var hue_val = d_commit_hues[oid_str];
		if (hue_val == null)
		{
			return "#888888";
		}

		var context = get_view().get_style_context();
		var bg = context.get_background_color(context.get_state());
		bool is_dark = (bg.red + bg.green + bg.blue) / 3.0 < 0.5;

		double r, g, b;
		double lightness = is_dark ? 0.7 : 0.35;
		hsl_to_rgb(hue_val, 0.7, lightness, out r, out g, out b);

		return "#%02x%02x%02x".printf(
			(int)(r * 255).clamp(0, 255),
			(int)(g * 255).clamp(0, 255),
			(int)(b * 255).clamp(0, 255));
	}

	protected override void draw(Cairo.Context cr, Gdk.Rectangle background_area, Gdk.Rectangle cell_area, Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state)
	{
		base.draw(cr, background_area, cell_area, start, end, state);

		var context = get_view().get_style_context();
		var fg = context.get_color(context.get_state());

		cr.save();
		cr.set_source_rgba(fg.red, fg.green, fg.blue, 0.35);
		cr.set_line_width(1.0);

		double left_x = background_area.x + 0.5;
		double right_x = background_area.x + background_area.width - 0.5;
		cr.move_to(left_x, background_area.y);
		cr.line_to(left_x, background_area.y + background_area.height);
		cr.move_to(right_x, background_area.y);
		cr.line_to(right_x, background_area.y + background_area.height);
		cr.stroke();

		if (d_blame != null)
		{
			uint32 line = (uint32)(start.get_line() + 1);

			if (line >= 1 && line <= d_max_line)
			{
				var hunk = d_blame.get_hunk_by_line(line);
				var start_line = (uint32)hunk.get_final_start_line_number();

				if (line == start_line && line > 1)
				{
					cr.move_to(background_area.x, background_area.y + 0.5);
					cr.line_to(background_area.x + background_area.width, background_area.y + 0.5);
					cr.stroke();
				}
			}
		}

		cr.restore();
	}

	protected override void query_data(Gtk.TextIter start, Gtk.TextIter end, Gtk.SourceGutterRendererState state)
	{
		if (d_blame == null)
		{
			set_text("", -1);
			return;
		}

		uint32 line = (uint32)(start.get_line() + 1);

		if (line < 1 || line > d_max_line)
		{
			set_text("", -1);
			return;
		}

		var hunk = d_blame.get_hunk_by_line(line);
		var start_line = (uint32)hunk.get_final_start_line_number();

		if (line == start_line)
		{
			var oid = hunk.get_final_commit_id();
			if (oid == null)
			{
				set_text("", -1);
				return;
			}

			var oid_str = oid.to_string();
			var short_id = oid_str != null && oid_str.length >= 7 ? oid_str.substring(0, 7) : "???????";

			var sig = hunk.get_final_signature();
			var author = "";
			var date = "";

			if (sig != null)
			{
				author = sig.get_name() ?? "";
				if (author.length > d_max_author_len)
				{
					author = author.substring(0, d_max_author_len);
				}

				var dt = sig.get_time();
				if (dt != null)
				{
					date = dt.format("%Y-%m-%d");
				}
			}

			var padded_author = "%-*s".printf(d_max_author_len, author);
			var commit_color = get_commit_color(oid_str);
			var esc_id = Markup.escape_text(short_id);
			var esc_author = Markup.escape_text(padded_author);
			var esc_date = Markup.escape_text(date);
			set_markup(@"<span foreground=\"$(commit_color)\">$(esc_id)</span> $(esc_author)  <span foreground=\"#5b9bd5\">$(esc_date)</span>", -1);
		}
		else
		{
			set_text("", -1);
		}
	}

	protected override bool query_activatable(Gtk.TextIter iter, Gdk.Rectangle area, Gdk.Event event)
	{
		if (d_blame == null)
		{
			return false;
		}

		uint32 line = (uint32)(iter.get_line() + 1);

		if (line < 1 || line > d_max_line)
		{
			return false;
		}

		var hunk = d_blame.get_hunk_by_line(line);
		return line == (uint32)hunk.get_final_start_line_number();
	}

	protected override void activate(Gtk.TextIter iter, Gdk.Rectangle area, Gdk.Event event)
	{
		if (d_blame == null)
		{
			return;
		}

		uint32 line = (uint32)(iter.get_line() + 1);

		if (line < 1 || line > d_max_line)
		{
			return;
		}

		var hunk = d_blame.get_hunk_by_line(line);
		var oid = hunk.get_final_commit_id();
		if (oid != null)
		{
			commit_clicked(oid);
		}
	}
}

// ex: ts=4 noet
