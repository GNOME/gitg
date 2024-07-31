/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Ignacio Casal Quinteiro
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-remote-notification.ui")]
public class RemoteNotification : ProgressBin, GitgExt.Notification
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private Remote? d_remote;

	[GtkChild ( name = "image_icon" )]
	private unowned Gtk.Image d_image_icon;

	[GtkChild ( name = "label_text" )]
	private unowned Gtk.Label d_label_text;

	[GtkChild ( name = "button_cancel" )]
	private unowned Gtk.Button d_button_cancel;

	private bool d_finished;

	public signal void cancel();

	private string d_text;

	public RemoteNotification(Remote remote)
	{
		d_remote = remote;

		d_remote.bind_property("state", this, "remote_state");
		d_remote.bind_property("transfer-progress", this, "fraction");
	}

	public Gtk.Widget? widget
	{
		owned get { return this; }
	}

	public void success(string text)
	{
		Idle.add(() => {
			d_image_icon.icon_name = "emblem-ok-symbolic";
			this.text = text;

			get_style_context().add_class("success");

			finish(true);

			return false;
		});
	}

	public void error(string text)
	{
		Idle.add(() => {
			d_image_icon.icon_name = "network-error-symbolic";
			this.text = text;

			get_style_context().add_class("error");
			finish(false);

			return false;
		});
	}

	private void finish(bool auto_close)
	{
		Idle.add(() => {
			d_finished = true;
			d_button_cancel.label = _("Close");

			if (auto_close)
			{
				close(3000);
			}

			return false;
		});
	}

	public string text
	{
		get
		{
			return d_text;
		}

		set
		{
			Idle.add(() => {
				d_label_text.set_markup(value);
				return false;
			});
		}
	}

	public RemoteState remote_state
	{
		set
		{
			Idle.add(() => {
				switch (value)
				{
					case Gitg.RemoteState.CONNECTING:
						d_image_icon.icon_name = "network-wireless-acquiring-symbolic";
						break;
					case Gitg.RemoteState.CONNECTED:
						d_image_icon.icon_name = "network-idle-symbolic";
						break;
					case Gitg.RemoteState.TRANSFERRING:
						d_image_icon.icon_name = "network-transmit-receive-symbolic";
						break;
				}

				return false;
			});
		}
	}

	[GtkCallback]
	private void on_button_cancel_clicked()
	{
		if (d_finished)
		{
			close();
		}
		else
		{
			cancel();
		}
	}
}

}

// ex:ts=4 noet
