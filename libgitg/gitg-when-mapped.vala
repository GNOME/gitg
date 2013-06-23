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
				if (d_sid != 0)
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

// ex: ts=4 noet
