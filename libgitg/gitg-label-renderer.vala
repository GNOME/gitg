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
	public class LabelRenderer
	{
		private const int margin = 2;
		private const int padding = 6;

		private static string label_text(Ref r)
		{
			var escaped = Markup.escape_text(r.parsed_name.shortname);
			return "<span size='smaller'>%s</span>".printf(escaped);
		}

		private static int get_label_width(Pango.Layout layout,
		                                   Ref          r)
		{
			var smaller = label_text(r);

			int w;

			layout.set_markup(smaller, -1);
			layout.get_pixel_size(out w, null);

			return w + padding * 2;
		}

		public static int width(Gtk.Widget             widget,
		                        Pango.FontDescription *font,
		                        SList<Ref>             labels)
		{
			if (labels == null)
			{
				return 0;
			}

			int ret = 0;

			var ctx = widget.get_pango_context();
			var layout = new Pango.Layout(ctx);

			layout.set_font_description(font);

			foreach (Ref r in labels)
			{
				ret += get_label_width(layout, r) + margin;
			}

			return ret + margin;
		}

		private static string class_from_ref(RefType type)
		{
			string style_class;

			switch (type)
			{
				case RefType.BRANCH:
					style_class = "branch";
				break;
				case RefType.REMOTE:
					style_class = "remote";
				break;
				case RefType.TAG:
					style_class = "tag";
				break;
				case RefType.STASH:
					style_class = "stash";
				break;
				default:
					style_class = null;
				break;
			}

			return style_class;
		}

		private static int render_label(Gtk.Widget    widget,
		                                Cairo.Context cr,
		                                Pango.Layout  layout,
		                                Ref           r,
		                                double        x,
		                                double        y,
		                                int           height,
		                                bool          use_state)
		{
			var context = widget.get_style_context();
			var smaller = label_text(r);

			layout.set_markup(smaller, -1);

			int w;
			int h;

			layout.get_pixel_size(out w, out h);

			context.save();

			var style_class = class_from_ref(r.parsed_name.rtype);

			if (style_class != null)
			{
				context.add_class(style_class);
			}

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			if (rtl)
			{
				x -= w + padding * 2;
			}

			context.render_background(cr,
			                          x,
			                          y + margin,
			                          w + padding * 2,
			                          height - margin * 2);

			context.render_frame(cr,
			                     x,
			                     y + margin,
			                     w + padding * 2,
			                     height - margin * 2);

			context.render_layout(cr,
			                      x + padding,
			                      y + (height - h) / 2.0 - 1,
			                      layout);

			context.restore();
			return w;
		}

		public static void draw(Gtk.Widget            widget,
		                        Pango.FontDescription font,
		                        Cairo.Context         context,
		                        SList<Ref>            labels,
		                        Gdk.Rectangle         area)
		{
			double pos;

			var rtl = (widget.get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

			if (!rtl)
			{
				pos = area.x + margin + 0.5;
			}
			else
			{
				pos = area.x + area.width - margin - 0.5;
			}

			context.save();
			context.set_line_width(1.0);

			var ctx = widget.get_pango_context();
			var layout = new Pango.Layout(ctx);

			layout.set_font_description(font);

			foreach (Ref r in labels)
			{
				var w = render_label(widget,
				                     context,
				                     layout,
				                     r,
				                     (int)pos,
				                     area.y,
				                     area.height,
				                     true);

				var o = w + padding * 2 + margin;
				pos += rtl ? -o : o;
			}

			context.restore();
		}

		public static Ref? get_ref_at_pos(Gtk.Widget            widget,
		                                  Pango.FontDescription font,
		                                  SList<Ref>            labels,
		                                  int                   x,
		                                  out int               hot_x)
		{
			hot_x = 0;

			if (labels == null)
			{
				return null;
			}

			var ctx = widget.get_pango_context();
			var layout = new Pango.Layout(ctx);

			layout.set_font_description(font);

			int start = margin;
			Ref? ret = null;

			foreach (Ref r in labels)
			{
				int width = get_label_width(layout, r);

				if (x >= start && x <= start + width)
				{
					ret = r;
					hot_x = x - start;

					break;
				}

				start += width + margin;
			}

			return ret;
		}

		private static uchar convert_color_channel(uchar color,
		                                           uchar alpha)
		{
			return (uchar)((alpha != 0) ? (color / (alpha / 255.0)) : 0);
		}

		private static void convert_bgra_to_rgba(uchar[] src,
		                                         uchar[] dst,
		                                         int     width,
		                                         int     height)
		{
			int i = 0;

			for (int y = 0; y < height; ++y)
			{
				for (int x = 0; x < width; ++x)
				{
					dst[i] = convert_color_channel(src[i + 2], src[i + 3]);
					dst[i + 1] = convert_color_channel(src[i + 1], src[i + 3]);
					dst[i + 2] = convert_color_channel(src[i], src[i + 3]);
					dst[i + 3] = src[i + 3];

					i += 4;
				}
			}
		}

		public static Gdk.Pixbuf render_ref(Gtk.Widget            widget,
		                                    Pango.FontDescription font,
		                                    Ref                   r,
		                                    int                   height,
		                                    int                   minwidth)
		{
			var ctx = widget.get_pango_context();
			var layout = new Pango.Layout(ctx);

			layout.set_font_description(font);

			int width = int.max(get_label_width(layout, r), minwidth);

			var surface = new Cairo.ImageSurface(Cairo.Format.ARGB32,
			                                     width + 2,
			                                     height + 2);

			var context = new Cairo.Context(surface);
			context.set_line_width(1);

			render_label(widget, context, layout, r, 1, 1, height, false);
			var data = surface.get_data();

			Gdk.Pixbuf ret = new Gdk.Pixbuf(Gdk.Colorspace.RGB,
			                                true,
			                                8,
			                                width + 2,
			                                height + 2);

			var pixdata = ret.get_pixels();
			convert_bgra_to_rgba(data, pixdata, width + 2, height + 2);

			return ret;
		}
	}
}

// ex:ts=4 noet
