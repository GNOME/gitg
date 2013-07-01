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

public class PreferencesHistory : Object, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private Gtk.Widget? d_widget;
	private bool d_block;

	private void bind_check(Settings settings, string setting, Object obj)
	{
		settings.bind(setting,
		              obj,
		              "active",
		              SettingsBindFlags.GET |
		              SettingsBindFlags.SET);
	}

	private static int round_val(double val)
	{
		int ival = (int)val;

		return ival + (int)(val - ival > 0.5);
	}

	private Gtk.Widget build_ui()
	{
		if (d_widget != null)
		{
			return d_widget;
		}

		var settings = new Settings("org.gnome.gitg.preferences.history");

		var ret = GitgExt.UI.from_builder("ui/gitg-preferences-history.ui",
		                                  "main",
		                                  "collapse_inactive_lanes_enabled",
		                                  "collapse_inactive_lanes",
		                                  "topological_order",
		                                  "show_stash",
		                                  "show_staged",
		                                  "show_unstaged");

		d_widget = ret["main"] as Gtk.Widget;

		bind_check(settings,
		           "collapse-inactive-lanes-enabled",
		           ret["collapse_inactive_lanes_enabled"]);

		bind_check(settings, "topological-order", ret["topological_order"]);
		bind_check(settings, "show-stash", ret["show_stash"]);
		bind_check(settings, "show-staged", ret["show_staged"]);
		bind_check(settings, "show-unstaged", ret["show_unstaged"]);

		var collapse = ret["collapse_inactive_lanes"] as Gtk.Scale;

		collapse.get_adjustment().value_changed.connect((adj) => {
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
			update_collapse_inactive_lanes(settings, collapse);
			d_block = false;
		});

		d_widget.destroy.connect((w) => {
			settings.disconnect(monsig);
		});

		update_collapse_inactive_lanes(settings, collapse);

		return d_widget;
	}

	private static void update_collapse_inactive_lanes(Settings settings, Gtk.Scale collapse)
	{
		var val = round_val(collapse.get_value());
		var nval = settings.get_int("collapse-inactive-lanes");

		if (val != nval)
		{
			collapse.set_value((double)nval);
		}
	}

	public Gtk.Widget widget
	{
		owned get
		{
			return build_ui();
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
