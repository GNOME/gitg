/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

enum Gitg.DiffSelectionMode {
	NONE,
	SELECTING,
	DESELECTING
}

class Gitg.DiffViewFileSelectable : Object
{
	private string d_selection_category = "selection";
	private Gtk.TextTag d_selection_tag;
	private DiffSelectionMode d_selection_mode;
	private Gtk.TextMark d_start_selection_mark;
	private Gtk.TextMark d_end_selection_mark;
	private Gee.HashMap<int, bool> d_originally_selected;
	private Gdk.Cursor d_subtract_cursor_ptr;
	private Gdk.Cursor d_subtract_cursor_hand;
	private Gdk.Cursor d_cursor_ptr;
	private Gdk.Cursor d_cursor_hand;

	public Gtk.SourceView source_view
	{
		get; construct set;
	}

	public bool has_selection
	{
		get; private set;
	}

	public DiffViewFileSelectable(Gtk.SourceView source_view)
	{
		Object(source_view: source_view);
	}

	construct
	{
		source_view.button_press_event.connect(button_press_event_on_view);
		source_view.motion_notify_event.connect(motion_notify_event_on_view);
		source_view.button_release_event.connect(button_release_event_on_view);

		source_view.realize.connect(() => {
			update_cursor(cursor_ptr);
		});

		source_view.notify["state-flags"].connect(() => {
			update_cursor(cursor_ptr);
		});

		d_selection_tag = source_view.buffer.create_tag("selection");

		source_view.style_updated.connect(update_theme);
		update_theme();

		d_originally_selected = new Gee.HashMap<int, bool>();
	}

	private Gdk.Cursor composite_subtract_cursor(Gdk.CursorType cursor)
	{
		int width, height, hot_x, hot_y;

		var surface = PlatformSupport.create_cursor_surface(source_view.get_display(),
		                                                    cursor,
		                                                    out hot_x,
		                                                    out hot_y,
		                                                    out width,
		                                                    out height);

		if (surface == null)
		{
			return new Gdk.Cursor.for_display(source_view.get_display(), cursor);
		}

		var ctx = new Cairo.Context(surface);

		ctx.set_line_width(1);

		const int margin = 2;
		const int length = 5;

		ctx.set_source_rgb(0, 0, 0);
		ctx.move_to(width - margin - length + 0.5, margin - (length - 1) / 2 + 0.5);
		ctx.rel_line_to(length, 0);
		ctx.stroke();

		ctx.set_source_rgb(1, 1, 1);
		ctx.move_to(width - margin - length + 0.5, margin - (length - 1) / 2 + 1.5);
		ctx.rel_line_to(length, 0);
		ctx.stroke();

		return new Gdk.Cursor.from_surface(source_view.get_display(), surface, hot_x, hot_y);
	}

	private Gdk.Cursor cursor_ptr
	{
		owned get
		{
			if (d_cursor_ptr == null)
			{
				d_cursor_ptr = new Gdk.Cursor.for_display(source_view.get_display(), Gdk.CursorType.LEFT_PTR);
			}

			return d_cursor_ptr;
		}
	}

	private Gdk.Cursor cursor_hand
	{
		owned get
		{
			if (d_cursor_hand == null)
			{
				d_cursor_hand = new Gdk.Cursor.for_display(source_view.get_display(), Gdk.CursorType.HAND1);
			}

			return d_cursor_hand;
		}
	}

	private Gdk.Cursor subtract_cursor_ptr
	{
		owned get
		{
			if (d_subtract_cursor_ptr == null)
			{
				d_subtract_cursor_ptr = composite_subtract_cursor(Gdk.CursorType.LEFT_PTR);
			}

			
			return d_subtract_cursor_ptr;
		}
	}

	private Gdk.Cursor subtract_cursor_hand
	{
		owned get
		{
			if (d_subtract_cursor_hand == null)
			{
				d_subtract_cursor_hand = composite_subtract_cursor(Gdk.CursorType.HAND1);
			}

			
			return d_subtract_cursor_hand;
		}
	}

	private void update_cursor(Gdk.Cursor cursor)
	{
		var window = source_view.get_window(Gtk.TextWindowType.TEXT);

		if (window == null)
		{
			return;
		}

		window.set_cursor(cursor);
	}

	private void update_cursor_for_state(Gdk.ModifierType state)
	{
		Gtk.TextIter iter;
		
		var is_hunk = get_iter_from_pointer_position(out iter) && get_line_is_hunk(iter);

		if ((state & Gdk.ModifierType.MOD1_MASK) != 0 || d_selection_mode == DiffSelectionMode.DESELECTING)
		{
			if (is_hunk)
			{
				update_cursor(subtract_cursor_hand);
			}
			else
			{
				update_cursor(subtract_cursor_ptr);
			}
		}
		else
		{
			update_cursor(is_hunk ? cursor_hand : cursor_ptr);
		}
	}

	private void update_theme()
	{
		var selection_attributes = new Gtk.SourceMarkAttributes();
		var context = source_view.get_style_context();

		Gdk.RGBA theme_selected_bg_color, theme_selected_fg_color;

		if (context.lookup_color("theme_selected_bg_color", out theme_selected_bg_color))
		{
			selection_attributes.background = theme_selected_bg_color;
		}
		
		if (context.lookup_color("theme_selected_fg_color", out theme_selected_fg_color))
		{
			d_selection_tag.foreground_rgba = theme_selected_fg_color;
		}

		source_view.set_mark_attributes(d_selection_category, selection_attributes, 0);
	}

	private bool get_line_selected(Gtk.TextIter iter)
	{
		Gtk.TextIter start = iter;

		start.set_line_offset(0);

		var buffer = source_view.buffer as Gtk.SourceBuffer;

		return buffer.get_source_marks_at_iter(start, d_selection_category) != null;
	}

	private bool get_line_is_diff(Gtk.TextIter iter)
	{
		Gtk.TextIter start = iter;

		start.set_line_offset(0);

		var buffer = source_view.buffer as Gtk.SourceBuffer;

		return (buffer.get_source_marks_at_iter(start, "added") != null) ||
		       (buffer.get_source_marks_at_iter(start, "removed") != null);
	}

	private bool get_line_is_hunk(Gtk.TextIter iter)
	{
		Gtk.TextIter start = iter;

		start.set_line_offset(0);

		var buffer = source_view.buffer as Gtk.SourceBuffer;

		return buffer.get_source_marks_at_iter(start, "header") != null;
	}

	private bool get_iter_from_pointer_position(out Gtk.TextIter iter)
	{
		var win = source_view.get_window(Gtk.TextWindowType.TEXT);

		int x, y, width, height;

		// To silence unassigned iter warning
		var dummy_iter = Gtk.TextIter();
		iter = dummy_iter;

		width = win.get_width();
		height = win.get_height();

		var pointer = Gdk.Display.get_default().get_device_manager().get_client_pointer();
		win.get_device_position(pointer, out x, out y, null);

		if (x < 0 || y < 0 || x > width || y > height)
		{
			return false;
		}

		int win_x, win_y;

		source_view.window_to_buffer_coords(Gtk.TextWindowType.TEXT, x, y, out win_x, out win_y);
		source_view.get_line_at_y(out iter, win_y, null);

		return true;
	}

	private void update_selection_range(Gtk.TextIter start, Gtk.TextIter end, bool select)
	{
		var buffer = source_view.buffer as Gtk.SourceBuffer;

		Gtk.TextIter real_start, real_end;

		real_start = start;
		real_end = end;

		real_start.order(real_end);
		real_start.set_line_offset(0);

		if (!real_end.ends_line())
		{
			real_end.forward_to_line_end();
		}

		var start_line = real_start.get_line();
		var end_line = real_end.get_line();

		var current = real_start;

		while (start_line <= end_line)
		{
			if (get_line_is_diff(current))
			{
				if (!d_originally_selected.has_key(start_line))
				{
					d_originally_selected[start_line] = get_line_selected(current);
				}

				if (select)
				{
					buffer.create_source_mark(null, d_selection_category, current);

					var line_end = current;

					if (!line_end.ends_line())
					{
						line_end.forward_to_line_end();
					}

					buffer.apply_tag(d_selection_tag, current, line_end);
				}
			}

			if (!current.forward_line())
			{
				break;
			}

			start_line++;
		}

		if (!select)
		{
			buffer.remove_source_marks(real_start, real_end, d_selection_category);
			buffer.remove_tag(d_selection_tag, real_start, real_end);
		}
	}

	private void clear_original_selection(Gtk.TextIter start, Gtk.TextIter end, bool include_end)
	{
		var current = start;
		current.set_line_offset(0);

		var end_line = end.get_line();
		var current_line = current.get_line();

		if (include_end)
		{
			end_line++;
		}

		while (current_line < end_line)
		{
			var originally_selected = d_originally_selected[current_line];

			update_selection_range(current, current, originally_selected);

			current.forward_line();
			current_line++;
		}
	}

	private void update_selection_hunk(Gtk.TextIter iter, bool select)
	{
		var end = iter;

		end.forward_line();

		var buffer = source_view.buffer as Gtk.SourceBuffer;
		
		if (!buffer.forward_iter_to_source_mark(ref end, "header"))
		{
			end.forward_to_end();
		}

		update_selection_range(iter, end, select);
	}

	private bool button_press_event_on_view(Gdk.EventButton event)
	{
		if (event.button != 1)
		{
			return false;
		}

		Gtk.TextIter iter;

		if (!get_iter_from_pointer_position(out iter))
		{
			return false;
		}

		var select = (event.state & Gdk.ModifierType.MOD1_MASK) == 0;

		if (get_line_is_hunk(iter))
		{
			update_selection_hunk(iter, select);
			return true;
		}

		if (select)
		{
			d_selection_mode = DiffSelectionMode.SELECTING;
		}
		else
		{
			d_selection_mode = DiffSelectionMode.DESELECTING;
		}

		var buffer = source_view.buffer;

		d_start_selection_mark = buffer.create_mark(null, iter, false);
		d_end_selection_mark = buffer.create_mark(null, iter, false);

		update_selection(iter);
		update_cursor_for_state(event.state);

		return true;
	}

	private void update_selection(Gtk.TextIter cursor)
	{
		var buffer = source_view.buffer;

		Gtk.TextIter start, end;

		buffer.get_iter_at_mark(out start, d_start_selection_mark);
		buffer.get_iter_at_mark(out end, d_end_selection_mark);

		// Clear to original selection
		if (start.get_line() < end.get_line())
		{
			var next = cursor;
			next.forward_line();

			clear_original_selection(next, end, true);
		}
		else
		{
			clear_original_selection(end, cursor, false);
		}

		update_selection_range(start, cursor, d_selection_mode == DiffSelectionMode.SELECTING);
		buffer.move_mark(d_end_selection_mark, cursor);
	}

	private bool motion_notify_event_on_view(Gdk.EventMotion event)
	{
		Gtk.TextIter iter;

		if (!get_iter_from_pointer_position(out iter))
		{
			return false;
		}

		update_cursor_for_state(event.state);

		if (d_selection_mode == DiffSelectionMode.NONE)
		{
			return false;
		}

		update_selection(iter);
		return true;
	}

	private void update_has_selection()
	{
		var buffer = source_view.buffer;

		Gtk.TextIter iter;
		buffer.get_start_iter(out iter);

		bool something_selected = false;

		if (get_line_selected(iter))
		{
			something_selected = true;
		}
		else
		{
			something_selected = (buffer as Gtk.SourceBuffer).forward_iter_to_source_mark(ref iter, d_selection_category);
		}

		if (something_selected != has_selection)
		{
			has_selection = something_selected;
		}
	}

	private bool button_release_event_on_view(Gdk.EventButton event)
	{
		if (event.button != 1)
		{
			return false;
		}

		d_selection_mode = DiffSelectionMode.NONE;

		var buffer = source_view.buffer;

		if (d_start_selection_mark != null)
		{
			buffer.delete_mark(d_start_selection_mark);
			d_start_selection_mark = null;
		}

		if (d_end_selection_mark != null)
		{
			buffer.delete_mark(d_end_selection_mark);
			d_end_selection_mark = null;
		}

		update_has_selection();
		d_originally_selected.clear();

		return true;
	}
}

// ex:ts=4 noet
