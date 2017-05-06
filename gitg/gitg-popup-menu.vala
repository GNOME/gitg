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
	public signal Gtk.Menu? populate_menu(Gdk.EventButton? event);
	public signal Gdk.Rectangle? request_menu_position();

	private Gtk.Widget? d_widget;

	public PopupMenu(Gtk.Widget widget)
	{
		widget.button_press_event.connect(on_button_press_event);
		widget.popup_menu.connect(on_popup_menu);

		d_widget = widget;
	}

	public override void dispose()
	{
		if (d_widget != null)
		{
			d_widget.button_press_event.disconnect(on_button_press_event);
			d_widget.popup_menu.disconnect(on_popup_menu);

			d_widget = null;
		}
	}

	private bool popup_menu(Gtk.Widget widget, Gdk.EventButton? event)
	{
		var menu = populate_menu(event);

		if (menu == null)
		{
			return false;
		}

		menu.attach_to_widget(widget, null);

		if (event == null)
		{
			var position = request_menu_position();

			if (position == null)
			{
				menu.popup_at_widget(widget, Gdk.Gravity.CENTER, Gdk.Gravity.CENTER);
			}
			else
			{
				menu.popup_at_rect(widget.get_window(),
				                   position,
				                   Gdk.Gravity.CENTER, Gdk.Gravity.WEST);
			}
		}
		else
		{
			menu.popup_at_pointer(event);
		}

		return true;
	}

	private bool on_popup_menu(Gtk.Widget widget)
	{
		return popup_menu(widget, null);
	}

	private bool on_button_press_event(Gtk.Widget widget, Gdk.EventButton event)
	{
		Gdk.Event *ev = (Gdk.Event *)(event);

		if (!ev->triggers_context_menu())
		{
			return false;
		}

		return popup_menu(widget, event);
	}
}

}

// ex:set ts=4 noet
