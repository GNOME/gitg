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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-interface.ui")]
public class PreferencesInterface : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;
	private bool d_block;

	[GtkChild (name = "horizontal_layout_enabled")]
	private Gtk.CheckButton d_horizontal_layout_enabled;

	construct
	{
		var settings = new Settings("org.gnome.gitg.preferences.interface");

		d_horizontal_layout_enabled.active = settings.get_enum("orientation") == 0;

		d_horizontal_layout_enabled.notify["active"].connect((obj, spec)=> {
			if (d_block)
			{
				return;
			}

			if (!settings.set_enum("orientation", d_horizontal_layout_enabled.active ? 0 : 1))
			{
				d_horizontal_layout_enabled.active = settings.get_enum("orientation") == 0;
			}
		});

		settings.changed["orientation"].connect((s, k) => {
			d_block = true;
			d_horizontal_layout_enabled.active = settings.get_enum("orientation") == 0;
			d_block = false;
		});
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
		owned get { return "/org/gnome/gitg/Preferences/Interface"; }
	}

	public string display_name
	{
		owned get { return _("Interface"); }
	}
}

}

// vi:ts=4
