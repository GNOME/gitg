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
	private Gdk.Cursor d_cursor_ptr;
	private Gdk.Cursor d_cursor_hand;
	private bool d_is_rubber_band;

	public GtkSource.View source_view
	{
		get; construct set;
	}

	public bool has_selection
	{
		get; private set;
	}

	public int[] get_selected_lines()
	{
		var ret = new int[0];
		Gtk.TextIter iter;

		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		buffer.get_start_iter(out iter);

		while (buffer.forward_iter_to_source_mark(ref iter, d_selection_category))
		{
			ret += iter.get_line();
		}

		return ret;
	}

	public DiffViewFileSelectable(GtkSource.View source_view)
	{
		Object(source_view: source_view);
	}

	construct
	{
		var click_gesture = new Gtk.GestureClick();
		click_gesture.set_button(Gdk.BUTTON_PRIMARY);
		click_gesture.pressed.connect((n_press, x, y) => {
			button_press_event_on_view(x, y, click_gesture.get_current_event_state());
		});
		click_gesture.released.connect((_, _, _) => {
			button_release_event_on_view();
		});
		source_view.add_controller(click_gesture);

		var motion_controller = new Gtk.EventControllerMotion();
		motion_controller.motion.connect((x, y) => {
			update_selection_event(x, y);
		});
		motion_controller.enter.connect((x, y) => {
			update_selection_event(x, y);
		});
		motion_controller.leave.connect(() => {
			update_cursor(cursor_ptr);
		});
		source_view.add_controller(motion_controller);

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

		Gtk.TextIter start;
		source_view.buffer.get_start_iter(out start);

		d_start_selection_mark = source_view.buffer.create_mark(null, start, false);
		d_end_selection_mark = source_view.buffer.create_mark(null, start, false);
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

	private void update_cursor(Gdk.Cursor cursor)
	{
		var window = source_view.get_window(Gtk.TextWindowType.TEXT);

		if (window == null)
		{
			return;
		}

		window.set_cursor(cursor);
	}

	private void update_theme()
	{
		var selection_attributes = new GtkSource.MarkAttributes();
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

		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		return buffer.get_source_marks_at_iter(start, d_selection_category) != null;
	}

	private bool get_line_is_diff(Gtk.TextIter iter)
	{
		Gtk.TextIter start = iter;

		start.set_line_offset(0);

		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		return (buffer.get_source_marks_at_iter(start, "added") != null) ||
		       (buffer.get_source_marks_at_iter(start, "removed") != null);
	}

	private bool get_line_is_hunk(Gtk.TextIter iter)
	{
		Gtk.TextIter start = iter;

		start.set_line_offset(0);

		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		return buffer.get_source_marks_at_iter(start, "header") != null;
	}


	private bool get_iter_from_event_position(out Gtk.TextIter iter, double x, double y)
	{
		int win_x, win_y;

		source_view.window_to_buffer_coords(Gtk.TextWindowType.TEXT, (int)x, (int)y, out win_x, out win_y);
		source_view.get_line_at_y(out iter, win_y, null);

		return true;
	}

	private void update_selection_range(Gtk.TextIter start, Gtk.TextIter end, bool select)
	{
		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		Gtk.TextIter real_start, real_end;

		real_start = start;
		real_end = end;

		if (real_start.compare(real_end) > 0)
		{
			var tmp = real_end;

			real_end = real_start;
			real_start = tmp;
		}

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

	private void forward_to_hunk_end(ref Gtk.TextIter iter)
	{
		iter.forward_line();

		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		if (!buffer.forward_iter_to_source_mark(ref iter, "header"))
		{
			iter.forward_to_end();
		}
	}

	private bool hunk_is_all_selected(Gtk.TextIter iter)
	{
		var start = iter;
		start.forward_line();

		var end = iter;
		forward_to_hunk_end(ref end);

		while (start.compare(end) <= 0)
		{
			if (get_line_is_diff(start) && !get_line_selected(start))
			{
				return false;
			}

			if (!start.forward_line())
			{
				break;
			}
		}

		return true;
	}

	private void update_selection_hunk(Gtk.TextIter iter, bool select)
	{
		var end = iter;
		forward_to_hunk_end(ref end);

		update_selection_range(iter, end, select);
	}

	private void button_press_event_on_view(double x, double y, Gdk.ModifierType state)
	{

		Gtk.TextIter iter;

		if (!get_iter_from_event_position(out iter, x, y))
		{
			return;
		}

		var buffer = source_view.buffer;

		if ((state & Gdk.ModifierType.SHIFT_MASK) != 0)
		{
			update_selection(iter);
			return;
		}

		if (get_line_is_hunk(iter))
		{
			update_selection_hunk(iter, !hunk_is_all_selected(iter));
			return;
		}

		d_is_rubber_band = true;

		var select = !get_line_selected(iter);

		if (select)
		{
			d_selection_mode = DiffSelectionMode.SELECTING;
		}
		else
		{
			d_selection_mode = DiffSelectionMode.DESELECTING;
		}

		d_originally_selected.clear();

		buffer.move_mark(d_start_selection_mark, iter);
		buffer.move_mark(d_end_selection_mark, iter);

		update_selection(iter);
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
			var next = start.get_line() < cursor.get_line() ? cursor : start;
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

	private void update_selection_event(double x, double y)
	{
		Gtk.TextIter iter;

		if (!get_iter_from_event_position(out iter, x, y))
		{
			return;
		}

		if (d_is_rubber_band || (get_line_is_diff(iter) || get_line_is_hunk(iter)))
		{
			update_cursor(cursor_hand);
		}
		else
		{
			update_cursor(cursor_ptr);
		}

		if (!d_is_rubber_band)
		{
			return;
		}

		update_selection(iter);
	}

	private void update_has_selection()
	{
		unowned GtkSource.Buffer buffer = (GtkSource.Buffer) source_view.buffer;

		Gtk.TextIter iter;
		buffer.get_start_iter(out iter);

		bool something_selected = false;

		if (get_line_selected(iter))
		{
			something_selected = true;
		}
		else
		{
			something_selected = buffer.forward_iter_to_source_mark(ref iter, d_selection_category);
		}

		if (something_selected != has_selection)
		{
			has_selection = something_selected;
		}
	}

	private void button_release_event_on_view()
	{
		d_is_rubber_band = false;

		update_has_selection();
	}
}

// ex:ts=4 noet
