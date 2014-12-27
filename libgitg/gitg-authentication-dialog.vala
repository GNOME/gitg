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

public enum AuthenticationLifeTime
{
	FORGET,
	SESSION,
	FOREVER
}

[GtkTemplate ( ui = "/org/gnome/gitg/ui/gitg-authentication-dialog.ui" )]
public class AuthenticationDialog : Gtk.Dialog
{
	[GtkChild ( name = "label_title" )]
	private Gtk.Label d_label_title;

	[GtkChild ( name = "label_failed" )]
	private Gtk.Label d_label_failed;

	[GtkChild ( name = "entry_username" )]
	private Gtk.Entry d_entry_username;

	[GtkChild ( name = "entry_password" )]
	private Gtk.Entry d_entry_password;

	[GtkChild ( name = "radio_button_forget" )]
	private Gtk.RadioButton d_radio_button_forget;

	[GtkChild ( name = "radio_button_session" )]
	private Gtk.RadioButton d_radio_button_session;

	[GtkChild ( name = "radio_button_forever" )]
	private Gtk.RadioButton d_radio_button_forever;

	private static AuthenticationLifeTime s_last_lifetime;

	static construct
	{
		s_last_lifetime = AuthenticationLifeTime.SESSION;
	}

	public AuthenticationDialog(string url, string? username, bool failed)
	{
		Object(use_header_bar: 1);

		set_default_response(Gtk.ResponseType.OK);

		/* Translators: %s will be replaced with a URL indicating the resource
		   for which the authentication is required. */
		d_label_title.label = _("Password required for %s").printf(url);
		d_label_failed.visible = failed;

		if (username != null)
		{
			d_entry_username.text = username;
			d_entry_password.grab_focus();
		}

		switch (s_last_lifetime)
		{
			case AuthenticationLifeTime.FORGET:
				d_radio_button_forget.active = true;
				break;
			case AuthenticationLifeTime.SESSION:
				d_radio_button_session.active = true;
				break;
			case AuthenticationLifeTime.FOREVER:
				d_radio_button_forever.active = true;
				break;
		}
	}

	public string username
	{
		get { return d_entry_username.text; }
	}

	public string password
	{
		get { return d_entry_password.text; }
	}

	public AuthenticationLifeTime life_time
	{
		get
		{
			if (d_radio_button_forget.active)
			{
				return AuthenticationLifeTime.FORGET;
			}
			else if (d_radio_button_session.active)
			{
				return AuthenticationLifeTime.SESSION;
			}
			else
			{
				return AuthenticationLifeTime.FOREVER;
			}
		}
	}
}

}
