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
	public class ProgressBin : Adw.Bin
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

		static construct
		{
			set_css_name("progress-bin");
		}

		public override void snapshot(Gtk.Snapshot snapshot)
		{
			var w = get_width();
			var h = get_height();


			var context = get_style_context();
			snapshot.render_background(context, 0, 0, w, h);

			context.save();
			context.add_class("progress-bin");

			snapshot.render_background(context, 0, 0, w * d_fraction, h);
			context.restore();
			
			base.snapshot(snapshot);

		}
	}
}

// ex:ts=4 noet
