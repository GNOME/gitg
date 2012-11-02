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

class PreferencesInterface : Object, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;
	private bool d_block;

	private Gtk.Widget d_widget;

	private Gtk.Widget build_ui()
	{
		if (d_widget != null)
		{
			return d_widget;
		}

		var settings = new Settings("org.gnome.gitg.preferences.interface");

		var ret = GitgExt.UI.from_builder("ui/gitg-preferences-interface.ui",
		                                  "main",
		                                  "horizontal_layout_enabled");

		d_widget = ret["main"] as Gtk.Widget;

		var check = ret["horizontal_layout_enabled"] as Gtk.CheckButton;

		check.active = settings.get_enum("orientation") == 0;

		check.notify["active"].connect((obj, spec)=> {
			if (d_block)
			{
				return;
			}

			d_block = true;

			if (!settings.set_enum("orientation", check.active ? 1 : 0))
			{
				check.active = settings.get_enum("orientation") == 0;
			}

			d_block = false;
		});

		settings.changed["orientation"].connect((s, k) => {
			if (d_block)
			{
				return;
			}

			d_block = true;
			check.active = settings.get_enum("orientation") == 0;
			d_block = false;
		});

		return d_widget;
	}

	public Gtk.Widget widget
	{
		owned get { return build_ui(); }
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
