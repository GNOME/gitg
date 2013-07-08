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
		install_style_property(new ParamSpecInt("bar-height",
		                                        "bar height",
		                                        "bar height",
		                                        0,
		                                        int.MAX,
		                                        5,
		                                        ParamFlags.READWRITE |
		                                        ParamFlags.STATIC_STRINGS));
	}

	construct
	{
		make_layout();

		var css = new Gtk.CssProvider();

		var fb = @"
			GitgDiffStat {
				border: 1px inset shade(@borders, 1.2);
				border-radius: 5px;
				background-color: shade(@theme_bg_color, 1.2);
				-GitgDiffStat-bar-height: 5px;
			}

			GitgDiffStat added,
			GitgDiffStat removed {
				border: 0;
			}

			GitgDiffStat added {
				background-color: #33cc33;
				border-radius: 3px 0px 0px 3px;
			}

			GitgDiffStat removed {
				background-color: #cc3333;
				border-radius: 0px 3px 3px 0px;
			}

			GitgDiffStat removed:only-child,
			GitgDiffStat added:only-child {
				border-radius: 3px;
			}
		";

		try
		{
			css.load_from_data(fb, fb.length);
		}
		catch (Error e)
		{
			warning("Failed to load diff-stat style: %s", e.message);
		}

		get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_FALLBACK);

		css = new Gtk.CssProvider();

		var us = @"
			GitgDiffStat {
				padding: 1px 5px 1px 3px;
			}
		";

		try
		{
			css.load_from_data(us, us.length);
		}
		catch (Error e)
		{
			warning("Failed to load diff-stat style: %s", e.message);
		}

		get_style_context().add_provider(css, Gtk.STYLE_PROVIDER_PRIORITY_USER);
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

	protected override void style_updated()
	{
		base.style_updated();

		d_layout = null;

		make_layout();
	}

	protected override bool draw(Cairo.Context context)
	{
		// Draw added/removed bars in center
		var sctx = get_style_context();
		var padding = sctx.get_padding(get_state_flags());
		var border = sctx.get_border(get_state_flags());

		var h = get_allocated_height();
		var w = get_allocated_width();

		sctx.render_background(context, 0, 0, w, h);
		sctx.render_frame(context, 0, 0, w, h);

		Pango.Rectangle rect;
		d_layout.get_extents(null, out rect);

		sctx.render_layout(context,
		                   padding.left + border.left + rect.x / Pango.SCALE,
		                   (h - rect.height / Pango.SCALE) / 2 + rect.y / Pango.SCALE,
		                   d_layout);

		int hbar;
		sctx.get_style("bar-height", out hbar);
		var ybar = (h - hbar) / 2;

		var xbar = padding.left * 2 + border.left + (rect.x + rect.width) / Pango.SCALE;
		var wrest = (int)(w - padding.left * 2 - (rect.x + rect.width) / Pango.SCALE - padding.right - border.left - border.right);

		double afrac = 0;
		var total = added + removed;

		if (total != 0)
		{
			afrac = added / (double)total;
		}

		var wbar = (int)(wrest * afrac);

		sctx.save();
		sctx.add_region("added",
		                Gtk.RegionFlags.FIRST |
		                (removed == 0 ? Gtk.RegionFlags.ONLY : 0));

		sctx.render_background(context, xbar, ybar, wbar, hbar);

		sctx.restore();
		sctx.save();

		sctx.add_region("removed",
		                Gtk.RegionFlags.LAST |
		                (added == 0 ? Gtk.RegionFlags.ONLY : 0));

		sctx.render_background(context,
		                       xbar + wbar,
		                       ybar,
		                       wrest - wbar,
		                       hbar);

		sctx.restore();

		return false;
	}

	protected override void get_preferred_height(out int minimum_height,
	                                             out int natural_height)
	{
		var sctx = get_style_context();
		var padding = sctx.get_padding(get_state_flags());
		var border = sctx.get_border(get_state_flags());

		Pango.Rectangle rect;
		d_layout.get_extents(null, out rect);

		int h = padding.top + padding.bottom + border.top + border.bottom;
		int hlbl = (rect.height + rect.y) / Pango.SCALE;

		int bar_height;
		sctx.get_style("bar-height", out bar_height);

		h += int.max(hlbl, bar_height);

		minimum_height = h;
		natural_height = h;
	}

	protected override void get_preferred_width(out int minimum_width,
	                                            out int natural_width)
	{
		var sctx = get_style_context();
		var padding = sctx.get_padding(get_state_flags());
		var border = sctx.get_border(get_state_flags());

		Pango.Rectangle rect;
		d_layout.get_extents(out rect, null);

		var w = padding.left + padding.right + border.left + border.right + (rect.width + rect.x) / Pango.SCALE;

		minimum_width = w;
		natural_width = 75;
	}
}

// ex:ts=4 noet
