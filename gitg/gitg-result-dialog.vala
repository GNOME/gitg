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

public class AnsiRenderer {
	private TextBuffer buf;
	private HashTable<string, TextTag> tags;

	public AnsiRenderer (TextBuffer buf) {
		this.buf = buf;
		tags = new HashTable<string, TextTag> (str_hash, str_equal);
	}

	private TextTag get_tag (bool bold, bool underline, int fg) {
		string key = "%d:%d:%d".printf (bold ? 1 : 0, underline ? 1 : 0, fg);
		TextTag? t = tags.lookup (key);
		if (t != null)
			return t;

		t = new TextTag (key);
		if (bold)
			t.weight = Pango.Weight.BOLD;
		if (underline)
			t.underline = Pango.Underline.SINGLE;
		if (fg != -1) {
			switch (fg) {
				case 30:
					t.foreground = "black";
					break;
				case 31:
					t.foreground = "red";
					break;
				case 32:
					t.foreground = "green";
					break;
				case 33:
					t.foreground = "yellow";
					break;
				case 34:
					t.foreground = "blue";
					break;
				case 35:
					t.foreground = "magenta";
					break;
				case 36:
					t.foreground = "cyan";
					break;
				case 37:
					t.foreground = "white";
					break;
				default:
					break;
			}
			t.foreground_set = true;
		}
		buf.get_tag_table().add (t);
		tags.insert(key, t);
		return t;
	}

	public void render_ansi (string s) {
		buf.set_text ("");

		int len = s.length;
		int p = 0;

		bool bold = false;
		bool underline = false;
		int fg = -1;

		while (p < len) {
			int escpos = s.index_of ("\u001b", p);
			if (escpos < 0) {
				// no more escapes — insert remainder
				string seg = s.substring (p, len - p);
				insert_with_tag (seg, bold, underline, fg);
				break;
			}

			// insert text before escape
			if (escpos > p) {
				string seg = s.substring (p, escpos - p);
				insert_with_tag (seg, bold, underline, fg);
			}

			// parse sequence if it's CSI SGR: ESC [ ... m
			if (escpos + 1 < len && s[escpos + 1] == '[') {
				int mpos = s.index_of ("m", escpos + 2);
				if (mpos < 0) {
					// malformed — treat remaining as plain text
					string seg = s.substring (escpos, len - escpos);
					insert_with_tag (seg, bold, underline, fg);
					break;
				}
				string code = s.substring (escpos + 2, mpos - (escpos + 2));
				if (code.length == 0) code = "0";
				string[] parts = code.split (";");
				foreach (var part in parts) {
					int v = 0;
					try {
						v = int.parse (part);
					} catch (Error e) {
						v = -1;
					}
					if (v == 0) {
						// reset
						bold = false; underline = false; fg = -1;
					} else if (v == 1) {
						bold = true;
					} else if (v == 4) {
						underline = true;
					} else if (v >= 30 && v <= 37) {
						fg = v;
					} else if (v == 39) {
						fg = -1; // default fg
					} else if (v == 22) {
						bold = false;
					} else if (v == 24) {
						underline = false;
					} else {
						// ignore other codes for brevity
					}
				}
				p = mpos + 1;
				continue;
			} else {
				print("unsupported ");
				// not a supported escape sequence, insert ESC as literal
				insert_with_tag ("\u001b", bold, underline, fg);
				p = escpos + 1;
			}
		}
	}

	private void insert_with_tag (string text, bool bold, bool underline, int fg) {
		if (text.length == 0)
			return;

		TextIter start;
		buf.get_end_iter (out start);
		if (bold || underline || fg != -1) {
			TextTag t = get_tag (bold, underline, fg);
			buf.insert_with_tags(ref start, text, -1, t);
		} else {
			buf.insert (ref start, text, -1);
		}
	}
}

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-result-dialog.ui")]
class ResultDialog : Dialog
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private unowned Button d_button_close;

	[GtkChild]
	private unowned TextView d_text_view_message;

	[GtkChild]
	private unowned Label d_label_result;

	private TextBuffer buf;
	private TextView tv;
	private GLib.Regex url_reg;

	private uint timer_id = 0;
	private AnsiRenderer ansiRenderer;

	public ResultDialog(Gtk.Window? parent, string title, string? label_text = null)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
		set_title(title);
		if (label_text != null)
			d_label_result.set_text(label_text);
		d_button_close.get_style_context().add_class(STYLE_CLASS_SUGGESTED_ACTION);
		url_reg = new Regex ("https?://[^\\s'\"<>]+");
		tv = d_text_view_message;
		var font_desc = Pango.FontDescription.from_string ("Monospace 11");
		tv.override_font (font_desc);
		buf = tv.get_buffer ();
		ansiRenderer = new AnsiRenderer(buf);
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

	public static int byte_to_char_offset (string str, int byte_offset) {
		if (byte_offset <= 0) return 0;
		if (byte_offset >= str.length) return str.char_count ();

		// Count characters from start to byte_offset
		int char_count = 0;
		int current_byte = 0;

		unichar c;
		for (int i = 0; str.get_next_char (ref i, out c);) {
			if (i > byte_offset) break;
			char_count++;
			current_byte = i;
		}

		return char_count;
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
		string text = buf.get_text (start, end, false);

		MatchInfo? info = null;
		url_reg.match (text, 0, out info);

		int match_index = 0;
		while(info.matches()) {
			string matched = info.fetch (0); // full match
			int byte_start, byte_end;
			info.fetch_pos (0, out byte_start, out byte_end);

			int st_off = byte_to_char_offset(text, byte_start);
			int en_off = byte_to_char_offset(text, byte_end);

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

	public void append_message(string? message)
	{
		if (message != null)
			//d_text_view_message.buffer.text += message;
		    ansiRenderer.render_ansi(message);
	}

	public void clear_messages()
	{
		//d_text_view_message.buffer.text = "";
		ansiRenderer.render_ansi("");
	}
}
}

// ex: ts=4 noet
