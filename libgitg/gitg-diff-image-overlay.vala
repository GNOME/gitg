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

class Gitg.DiffImageOverlay : DiffImageComposite
{
	private double d_alpha;

	public double alpha
	{
		get { return d_alpha; }

		set
		{
			var newalpha = double.max(0, double.min(value, 1));

			if (newalpha != d_alpha)
			{
				d_alpha = newalpha;
				queue_draw();
			}
		}
	}

	construct
	{
		alpha = 0.5;
	}

	protected override bool draw(Cairo.Context cr)
	{
		base.draw(cr);

		var window = get_window();

		Gtk.Allocation alloc;
		get_allocation(out alloc);

		int image_width, image_height;
		get_sizing(alloc.width, out image_width, out image_height);

		var old_surface = cache.get_old_surface(window);
		var new_surface = cache.get_new_surface(window);

		int x = (alloc.width - image_width) / 2;
		int y = 0;

		if (old_surface != null && d_alpha != 1)
		{
			cr.set_source_surface(old_surface, x, y);
			cr.paint_with_alpha(1 - d_alpha);
		}

		if (new_surface != null && d_alpha != 0)
		{
			cr.set_source_surface(new_surface, x, y);
			cr.paint_with_alpha(d_alpha);
		}

		return true;
	}

	protected override void realize()
	{
		base.realize();
		queue_resize();
	}
}
