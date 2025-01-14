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

class Gitg.DiffImageComposite : Gtk.DrawingArea
{
	public Gitg.DiffImageSurfaceCache cache { get; set; }

	private void get_natural_size(out int image_width, out int image_height)
	{
		var pixbuf_old = cache.old_pixbuf;
		var pixbuf_new = cache.new_pixbuf;

		if (pixbuf_old == null || pixbuf_new == null)
		{
			image_width = 0;
			image_height = 0;

			return;
		}

		var window = get_window();

		int pixbuf_old_height = pixbuf_old.get_height ();
		int pixbuf_new_height = pixbuf_new.get_height ();

		int pixbuf_old_width = pixbuf_old.get_width ();
		int pixbuf_new_width = pixbuf_new.get_width ();

		double xscale_old = 1, yscale_old = 1;
		double xscale_new = 1, yscale_new = 1;

		if (window != null)
		{
			cache.get_old_surface(window).get_device_scale(out xscale_old, out yscale_old);
			cache.get_new_surface(window).get_device_scale(out xscale_new, out yscale_new);
		}

		image_width = (int) double.max (pixbuf_old_width / xscale_old, pixbuf_new_width / xscale_new);
		image_height = (int) double.max (pixbuf_old_height / xscale_old, pixbuf_new_height / xscale_new);
	}

	protected void get_sizing(int width, out int image_width, out int image_height)
	{
		get_natural_size(out image_width, out image_height);

		// Scale down to fit in width
		if (image_width > width)
		{
			image_height *= width / image_width;
			image_width = width;
		}
	}

	protected override void get_preferred_width(out int minimum_width, out int natural_width)
	{
		int natural_height;

		get_natural_size(out natural_width, out natural_height);
		minimum_width = 0;
	}

	protected override void get_preferred_height_for_width(int width, out int minimum_height, out int natural_height)
	{
		int image_width, image_height;

		get_sizing(width, out image_width, out image_height);

		minimum_height = image_height;
		natural_height = image_height;
	}

	protected override Gtk.SizeRequestMode get_request_mode()
	{
		return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
	}

	protected override bool draw(Cairo.Context cr)
	{
		Gtk.Allocation alloc;
		get_allocation(out alloc);

		var ctx = get_style_context();

		ctx.render_background(cr, alloc.x, alloc.y, alloc.width, alloc.height);
		return true;
	}

	protected override void realize()
	{
		base.realize();
		queue_resize();
	}
}
