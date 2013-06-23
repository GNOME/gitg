/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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
	class CellRendererLanes : Gtk.CellRendererText
	{
		public Commit? commit { get; set; }
		public Commit? next_commit { get; set; }
		public uint lane_width { get; set; default = 16; }
		public uint dot_width { get; set; default = 10; }
		public unowned SList<Ref> labels { get; set; }

		private int d_last_height;

		private uint num_lanes
		{
			get { return commit.get_lanes().length(); }
		}

		private uint total_width(Gtk.Widget widget)
		{
			return num_lanes * lane_width +
			       LabelRenderer.width(widget, font_desc, labels);
		}

		public override void get_size(Gtk.Widget     widget,
		                              Gdk.Rectangle? area,
		                              out int        xoffset,
		                              out int        yoffset,
		                              out int        width,
		                              out int        height)
		{
			xoffset = 0;
			yoffset = 0;

			width = (int)total_width(widget);
			height = area != null ? area.height : 1;
		}

		private void draw_arrow(Cairo.Context context,
		                        Gdk.Rectangle area,
		                        uint          laneidx,
		                        bool          top)
		{
			double cw = lane_width;
			double xpos = area.x + laneidx * cw + cw / 2.0;
			double df = (top ? -1 : 1) * 0.25 * area.height;
			double ypos = area.y + area.height / 2.0 + df;
			double q = cw / 4.0;

			context.move_to(xpos - q, ypos + (top ? q : -q));
			context.line_to(xpos, ypos);
			context.line_to(xpos + q, ypos + (top ? q : -q));
			context.stroke();

			context.move_to(xpos, ypos);
			context.line_to(xpos, ypos - df);
			context.stroke();
		}

		private void draw_arrows(Cairo.Context context,
		                         Gdk.Rectangle area)
		{
			uint to = 0;

			foreach (var lane in commit.get_lanes())
			{
				var color = lane.color;
				context.set_source_rgb(color.r, color.g, color.b);

				if (lane.tag == LaneTag.START)
				{
					draw_arrow(context, area, to, true);
				}
				else if (lane.tag == LaneTag.END)
				{
					draw_arrow(context, area, to, false);
				}

				++to;
			}
		}

		private void draw_paths_real(Cairo.Context context,
		                             Gdk.Rectangle area,
		                             Commit?       commit,
		                             double        yoffset)
		{
			if (commit == null)
			{
				return;
			}

			int to = 0;
			double cw = lane_width;
			double ch = area.height / 2.0;

			foreach (var lane in commit.get_lanes())
			{
				var color = lane.color;
				context.set_source_rgb(color.r, color.g, color.b);

				foreach (var from in lane.from)
				{
					double x1 = area.x + from * cw + cw / 2.0;
					double x2 = area.x + to * cw + cw / 2.0;
					double y1 = area.y + yoffset * ch;
					double y2 = area.y + (yoffset + 1) * ch;
					double y3 = area.y + (yoffset + 2) * ch;

					context.move_to(x1, y1);
					context.curve_to(x1, y2, x2, y2, x2, y3);
					context.stroke();
				}

				++to;
			}
		}

		private void draw_top_paths(Cairo.Context context,
		                            Gdk.Rectangle area)
		{
			draw_paths_real(context, area, commit, -1);
		}

		private void draw_bottom_paths(Cairo.Context context,
		                               Gdk.Rectangle area)
		{
			draw_paths_real(context, area, next_commit, 1);
		}

		private void draw_paths(Cairo.Context context,
		                        Gdk.Rectangle area)
		{
			context.set_line_width(2.0);
			context.set_line_cap(Cairo.LineCap.ROUND);

			draw_top_paths(context, area);
			draw_bottom_paths(context, area);
			draw_arrows(context, area);
		}

		private void draw_indicator(Cairo.Context context,
		                            Gdk.Rectangle area)
		{
			double offset;
			double radius;

			offset = commit.mylane * lane_width + (lane_width - dot_width) / 2.0;
			radius = dot_width / 2.0;

			context.set_line_width(2.0);

			context.arc(area.x + offset + radius,
			            area.y + area.height / 2.0,
			            radius,
			            0,
			            2 * Math.PI);

			context.set_source_rgb(0, 0, 0);
			context.stroke_preserve();

			if (commit.lane != null)
			{
				var color = commit.lane.color;
				context.set_source_rgb(color.r, color.g, color.b);
			}

			context.fill();
		}

		private void draw_labels(Cairo.Context context,
		                         Gdk.Rectangle area,
		                         Gtk.Widget    widget)
		{
			uint offset;

			offset = num_lanes * lane_width;

			context.translate(offset, 0);
			LabelRenderer.draw(widget, font_desc, context, labels, area);
		}

		public override void render(Cairo.Context         context,
		                            Gtk.Widget            widget,
		                            Gdk.Rectangle         area,
		                            Gdk.Rectangle         cell_area,
		                            Gtk.CellRendererState flags)
		{
			var ncell_area = cell_area;
			var narea = area;

			d_last_height = area.height;

			if (commit != null)
			{
				context.save();

				Gdk.cairo_rectangle(context, area);
				context.clip();

				draw_paths(context, area);
				draw_indicator(context, area);
				draw_labels(context, area, widget);

				var tw = total_width(widget);

				narea.x += (int)tw;
				ncell_area.x += (int)tw;

				context.restore();
			}

			base.render(context, widget, narea, ncell_area, flags);
		}
	}
}

// ex:ts=4 noet
