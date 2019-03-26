/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Ignacio Casal Quinteiro
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

namespace Gitg
{
	public class ProgressBin : Gtk.Bin
	{
		private double d_fraction;

		public double fraction
		{
			get { return d_fraction; }
			set
			{
				d_fraction = value;
				queue_draw();
			}
		}

		construct
		{
			set_has_window(true);
			set_redraw_on_allocate(false);
		}

		public override void realize()
		{
			set_realized(true);

			Gtk.Allocation allocation;
			get_allocation(out allocation);

			Gdk.WindowAttr attributes = {};
			attributes.x = allocation.x;
			attributes.y = allocation.y;
			attributes.width = allocation.width;
			attributes.height = allocation.height;
			attributes.window_type = Gdk.WindowType.CHILD;
			attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
			attributes.event_mask = get_events() |
			                        Gdk.EventMask.EXPOSURE_MASK |
			                        Gdk.EventMask.BUTTON_PRESS_MASK |
			                        Gdk.EventMask.BUTTON_RELEASE_MASK;

			var attributes_mask = Gdk.WindowAttributesType.X | Gdk.WindowAttributesType.Y;
			var window = new Gdk.Window(get_parent_window(),
			                            attributes, attributes_mask);


			set_window(window);
			window.set_user_data(this);
		}

		public override void size_allocate(Gtk.Allocation allocation)
		{
			set_allocation(allocation);

			var window = get_window();
			if (window != null)
			{
				window.move_resize(allocation.x, allocation.y, allocation.width, allocation.height);
			}

			var child = get_child();
			if (child != null && child.get_visible())
			{
				Gtk.Allocation child_allocation = {};
				int border_width = (int)get_border_width();
				child_allocation.x = border_width;
				child_allocation.y = border_width;
				child_allocation.width = allocation.width - 2 * border_width;
				child_allocation.height = allocation.height - 2 * border_width;

				child.size_allocate(child_allocation);
			}
		}

		public override bool draw(Cairo.Context cr)
		{
			Gtk.Allocation allocation;
			get_allocation(out allocation);

			var context = get_style_context();
			context.render_background(cr, 0, 0, allocation.width, allocation.height);

			context.save();
			context.add_class("progress-bin");

			context.render_background(cr, 0, 0, allocation.width * d_fraction, allocation.height);
			context.restore();

			base.draw(cr);
			return true;
		}
	}
}

// ex:ts=4 noet
