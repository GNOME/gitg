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
	private Settings? d_settings;
	private Settings? d_global_settings;

	[GtkChild (name = "horizontal_layout_enabled")]
	private unowned Gtk.CheckButton d_horizontal_layout_enabled;

	[GtkChild (name = "default_activity")]
	private unowned Gtk.ComboBox d_default_activity;

	[GtkChild (name = "gravatar_enabled")]
	private unowned Gtk.CheckButton d_gravatar_enabled;

	[GtkChild (name = "monitoring_enabled" )]
	private unowned Gtk.CheckButton d_monitoring_enabled;

	[GtkChild (name = "diff_highlighting_enabled")]
	private unowned Gtk.CheckButton d_diff_highlighting_enabled;

	[GtkChild (name = "default_style_scheme")]
	private unowned Gtk.ComboBox d_default_style_scheme;

	[GtkChild (name = "syntax_scheme_store")]
	private unowned Gtk.ListStore d_syntax_scheme_store;

	[GtkChild (name = "font_button")]
	private unowned Gtk.FontButton d_font_button;

	[GtkChild (name = "font_button_grid")]
	private unowned Gtk.Grid d_font_button_grid;

	[GtkChild (name = "default_font_checkbutton")]
	private unowned Gtk.CheckButton d_default_font_checkbutton;

	construct
	{
		d_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
		d_global_settings = new Settings("org.gnome.desktop.interface");

		d_horizontal_layout_enabled.active = d_settings.get_enum("orientation") == 0;

		d_horizontal_layout_enabled.notify["active"].connect((obj, spec)=> {
			if (d_block)
			{
				return;
			}

			if (!d_settings.set_enum("orientation", d_horizontal_layout_enabled.active ? 0 : 1))
			{
				d_horizontal_layout_enabled.active = d_settings.get_enum("orientation") == 0;
			}
		});

		var style_manager = Gtk.SourceStyleSchemeManager.get_default ();
		Gtk.TreeIter iter;

		foreach (var id in style_manager.get_scheme_ids()) {
			var scheme = style_manager.get_scheme(id);
			d_syntax_scheme_store.append (out iter);
			d_syntax_scheme_store.set (iter, 0, scheme.name, 1, scheme.id);
		}

		d_settings.changed["orientation"].connect(orientation_changed);

		d_settings.bind("default-activity",
		                d_default_activity,
		                "active-id",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("use-gravatar",
		                d_gravatar_enabled,
		                "active",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("enable-monitoring",
		                d_monitoring_enabled,
		                "active",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("enable-diff-highlighting",
		                d_diff_highlighting_enabled,
		                "active",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("style-scheme",
		                d_default_style_scheme,
		                "active-id",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("use-default-font",
		              d_default_font_checkbutton,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_settings.bind("use-default-font",
		              d_font_button_grid,
		              "sensitive",
		              SettingsBindFlags.GET | SettingsBindFlags.SET | SettingsBindFlags.INVERT_BOOLEAN);

		d_settings.bind("monospace-font-name",
		                d_font_button,
		                "font",
		                SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_global_settings.changed["monospace-font-name"].connect((s, k) => {
			update_system_font_label();
		});

		update_system_font_label();
	}

	private void update_system_font_label()
	{
		var system_fontname = d_global_settings.get_string ("monospace-font-name");
		string label = _("_Use the system fixed width font (%s)").printf(system_fontname);
		d_default_font_checkbutton.label = label;
	}

	public override void dispose()
	{
		if (d_settings != null)
		{
			d_settings.changed["orientation"].disconnect(orientation_changed);
			d_settings = null;
		}

		base.dispose();
	}

	private void orientation_changed(Settings settings, string key)
	{
		d_block = true;
		d_horizontal_layout_enabled.active = settings.get_enum(key) == 0;
		d_block = false;
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
