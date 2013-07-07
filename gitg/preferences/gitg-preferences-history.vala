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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-history.ui")]
public class PreferencesHistory : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;
	private bool d_block;

	[GtkChild (name = "collapse_inactive_lanes_enabled")]
	private Gtk.CheckButton d_collapse_inactive_lanes_enabled;

	[GtkChild (name = "adjustment_collapse")]
	private Gtk.Adjustment d_adjustment_collapse;
	[GtkChild (name = "collapse_inactive_lanes")]
	private Gtk.Scale d_collapse_inactive_lanes;

	[GtkChild (name = "topological_order")]
	private Gtk.CheckButton d_topological_order;

	[GtkChild (name = "show_stash")]
	private Gtk.CheckButton d_show_stash;

	[GtkChild (name = "show_staged")]
	private Gtk.CheckButton d_show_staged;

	[GtkChild (name = "show_unstaged")]
	private Gtk.CheckButton d_show_unstaged;

	private static int round_val(double val)
	{
		int ival = (int)val;

		return ival + (int)(val - ival > 0.5);
	}

	construct
	{
		var settings = new Settings("org.gnome.gitg.preferences.history");

		settings.bind("collapse-inactive-lanes-enabled",
		              d_collapse_inactive_lanes_enabled,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("topological-order",
		              d_topological_order,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-stash",
		              d_show_stash,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-staged",
		              d_show_staged,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-unstaged",
		              d_show_unstaged,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_adjustment_collapse.value_changed.connect((adj) => {
			if (d_block)
			{
				return;
			}

			var nval = round_val(adj.get_value());
			var val = settings.get_int("collapse-inactive-lanes");

			if (val != nval)
			{
				settings.set_int("collapse-inactive-lanes", nval);
			}

			d_block = true;
			adj.set_value(nval);
			d_block = false;
		});

		var monsig = settings.changed["collapse-inactive-lanes"].connect((s, k) => {
			d_block = true;
			update_collapse_inactive_lanes(settings);
			d_block = false;
		});

		destroy.connect((w) => {
			settings.disconnect(monsig);
		});

		update_collapse_inactive_lanes(settings);
	}

	private void update_collapse_inactive_lanes(Settings settings)
	{
		var val = round_val(d_collapse_inactive_lanes.get_value());
		var nval = settings.get_int("collapse-inactive-lanes");

		if (val != nval)
		{
			d_collapse_inactive_lanes.set_value((double)nval);
		}
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
		owned get { return "/org/gnome/gitg/Preferences/History"; }
	}

	public string display_name
	{
		owned get { return _("History"); }
	}
}

}

// vi:ts=4
