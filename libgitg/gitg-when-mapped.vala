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
	public class WhenMapped
	{
		public delegate void OnMapped();

		private unowned Gtk.Widget? d_widget;
		private unowned Object? d_lifetime;
		private ulong d_sid;

		public WhenMapped(Gtk.Widget widget)
		{
			d_sid = 0;
			d_widget = widget;

			d_widget.weak_ref(weak_notify);
		}

		private void weak_notify(Object o)
		{
			d_widget = null;
			d_sid = 0;

			if (d_lifetime != null)
			{
				d_lifetime.weak_unref(lifetime_weak_notify);
				d_lifetime = null;
			}
		}

		~WhenMapped()
		{
			if (d_widget != null)
			{
				if (d_sid != 0 && SignalHandler.is_connected(d_widget, d_sid))
				{
					d_widget.disconnect(d_sid);
				}

				d_widget.weak_unref(weak_notify);
				d_widget = null;
			}

			if (d_lifetime != null)
			{
				d_lifetime.weak_unref(lifetime_weak_notify);
				d_lifetime = null;
			}
		}

		private void lifetime_weak_notify(Object o)
		{
			if (d_sid != 0 && d_widget != null)
			{
				d_widget.disconnect(d_sid);
				d_sid = 0;
			}

			d_lifetime = null;
		}

		public void update(owned OnMapped mapped, Object? lifetime = null)
		{
			if (d_widget == null)
			{
				return;
			}

			if (d_sid != 0)
			{
				d_widget.disconnect(d_sid);
				d_sid = 0;
			}

			if (d_lifetime != null)
			{
				d_lifetime.weak_unref(lifetime_weak_notify);
				d_lifetime = null;
			}

			if (d_widget.get_mapped())
			{
				mapped();
			}
			else
			{
				d_sid = d_widget.map.connect(() => {
					d_widget.disconnect(d_sid);
					d_sid = 0;

					if (d_lifetime != null)
					{
						d_lifetime.weak_unref(lifetime_weak_notify);
						d_lifetime = null;
					}

					mapped();
				});

				d_lifetime = lifetime;

				if (d_lifetime != null)
				{
					d_lifetime.weak_ref(lifetime_weak_notify);
				}
			}
		}
	}
}

// ex:ts=4 noet
