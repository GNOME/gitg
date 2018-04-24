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

class Gitg.DiffImageSlider : DiffImageComposite
{
	private double d_position;

	public double position
	{
		get { return d_position; }

		set
		{
			var newpos = double.max(0, double.min(value, 1));

			if (newpos != d_position)
			{
				d_position = newpos;
				queue_draw();
			}
		}
	}

	construct
	{
		position = 0.5;
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

		int pos = (int)(image_width * position);

		if (old_surface != null)
		{
			cr.save();
			{
				cr.rectangle(x, y, pos, image_height);
				cr.clip();
				cr.set_source_surface(old_surface, x, y);
				cr.paint();
			}
			cr.restore();
		}

		if (new_surface != null)
		{
			cr.save();
			{
				cr.rectangle(x + pos, y, image_width - pos, image_height);
				cr.clip();
				cr.set_source_surface(new_surface, x, y);
				cr.paint();
			}
			cr.restore();
		}

		return true;
	}

	protected override void realize()
	{
		base.realize();
		queue_resize();
	}
}
