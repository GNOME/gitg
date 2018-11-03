/*
 * This file is part of gitg
 *
 * Copyright (C) 2016 - Jesse van den Kieboom
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

class Gitg.DiffImageSideBySide : Gtk.DrawingArea
{
	private Pango.Layout d_old_size_layout;
	private Pango.Layout d_new_size_layout;

	private const int TEXT_SPACING = 6;

	private Pango.Layout? old_size_layout
	{
		get
		{
			if (d_old_size_layout == null && cache.old_pixbuf != null)
			{
				string message = @"$(cache.old_pixbuf.get_width()) × $(cache.old_pixbuf.get_height())";

				if (cache.new_pixbuf != null)
				{
					// Translators: this label is displayed below the image diff, %s
					// is substituted with the size of the image
					d_old_size_layout = create_pango_layout(_("before (%s)").printf(message));
				}
				else
				{
					// Translators: this label is displayed below the image diff, %s
					// is substituted with the size of the image
					d_old_size_layout = create_pango_layout(_("removed (%s)").printf(message));
				}
			}

			return d_old_size_layout;
		}
	}

	private Pango.Layout? new_size_layout
	{
		get
		{
			if (d_new_size_layout == null && cache.new_pixbuf != null)
			{
				string message = @"$(cache.new_pixbuf.get_width()) × $(cache.new_pixbuf.get_height())";

				if (cache.old_pixbuf != null)
				{
					// Translators: this label is displayed below the image diff, %s
					// is substituted with the size of the image
					d_new_size_layout = create_pango_layout(_("after (%s)").printf(message));
				}
				else
				{
					// Translators: this label is displayed below the image diff, %s
					// is substituted with the size of the image
					d_new_size_layout = create_pango_layout(_("added (%s)").printf(message));
				}
			}

			return d_new_size_layout;
		}
	}

	public Gitg.DiffImageSurfaceCache cache { get; set; }
	public int spacing { get; set; }

	private struct Size
	{
		public int width;

		public int image_width;
		public int image_height;
	}

	private struct Sizing
	{
		public Size old_size;
		public Size new_size;
	}

	private Sizing get_sizing(int width)
	{
		double ow = 0, oh = 0, nw = 0, nh = 0;

		var old_pixbuf = cache.old_pixbuf;
		var new_pixbuf = cache.new_pixbuf;

		var window = get_window();

		if (old_pixbuf != null)
		{
			double xscale = 1, yscale = 1;

			if (window != null)
			{
				cache.get_old_surface(get_window()).get_device_scale(out xscale, out yscale);
			}

			ow = (double)old_pixbuf.get_width() / xscale;
			oh = (double)old_pixbuf.get_height() / yscale;
		}

		if (new_pixbuf != null)
		{
			double xscale = 1, yscale = 1;

			if (window != null)
			{
				cache.get_new_surface(get_window()).get_device_scale(out xscale, out yscale);
			}

			nw = (double)new_pixbuf.get_width() / xscale;
			nh = (double)new_pixbuf.get_height() / yscale;
		}

		var tw = ow + nw;

		width -= spacing;

		double osw = 0, nsw = 0;

		if (tw != 0)
		{
			if (ow != 0)
			{
				osw = width * (ow / tw);
			}

			if (nw != 0)
			{
				nsw = width * (nw / tw);
			}
		}

		var oswi = double.min(osw, ow);
		var nswi = double.min(nsw, nw);

		double oshi = 0, nshi = 0;

		if (ow != 0)
		{
			oshi = oswi / ow * oh;
		}

		if (nw != 0)
		{
			nshi = nswi / nw * nh;
		}

		return Sizing() {
			old_size = Size() {
				width = (int)osw,

				image_width = (int)oswi,
				image_height = (int)oshi
			},

			new_size = Size() {
				width = (int)nsw,

				image_width = (int)nswi,
				image_height = (int)nshi
			}
		};
	}

	protected override void style_updated()
	{
		d_old_size_layout = null;
		d_new_size_layout = null;
	}

	protected override void get_preferred_height_for_width(int width, out int minimum_height, out int natural_height)
	{
		var sizing = get_sizing(width);
		var h = double.max(sizing.old_size.image_height, sizing.new_size.image_height);

		var ol = old_size_layout;
		var nl = new_size_layout;

		int osw = 0, osh = 0, nsw = 0, nsh = 0;

		if (ol != null)
		{
			ol.get_pixel_size(out osw, out osh);
		}

		if (nl != null)
		{
			nl.get_pixel_size(out nsw, out nsh);
		}

		h += TEXT_SPACING + int.max(osh, nsh);

		minimum_height = (int)h;
		natural_height = (int)h;
	}

	protected override Gtk.SizeRequestMode get_request_mode()
	{
		return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
	}

	protected override bool draw(Cairo.Context cr)
	{
		var window = get_window();

		Gtk.Allocation alloc;
		get_allocation(out alloc);

		var sizing = get_sizing(alloc.width);

		var old_surface = cache.get_old_surface(window);
		var new_surface = cache.get_new_surface(window);

		var ctx = get_style_context();

		ctx.render_background(cr, alloc.x, alloc.y, alloc.width, alloc.height);

		double max_height = double.max(sizing.old_size.image_height, sizing.new_size.image_height);
		double spread_factor = 0.5;

		if (old_surface != null && new_surface != null)
		{
			spread_factor = 2.0 / 3.0;
		}

		if (old_surface != null)
		{
			var x = (sizing.old_size.width - sizing.old_size.image_width) * spread_factor;
			var y = (max_height - sizing.old_size.image_height) / 2;

			cr.set_source_surface(old_surface, x, y);
			cr.paint();

			Pango.Rectangle rect;

			old_size_layout.get_pixel_extents(null, out rect);

			ctx.render_layout(cr,
			                  x + rect.x + (sizing.old_size.image_width - rect.width) / 2,
			                  rect.y + max_height + TEXT_SPACING,
			                  old_size_layout);
		}

		if (new_surface != null)
		{
			var x = (sizing.new_size.width - sizing.new_size.image_width) * (1.0 - spread_factor);
			var y = (max_height - sizing.new_size.image_height) / 2;

			if (cache.old_pixbuf != null)
			{
				x += sizing.old_size.width + spacing;
			}

			cr.set_source_surface(new_surface, x, y);
			cr.paint();

			Pango.Rectangle rect;

			new_size_layout.get_pixel_extents(null, out rect);

			ctx.render_layout(cr,
			                  x + rect.x + (sizing.new_size.image_width - rect.width) / 2,
			                  rect.y + max_height + TEXT_SPACING,
			                  new_size_layout);
		}

		return true;
	}

	protected override void realize()
	{
		base.realize();
		queue_resize();
	}
}
