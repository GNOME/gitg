/*
 * This file is part of gitg
 *
 * Copyright (C) 2025 - Alberto Fanjul
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

using Gtk;
using Gdk;

namespace Gitg
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-push-result-dialog.ui")]
class PushResultDialog : Dialog
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private unowned Button d_button_close;

	[GtkChild]
	private unowned TextView d_text_view_message;

	private TextBuffer buf;
	private TextView tv;
	private GLib.Regex url_reg;

	private uint timer_id = 0;

	public PushResultDialog(Gtk.Window? parent)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
		d_button_close.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
		url_reg = new Regex ("https?://[^\\s'\"<>]+");
		tv = d_text_view_message;
		buf = tv.get_buffer ();
		tv.add_events (Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.POINTER_MOTION_MASK);

		buf.changed.connect (() => {
			if (timer_id != 0) {
				GLib.Source.remove (timer_id);
				timer_id = 0;
			}
			timer_id = Timeout.add (300, () => {
				highlight_links ();
				timer_id = 0;
				return false;
			});
		});

		tv.motion_notify_event.connect (on_hover_link);
		tv.button_press_event.connect (on_link_press);
	}

	private void highlight_links () {

		List<TextTag> to_remove = new List<TextTag> ();

		var tt = buf.get_tag_table ();
		tt.foreach ((t) => {
			string? name = t.name;
			if (name != null && name.has_prefix ("link-")) {
				to_remove.append (t);
			}
		});

		TextIter whole_start, whole_end;
		buf.get_start_iter (out whole_start);
		buf.get_end_iter (out whole_end);
		foreach (var t in to_remove) {
			buf.remove_tag (t, whole_start, whole_end);
			tt.remove (t);
		}

		TextIter start;
		buf.get_start_iter (out start);
		TextIter end;
		buf.get_end_iter (out end);
		string text = buf.get_text (start, end, true);

		MatchInfo? info = null;
		url_reg.match (text, 0, out info);

		int match_index = 0;
		while(info.matches()) {
			string matched = info.fetch (0); // full match
			int byte_start, byte_end;
			info.fetch_pos (0, out byte_start, out byte_end);

			int st_off = byte_start;
			int en_off = byte_end;

			TextIter it_start;
			buf.get_iter_at_offset (out it_start, st_off);
			TextIter it_end;
			buf.get_iter_at_offset (out it_end, en_off);

			string tag_name = "link-" + match_index.to_string ();
			TextTag tag = buf.create_tag (tag_name,
			                              "foreground", "blue",
			                              "underline", Pango.Underline.SINGLE,
			                              "editable", true);

			tag.set_data ("href", matched);

			buf.apply_tag (tag, it_start, it_end);

			match_index++;
			info.next();
		}
	}

	private bool get_iter_at_event (int ex, int ey, out TextIter iter) {
		int bx = 0;
		int by = 0;
		tv.window_to_buffer_coords (TextWindowType.WIDGET, ex, ey, out bx, out by);

		tv.get_iter_at_location (out iter, bx, by);
		return true;
	}

	private bool on_hover_link (EventMotion ev) {
		TextIter iter;
		if (!get_iter_at_event ((int) ev.x, (int) ev.y, out iter))
			return false;

		var tags = iter.get_tags ();
		bool over_link = false;
		foreach (var t in tags) {
			var href = t.get_data<string> ("href");
			if (href != null) {
				over_link = true;
				break;
			}
		}

		var gdk_window = tv.get_window (TextWindowType.TEXT);
		if (gdk_window != null) {
			if (over_link) {
				var cursor = new Gdk.Cursor (Gdk.CursorType.HAND2);
				gdk_window.set_cursor (cursor);
			} else {
				gdk_window.set_cursor (null);
			}
		}

		return false;
	}

	private bool on_link_press (EventButton ev) {
		if (ev.type != Gdk.EventType.BUTTON_PRESS || ev.button != Gdk.BUTTON_PRIMARY) {
			return false;
		}
		TextIter iter;
		if (!get_iter_at_event ((int) ev.x, (int) ev.y, out iter))
			return false;

		var tags = iter.get_tags ();
		foreach (var t in tags) {

			var href = t.get_data<string> ("href");
			if (href != null) {
				TextTag visited = null;
				bool is_visited = t.name.has_suffix("-visited");
				if (!is_visited) {
					visited = buf.create_tag (t.name + "-visited",
					"foreground", "magenta",
					"underline", Pango.Underline.SINGLE);
					visited.set_data ("href", href);
				}
				try {
					AppInfo.launch_default_for_uri (href, null);
					if (!is_visited) {
						TextIter range_start = iter; // copy
						TextIter range_end	 = iter; // copy
						bool has_backward = range_start.backward_to_tag_toggle (t);
						bool has_forward  = range_end.forward_to_tag_toggle (t);
						buf.remove_tag (t, range_start, range_end);
						buf.apply_tag (visited, range_start, range_end);
					}
				} catch (Error e) {
					stderr.printf ("Failed to open %s: %s\n", href, e.message);
				}
				return true;
			}
		}
		return false;
	}

	public void append_message(string message)
	{
		d_text_view_message.buffer.text += message;
	}

	public void clear_messages()
	{
		d_text_view_message.buffer.text = "";
	}
}
}

// ex: ts=4 noet
