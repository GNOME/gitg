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

class Gitg.DiffViewFileSelectable : Object
{
	private string d_selection_category = "selection";
	private Gtk.TextTag d_selection_tag;
	private bool d_is_selecting;
	private bool d_is_deselecting;
	private Gtk.TextMark d_start_selection_mark;
	private Gtk.TextMark d_end_selection_mark;

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

		source_view.get_style_context().add_class("handle-selection");

		source_view.realize.connect(() => {
			update_cursor(Gdk.CursorType.LEFT_PTR);
		});

		source_view.notify["state-flags"].connect(() => {
			update_cursor(Gdk.CursorType.LEFT_PTR);
		});

		d_selection_tag = source_view.buffer.create_tag("selection");

		source_view.style_updated.connect(update_theme);
		update_theme();
	}

	private void update_cursor(Gdk.CursorType type)
	{
		var window = source_view.get_window(Gtk.TextWindowType.TEXT);

		if (window == null)
		{
			return;
		}

		var cursor = new Gdk.Cursor.for_display(source_view.get_display(), type);
		window.set_cursor(cursor);
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
		var text_view = source_view as Gtk.TextView;
		Gtk.TextIter start = iter;

		start.set_line_offset(0);
		var buffer = text_view.get_buffer() as Gtk.SourceBuffer;

		return buffer.get_source_marks_at_iter(start, d_selection_category) != null;
	}

	private bool get_line_is_diff(Gtk.TextIter iter)
	{
		var text_view = source_view as Gtk.TextView;
		Gtk.TextIter start = iter;

		start.set_line_offset(0);
		var buffer = text_view.get_buffer() as Gtk.SourceBuffer;

		return (buffer.get_source_marks_at_iter(start, "added") != null) ||
		       (buffer.get_source_marks_at_iter(start, "removed") != null);
	}

	private bool get_line_is_hunk(Gtk.TextIter iter)
	{
		var text_view = source_view as Gtk.TextView;
		Gtk.TextIter start = iter;

		start.set_line_offset(0);
		var buffer = text_view.get_buffer() as Gtk.SourceBuffer;

		return buffer.get_source_marks_at_iter(start, "header") != null;
	}

	private bool get_iter_from_pointer_position(out Gtk.TextIter iter)
	{
		var text_view = source_view as Gtk.TextView;
		var win = text_view.get_window(Gtk.TextWindowType.TEXT);
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
		text_view.window_to_buffer_coords(Gtk.TextWindowType.TEXT, x, y, out win_x, out win_y);

		text_view.get_iter_at_location(out iter, win_x, win_y);

		return true;
	}

	private void select_range(Gtk.TextIter start, Gtk.TextIter end)
	{
		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer() as Gtk.SourceBuffer;

		Gtk.TextIter real_start, real_end;

		real_start = start;
		real_end = end;

		real_start.order(real_end);
		real_start.set_line_offset(0);

		while (real_start.get_line() <= real_end.get_line())
		{
			if (get_line_is_diff(real_start))
			{
				buffer.create_source_mark(null, d_selection_category, real_start);

				var line_end = real_start;
				line_end.forward_to_line_end();

				buffer.apply_tag(d_selection_tag, real_start, line_end);
			}

			if (!real_start.forward_line())
			{
				break;
			}
		}
	}

	private void deselect_range(Gtk.TextIter start, Gtk.TextIter end)
	{
		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer() as Gtk.SourceBuffer;

		Gtk.TextIter real_start, real_end;

		real_start = start;
		real_start.set_line_offset(0);

		real_end = end;
		real_end.forward_to_line_end();

		buffer.remove_source_marks(real_start, real_end, d_selection_category);
		buffer.remove_tag(d_selection_tag, real_start, real_end);
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

		if (get_line_selected(iter))
		{
			d_is_deselecting = true;
			deselect_range(iter, iter);
		}
		else
		{
			d_is_selecting = true;
			select_range(iter, iter);
		}

		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer();

		d_start_selection_mark = buffer.create_mark(null, iter, false);
		d_end_selection_mark = buffer.create_mark(null, iter, false);

		return false;
	}

	private bool motion_notify_event_on_view(Gdk.EventMotion event)
	{
		Gtk.TextIter iter;
		if (!get_iter_from_pointer_position(out iter))
		{
			return false;
		}

		update_cursor(get_line_is_hunk(iter) ? Gdk.CursorType.HAND1 : Gdk.CursorType.LEFT_PTR);

		if (!d_is_selecting && !d_is_deselecting)
		{
			return false;
		}

		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer();

		Gtk.TextIter start, end, current;

		current = iter;

		buffer.get_iter_at_mark(out start, d_start_selection_mark);
		start.order(current);

		if (d_is_selecting)
		{
			select_range(start, current);
		}
		else
		{
			deselect_range(start, current);
		}

		buffer.get_iter_at_mark(out end, d_end_selection_mark);
		if (!end.in_range(start, current))
		{
			start = end;
			current = iter;

			start.order(current);

			if (d_is_selecting)
			{
				deselect_range(start, current);
			}
			else
			{
				select_range(start, current);
			}
		}

		buffer.move_mark(d_end_selection_mark, iter);

		return false;
	}

	private void update_has_selection()
	{
		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer();

		Gtk.TextIter iter;
		buffer.get_start_iter(out iter);

		bool something_selected = false;

		if (get_line_selected(iter))
		{
			something_selected = true;
		}
		else
		{
			something_selected = (buffer as Gtk.SourceBuffer).forward_iter_to_source_mark(iter, d_selection_category);
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

		d_is_selecting = false;
		d_is_deselecting = false;

		var text_view = source_view as Gtk.TextView;
		var buffer = text_view.get_buffer();

		buffer.delete_mark(d_start_selection_mark);
		d_start_selection_mark = null;

		buffer.delete_mark(d_end_selection_mark);
		d_end_selection_mark = null;

		update_has_selection();

		return false;
	}
}

// ex:ts=4 noet
