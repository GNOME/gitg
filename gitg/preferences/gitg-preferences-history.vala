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

	[GtkChild (name = "mainline_head")]
	private Gtk.CheckButton d_mainline_head;

	[GtkChild (name = "select_current_branch" )]
	private Gtk.RadioButton d_select_current_branch;

	[GtkChild (name = "select_all_branches" )]
	private Gtk.RadioButton d_select_all_branches;

	[GtkChild (name = "select_all_commits" )]
	private Gtk.RadioButton d_select_all_commits;

	[GtkChild (name = "sort_references_by_activity")]
	private Gtk.CheckButton d_sort_references_by_activity;

	[GtkChild (name = "show_upstream_with_branch")]
	private Gtk.CheckButton d_show_upstream_with_branch;

	private Gtk.RadioButton[] d_select_buttons;
	private string[] d_select_names;

	private static int round_val(double val)
	{
		int ival = (int)val;

		return ival + (int)(val - ival > 0.5);
	}

	construct
	{
		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.history");

		settings.bind("collapse-inactive-lanes-enabled",
		              d_collapse_inactive_lanes_enabled,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("topological-order",
		              d_topological_order,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("mainline-head",
		              d_mainline_head,
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

		d_select_buttons = new Gtk.RadioButton[] {
			d_select_current_branch,
			d_select_all_branches,
			d_select_all_commits
		};

		d_select_names = new string[] {
			"current-branch",
			"all-branches",
			"all-commits"
		};

		settings.bind("default-selection",
		              this,
		              "default-selection",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		for (var i = 0; i < d_select_buttons.length; i++) {
			d_select_buttons[i].notify["active"].connect(() => {
				notify_property("default-selection");
			});
		}

		settings.bind_with_mapping("reference-sort-order",
		                           d_sort_references_by_activity,
		                           "active",
		                           SettingsBindFlags.GET | SettingsBindFlags.SET,
			(value, variant) => {
				value.set_boolean(variant.get_string() == "last-activity");
				return true;
			},

		    (value, expected_type) => {
		    	return new Variant.string(value.get_boolean() ? "last-activity" : "name");
		    },

		    null, null
		);

		settings.bind("show-upstream-with-branch",
		              d_show_upstream_with_branch,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);
	}

	public string default_selection
	{
		get
		{
			for (var i = 0; i < d_select_buttons.length; i++)
			{
				if (d_select_buttons[i].active)
				{
					return d_select_names[i];
				}
			}

			return d_select_names[0];
		}

		set
		{
			for (var i = 0; i < d_select_buttons.length; i++)
			{
				if (d_select_names[i] == value)
				{
					d_select_buttons[i].active = true;
					return;
				}
			}
		}
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
