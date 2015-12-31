/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-diff.ui")]
public class Gitg.PreferencesDiff : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild (name = "check_button_wrap_lines")]
	private Gtk.CheckButton d_check_button_wrap_lines;

	[GtkChild (name = "check_button_ignore_whitespace_changes")]
	private Gtk.CheckButton d_check_button_ignore_whitespace_changes;

	[GtkChild (name = "spin_button_tab_width")]
	private Gtk.SpinButton d_spin_button_tab_width;

	[GtkChild (name = "spin_button_context_lines")]
	private Gtk.SpinButton d_spin_button_context_lines;

	construct
	{
		var settings = new Settings("org.gnome.gitg.preferences.diff");

		settings.bind("wrap",
		              d_check_button_wrap_lines,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("ignore-whitespace",
		              d_check_button_ignore_whitespace_changes,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind_with_mapping("context-lines",
		                           d_spin_button_context_lines.adjustment,
		                           "value",
		                           SettingsBindFlags.GET | SettingsBindFlags.SET,
			(value, variant) => {
				value.set_double(variant.get_int32());
				return true;
			},

			(value, expected_type) => {
				return new Variant.int32((int32)value.get_double());
			},

			null, null
		);

		settings.bind_with_mapping("tab-width",
		                           d_spin_button_tab_width.adjustment,
		                           "value",
		                           SettingsBindFlags.GET | SettingsBindFlags.SET,
			(value, variant) => {
				value.set_double(variant.get_int32());
				return true;
			},

			(value, expected_type) => {
				return new Variant.int32((int32)value.get_double());
			},

			null, null
		);
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
		owned get { return "/org/gnome/gitg/Preferences/Diff"; }
	}

	public string display_name
	{
		owned get { return C_("Preferences", "Diff"); }
	}
}

// vi:ts=4
