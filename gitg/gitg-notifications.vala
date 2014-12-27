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

public class Notifications : Object, GitgExt.Notifications
{
	private Gtk.Overlay d_overlay;
	private Gee.HashSet<uint> d_delay_handles;
	private Gtk.Box d_box;

	public Notifications(Gtk.Overlay overlay)
	{
		d_overlay = overlay;
		d_delay_handles = new Gee.HashSet<uint>();

		d_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
		d_box.get_style_context().add_class("notifications");
		d_box.show();

		d_box.valign = Gtk.Align.END;
		d_overlay.add_overlay(d_box);
	}

	public override void dispose()
	{
		foreach (var id in d_delay_handles)
		{
			Source.remove(id);
		}

		d_delay_handles.clear();

		base.dispose();
	}

	public void add(Gtk.Widget widget)
	{
		var revealer = new Gtk.Revealer();

		revealer.margin_top = 1;
		revealer.set_transition_duration(500);
		revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
		revealer.add(widget);

		widget.show();
		revealer.show();

		d_box.add(revealer);
		revealer.reveal_child = true;
	}

	private void remove_now(Gtk.Widget widget)
	{
		var revealer = widget.get_parent() as Gtk.Revealer;

		revealer.notify["child-revealed"].connect(() => {
			revealer.remove(widget);
			revealer.destroy();
		});

		revealer.reveal_child = false;
	}

	public void remove(Gtk.Widget widget, uint delay)
	{
		if (delay == 0)
		{
			remove_now(widget);
		}

		uint id = 0;

		id = Timeout.add(delay, () => {
			d_delay_handles.remove(id);
			remove_now(widget);

			return false;
		});

		d_delay_handles.add(id);
	}
}

}

// ex:set ts=4 noet:
