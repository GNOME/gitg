/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

class PopupMenu : Object
{
	public signal void populate_menu(GLib.Menu menu, GLib.SimpleActionGroup actions, Gdk.Event? event);
	public signal Gdk.Rectangle? request_menu_position();

	private Gtk.Widget? d_widget;
	private Gtk.GestureClick d_click_gesture;

	public PopupMenu(Gtk.Widget widget)
	{
		d_click_gesture = new Gtk.GestureClick();
		d_click_gesture.set_button(0);
		d_click_gesture.pressed.connect(on_button_pressed);
		widget.add_controller(d_click_gesture);

		d_widget = widget;
	}

	public override void dispose()
	{
		if (d_widget != null)
		{
			d_widget.remove_controller(d_click_gesture);

			d_widget = null;
		}
	}

	private bool popup_menu(Gtk.Widget widget, Gdk.Event? event)
	{
		var menu_model = new GLib.Menu();
		var actions = new GLib.SimpleActionGroup();
		
		populate_menu(menu_model, actions, event);

		if (menu_model.get_n_items() == 0)
		{
			return false;
		}

		var popover = new Gtk.PopoverMenu.from_model(menu_model);
		popover.set_parent(widget);
		popover.insert_action_group("popup", actions);
		popover.set_has_arrow(false);

		if (event == null)
		{
			var position = request_menu_position();

			if (position != null)
			{
				popover.set_pointing_to(position);
			}
		}
		else
		{
			double x, y;
			event.get_position(out x, out y);
			Gdk.Rectangle rect = { (int)x, (int)y, 1, 1 };
			popover.set_pointing_to(rect);
		}

		popover.popup();

		return true;
	}

	private void on_button_pressed(int n_press, double x, double y)
	{
		var event = d_click_gesture.get_current_event();

		if (event == null || !event.triggers_context_menu())
		{
			return;
		}

		d_click_gesture.set_state(Gtk.EventSequenceState.CLAIMED);
		popup_menu(d_widget, event);
	}
}

}

// ex:set ts=4 noet
