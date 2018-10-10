/*
 *
 * Copyright (C) 2018 - Jente Hidskes <hjdskes@gmail.com>
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

public class Theme : Gtk.Widget
{
	private static GLib.Once<Theme> _instance;

	public static unowned Theme instance ()
	{
		return _instance.once (() => { return new Theme (); });
	}

	public bool is_theme_dark()
	{
		var settings = Gtk.Settings.get_default();
		var theme = Environment.get_variable("GTK_THEME");

		var dark = settings.gtk_application_prefer_dark_theme || (theme != null && theme.has_suffix(":dark"));

		if (!dark) {
			var stylecontext = get_style_context();
			Gdk.RGBA rgba;
			var background_set = stylecontext.lookup_color("theme_bg_color", out rgba);

			if (background_set && rgba.red + rgba.green + rgba.blue < 1.0)
			{
				dark = true;
			}
		}

		return dark;
	}
}

}

// ex:ts=4 noet
