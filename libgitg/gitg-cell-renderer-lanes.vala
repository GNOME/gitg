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
	public class CellRendererLanes : Gtk.CellRendererText
	{
		public Commit? commit { get; set; }
		public Commit? next_commit { get; set; }
		public uint lane_width { get; set; default = 16; }
		public uint dot_width { get; set; default = 10; }
		public unowned SList<Ref> labels { get; set; }

		private int d_last_height;

		private delegate double DirectionFunc(double i);

		private uint num_visible_lanes
		{
			get
			{
				int ret = 0;
				int trailing_hidden = 0;

				foreach (var lane in commit.get_lanes())
				{
					++ret;

					if ((lane.tag & LaneTag.HIDDEN) != 0)
					{
						trailing_hidden++;
					}
					else
					{
						trailing_hidden = 0;
					}
				}

				return ret - trailing_hidden;
			}
		}

		private uint total_width(Gtk.Widget widget)
		{
			return num_visible_lanes * lane_width +
			       LabelRenderer.width(widget, font_desc, labels);
		}

		public override void get_preferred_width(Gtk.Widget widget,
		                                         out int    minimum_width,
		                                         out int    natural_width)
		{
			base.get_preferred_width(widget, out minimum_width, out natural_width);

			var w = (int)total_width(widget);

			if (w > minimum_width)
			{
				minimum_width = w;
			}
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
		                             DirectionFunc f,
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
				if ((lane.tag & LaneTag.HIDDEN) != 0)
				{
					++to;
					continue;
				}

				var color = lane.color;
				context.set_source_rgb(color.r, color.g, color.b);

				foreach (var from in lane.from)
				{
					double x1 = area.x + f(from * cw + cw / 2.0);
					double x2 = area.x + f(to * cw + cw / 2.0);
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
		                            Gdk.Rectangle area,
		                            DirectionFunc f)
		{
			draw_paths_real(context, area, commit, f, -1);
		}

		private void draw_bottom_paths(Cairo.Context context,
		                               Gdk.Rectangle area,
		                               DirectionFunc f)
		{
			draw_paths_real(context, area, next_commit, f, 1);
		}

		private void draw_paths(Cairo.Context context,
		                        Gdk.Rectangle area,
		                        DirectionFunc f)
		{
			context.set_line_width(2.0);
			context.set_line_cap(Cairo.LineCap.ROUND);

			context.save();

			draw_top_paths(context, area, f);
			draw_bottom_paths(context, area, f);
			draw_arrows(context, area);

			context.restore();
		}

		private void draw_indicator(Cairo.Context context,
		                            Gdk.Rectangle area,
		                            DirectionFunc f)
		{
			double offset;
			double radius;

			offset = commit.mylane * lane_width + (lane_width - dot_width) / 2.0;
			radius = dot_width / 2.0;

			context.set_line_width(0.0);

			context.arc(area.x + f(offset + radius),
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
		                         Gtk.Widget    widget,
		                         Gdk.Rectangle area)
		{
			int offset;

			offset = (int)(num_visible_lanes * lane_width);

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			if (rtl)
			{
				offset = -offset;
			}

			context.save();
			context.translate(offset, 0);
			LabelRenderer.draw(widget, font_desc, context, labels, area);
			context.restore();
		}

		private void draw_lane(Cairo.Context context,
		                       Gtk.Widget    widget,
		                       Gdk.Rectangle area)
		{
			DirectionFunc f;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			context.save();

			if (rtl)
			{
				context.translate(area.width, 0);
				f = (a) => -a;
			}
			else
			{
				f = (a) => a;
			}

			draw_paths(context, area, f);
			draw_indicator(context, area, f);

			context.restore();
		}

		public override void render(Cairo.Context         context,
		                            Gtk.Widget            widget,
		                            Gdk.Rectangle         area,
		                            Gdk.Rectangle         cell_area,
		                            Gtk.CellRendererState flags)
		{
			var ncell_area = cell_area;
			var narea = area;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			d_last_height = area.height;

			if (commit != null)
			{
				context.save();

				Gdk.cairo_rectangle(context, area);
				context.clip();

				draw_lane(context, widget, area);
				draw_labels(context, widget, area);

				var tw = total_width(widget);

				if (!rtl)
				{
					narea.x += (int)tw;
					ncell_area.x += (int)tw;
				}
				else
				{
					narea.width -= (int)tw;
					ncell_area.width -= (int)tw;
				}

				context.restore();
			}

			if (rtl == (Pango.find_base_dir(text, -1) != Pango.Direction.RTL))
			{
				xalign = 1.0f;
			}

			base.render(context, widget, narea, ncell_area, flags);
		}

		public Ref? get_ref_at_pos(Gtk.Widget widget,
		                           int        x,
		                           int        cell_w,
		                           out int    hot_x)
		{
			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;
			var offset = (int)(num_visible_lanes * lane_width);

			if (rtl)
			{
				x = cell_w - x;
			}

			return LabelRenderer.get_ref_at_pos(widget,
			                                    font_desc,
			                                    labels,
			                                    x - offset,
			                                    out hot_x);
		}
	}
}

// ex:ts=4 noet
