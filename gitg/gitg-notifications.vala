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
	private Gee.HashMap<GitgExt.Notification, uint> d_delay_handles;
	private Gtk.Box d_box;
	private Gee.HashMap<GitgExt.Notification, ulong> d_handles;

	public Notifications(Gtk.Overlay overlay)
	{
		d_overlay = overlay;
		d_delay_handles = new Gee.HashMap<GitgExt.Notification, uint>();
		d_handles = new Gee.HashMap<GitgExt.Notification, ulong>();

		d_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
		d_box.get_style_context().add_class("notifications");
		d_box.show();

		d_box.valign = Gtk.Align.END;
		d_overlay.add_overlay(d_box);
	}

	public override void dispose()
	{
		foreach (var id in d_delay_handles.values)
		{
			Source.remove(id);
		}

		d_delay_handles.clear();

		foreach (var notification in d_handles.keys)
		{
			notification.disconnect(d_handles[notification]);
		}

		d_handles.clear();

		base.dispose();
	}

	public new void add(GitgExt.Notification notification)
	{
		var revealer = new Gtk.Revealer();

		revealer.margin_top = 1;
		revealer.set_transition_duration(500);
		revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_UP);
		revealer.add(notification.widget);

		notification.widget.show();
		revealer.show();

		d_box.add(revealer);
		revealer.reveal_child = true;

		d_handles[notification] = notification.close.connect((delay) => {
			remove(notification, delay);
		});
	}

	private void remove_now(GitgExt.Notification notification)
	{
		var revealer = notification.widget.get_parent() as Gtk.Revealer;

		notification.disconnect(d_handles[notification]);

		revealer.notify["child-revealed"].connect(() => {
			revealer.remove(notification.widget);
			revealer.destroy();
		});

		revealer.reveal_child = false;
	}

	public void remove(GitgExt.Notification notification, uint delay)
	{
		if (d_delay_handles.has_key(notification))
		{
			Source.remove(d_delay_handles[notification]);
		}

		d_delay_handles[notification] = Timeout.add(delay, () => {
			d_delay_handles.unset(notification);
			remove_now(notification);

			return false;
		});
	}
}

}

// ex:set ts=4 noet:
