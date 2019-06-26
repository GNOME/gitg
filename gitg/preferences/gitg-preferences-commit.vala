/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-commit.ui")]
public class PreferencesCommit : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild (name = "check_button_show_markup")]
	private Gtk.CheckButton d_check_button_show_markup;

	[GtkChild (name = "grid_show_markup")]
	private Gtk.Grid d_grid_show_markup;

	[GtkChild (name = "check_button_show_subject_margin")]
	private Gtk.CheckButton d_check_button_show_subject_margin;

	[GtkChild (name = "spin_button_subject_margin_grid")]
	private Gtk.Grid d_spin_button_subject_margin_grid;
	[GtkChild (name = "spin_button_subject_margin")]
	private Gtk.SpinButton d_spin_button_subject_margin;

	[GtkChild (name = "check_button_show_right_margin")]
	private Gtk.CheckButton d_check_button_show_right_margin;

	[GtkChild (name = "spin_button_right_margin_grid")]
	private Gtk.Grid d_spin_button_right_margin_grid;
	[GtkChild (name = "spin_button_right_margin")]
	private Gtk.SpinButton d_spin_button_right_margin;

	[GtkChild (name = "enable_spell_checking")]
	private Gtk.CheckButton d_enable_spell_checking;


  [GtkChild (name = "radiobutton_default_datetime" )]
	private Gtk.RadioButton d_default_datetime_groupbox;

	[GtkChild (name = "radiobutton_custom_datetime" )]
	private Gtk.RadioButton d_custom_datetime;

  [GtkChild (name = "combobox_default_prefered_datetime")]
	private Gtk.ComboBox d_default_datetime;

	[GtkChild (name = "gtkentry_custom_datetime")]
	private Gtk.Entry d_custom_datetime_entry;

	construct
	{
		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.commit.message");

		settings.bind("show-markup",
		              d_check_button_show_markup,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-markup",
		              d_grid_show_markup,
		              "sensitive",
		              SettingsBindFlags.GET);

		settings.bind("show-subject-margin",
		              d_check_button_show_subject_margin,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-subject-margin",
		              d_spin_button_subject_margin_grid,
		              "sensitive",
		              SettingsBindFlags.GET);

		settings.bind("subject-margin-position",
		              d_spin_button_subject_margin,
		              "value",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-right-margin",
		              d_check_button_show_right_margin,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("show-right-margin",
		              d_spin_button_right_margin_grid,
		              "sensitive",
		              SettingsBindFlags.GET);

		settings.bind("right-margin-position",
		              d_spin_button_right_margin,
		              "value",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("enable-spell-checking",
		              d_enable_spell_checking,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("default-prefered-datetime",
		             d_default_datetime,
		             "active-id",
		             SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("custom-prefered-datetime-entry",
		             d_custom_datetime_entry,
		             "text",
		             SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("prefered-datetime-selection",
		              this,
		              "prefered_datetime_selection",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		create_prefered_datetime_signals_radiobutton();
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
		owned get { return "/org/gnome/gitg/Preferences/Commit"; }
	}

	public string display_name
	{
		owned get { return C_("Preferences", "Commit"); }
	}

    public string prefered_datetime_selection
	{
		get
		{
		    if (d_custom_datetime.active)
		        return "custom";

		    return "custom";
		}

		set
		{
		    if (value == "custom"){
		        d_custom_datetime.active = true;
		        d_custom_datetime_entry.editable = true;
		    }
		    else{
		        d_default_datetime_groupbox.active = true;
		        d_custom_datetime_entry.editable = false;
		    }
		}
	}

	private void create_prefered_datetime_signals_radiobutton()
	{

	    d_default_datetime_groupbox.notify["active"].connect( () => {
	        notify_property("prefered-datetime-selection");
	    });

	    d_custom_datetime.notify["active"].connect( () => {
	        notify_property("prefered-datetime-selection");
	    });
	}

}

}

// vi:ts=4
