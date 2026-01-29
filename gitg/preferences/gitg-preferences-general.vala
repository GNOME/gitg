/*
 * This file is part of gitg
 *
 * Copyright (C) 2062 - Alberto Fanjul
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-general.ui")]
public class PreferencesGeneral : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild (name = "smart_push")]
	private unowned Gtk.CheckButton d_smart_push;

	construct
	{
		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.general");

		settings.bind("smart-push",
		              d_smart_push,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);
	}

	public Gtk.Widget widget
	{
		owned get
		{
			return this;
		}
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/Preferences/General"; }
	}

	public string display_name
	{
		owned get { return _("General"); }
	}
}
}

// vi:ts=4
