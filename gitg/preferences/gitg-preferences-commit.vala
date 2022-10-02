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
	private unowned Gtk.CheckButton d_check_button_show_markup;

	[GtkChild (name = "grid_show_markup")]
	private unowned Gtk.Grid d_grid_show_markup;

	[GtkChild (name = "check_button_show_subject_margin")]
	private unowned Gtk.CheckButton d_check_button_show_subject_margin;

	[GtkChild (name = "spin_button_subject_margin_grid")]
	private unowned Gtk.Grid d_spin_button_subject_margin_grid;
	[GtkChild (name = "spin_button_subject_margin")]
	private unowned Gtk.SpinButton d_spin_button_subject_margin;

	[GtkChild (name = "check_button_show_right_margin")]
	private unowned Gtk.CheckButton d_check_button_show_right_margin;

	[GtkChild (name = "spin_button_right_margin_grid")]
	private unowned Gtk.Grid d_spin_button_right_margin_grid;
	[GtkChild (name = "spin_button_right_margin")]
	private unowned Gtk.SpinButton d_spin_button_right_margin;

	[GtkChild (name = "spell_language_button")]
	private unowned Gspell.LanguageChooserButton d_spell_language_button;
	[GtkChild (name = "enable_spell_checking")]
	private unowned Gtk.CheckButton d_enable_spell_checking;

	[GtkChild (name = "spin_button_max_num_commit_messages")]
	private unowned Gtk.SpinButton d_spin_button_max_num_commit_messages;

	[GtkChild (name = "spin_button_max_num_days_commit_messages")]
	private unowned Gtk.SpinButton d_spin_button_max_num_days_commit_messages;

	[GtkChild (name = "radiobutton_predefined_datetime" )]
	private unowned Gtk.RadioButton d_predefined_datetime;

	[GtkChild (name = "radiobutton_custom_datetime" )]
	private unowned Gtk.RadioButton d_custom_datetime;

	[GtkChild (name = "combobox_predefined_datetime")]
	private unowned Gtk.ComboBox d_predefined_datetime_combo;

	[GtkChild (name = "custom_datetime")]
	private unowned Gtk.Entry d_custom_datetime_entry;

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

		settings.bind("spell-checking-language", d_spell_language_button,
		              "language-code",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("max-number-commit-messages",
		              d_spin_button_max_num_commit_messages,
		              "value",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("max-number-days-commit-messages",
		              d_spin_button_max_num_days_commit_messages,
		              "value",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("predefined-datetime",
		             d_predefined_datetime_combo,
		             "active-id",
		             SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("custom-datetime",
		             d_custom_datetime_entry,
		             "text",
		             SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("datetime-selection",
		              this,
		              "datetime-selection",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_predefined_datetime.notify["active"].connect(() => {
			if (d_predefined_datetime.active) {
				notify_property("datetime-selection");
			}
		});

		d_custom_datetime.notify["active"].connect(() => {
			if (d_custom_datetime.active) {
				notify_property("datetime-selection");
			}
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
		owned get { return "/org/gnome/gitg/Preferences/Commit"; }
	}

	public string display_name
	{
		owned get { return C_("Preferences", "Commit"); }
	}

	public string datetime_selection
	{
		get
		{
			return d_custom_datetime.active ? "custom" : "predefined";
		}

		set
		{
			if (value == "custom"){
				d_custom_datetime.active = true;
			}
			else
			{
				d_predefined_datetime.active = true;
			}
		}
	}
}

}

// vi:ts=4
