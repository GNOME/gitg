/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

public class Gitg.DiffStat : Gtk.DrawingArea
{
	private uint d_added;
	private uint d_removed;

	private Pango.Layout d_layout;
	
	private const int BAR_HEIGHT = 5; //TODO expose bar height via CSS min-height
	
	public uint added
	{
		get { return d_added; }
		set
		{
			d_added = value;
			make_layout();
		}
	}

	public uint removed
	{
		get { return d_removed; }
		set
		{
			d_removed = value;
			make_layout();
		}
	}

	static construct
	{
		set_css_name("gitg-diffstat");
	}

	construct
	{
		make_layout();
	}

	private void make_layout()
	{
		var txt = @"$(added + removed)";

		if (d_layout == null)
		{
			d_layout = create_pango_layout(txt);
		}
		else
		{
			d_layout.set_text(txt, txt.length);
		}

		queue_resize();
	}

	public override void css_changed(Gtk.CssStyleChange change)
	{
		base.css_changed(change);

		d_layout = null;

		var dark = new Theme().is_theme_dark();

		if (dark)
		{
			get_style_context().add_class("dark");
		}
		else
		{
			get_style_context().remove_class("dark");
		}

		make_layout();
	}

	public override void snapshot(Gtk.Snapshot snapshot)
	{
		// Draw added/removed bars in center
		var sctx = get_style_context();
		var padding = sctx.get_padding();
		var border = sctx.get_border();

		var h = get_allocated_height();
		var w = get_allocated_width();

		snapshot.render_background(sctx, 0, 0, w, h);
		snapshot.render_frame(sctx, 0, 0, w, h);

		Pango.Rectangle rect;
		d_layout.get_extents(null, out rect);

		var rtl = (sctx.get_state() & Gtk.StateFlags.DIR_RTL) != 0;
		int x;

		if (!rtl)
		{
			x = padding.left + border.left + rect.x / Pango.SCALE;
		}
		else
		{
			x = w - padding.right - border.right - rect.width / Pango.SCALE;
		}

		snapshot.render_layout(sctx,
		                   x,
		                   (h - rect.height / Pango.SCALE) / 2 + rect.y / Pango.SCALE,
		                   d_layout);

		int hbar = BAR_HEIGHT;

		var ybar = (h - hbar) / 2;

		var wrest = (int)(w - padding.left * 2 - (rect.x + rect.width) / Pango.SCALE - padding.right - border.left - border.right);

		double afrac = 0;
		var total = added + removed;

		if (total != 0)
		{
			afrac = added / (double)total;
		}

		var wbar = (int)(wrest * afrac);

		if (!rtl)
		{
			x += padding.left + rect.width / Pango.SCALE;
		}
		else
		{
			x -= padding.right + wbar;
		}

		if (added == 0 && removed == 0)
		{
			sctx.save();
			snapshot.render_background(sctx, x, ybar, wrest, hbar);
			sctx.restore();
		}
		else if (added == 0 || removed == 0)
		{
			sctx.save();
			sctx.add_class(added == 0 ? "removed-only" : "added-only");
			snapshot.render_background(sctx, x, ybar, wrest, hbar);
			sctx.restore();
		}
		else
		{
			sctx.save();
			sctx.add_class("added");
			snapshot.render_background(sctx, x, ybar, wbar, hbar);
			sctx.restore();

			sctx.save();
			sctx.add_class("removed");
			x += rtl ? (wbar - wrest) : wbar;
			snapshot.render_background(sctx,
			                       x,
			                       ybar,
			                       wrest - wbar,
			                       hbar);
			sctx.restore();
		}
	}


	public override void measure(Gtk.Orientation orientation, int for_size, out int minimum, out int natural, out int minimum_baseline, out int natural_baseline)
	{
		minimum_baseline = -1;
		natural_baseline = -1;

		var sctx = get_style_context();
		var padding = sctx.get_padding();
		var border = sctx.get_border();

		if (orientation == Gtk.Orientation.VERTICAL)
		{
			Pango.Rectangle rect;
			d_layout.get_extents(null, out rect);

			int h = padding.top + padding.bottom + border.top + border.bottom;
			int hlbl = (rect.height + rect.y) / Pango.SCALE;

			h += int.max(hlbl, BAR_HEIGHT);

			minimum = h;
			natural = h;
		}
		else
		{
			Pango.Rectangle rect;
			d_layout.get_extents(out rect, null);

			var width = padding.left + padding.right + border.left + border.right + (rect.width + rect.x) / Pango.SCALE;

			minimum = width;
			natural = 75;
		}
	}
}

// ex:ts=4 noet
