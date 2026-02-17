/*
 * This file is part of gitg
 *
 * Copyright (C) 2062 - Alberto Fanjul
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-preferences-general.ui")]
public class PreferencesGeneral : Gtk.Grid, GitgExt.Preferences
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private unowned Gtk.CheckButton smart_push;

	[GtkChild]
	private unowned Gtk.Grid visible_columns_grid;

	[GtkChild]
	private unowned Gtk.Grid show_column_headers_grid;
	Settings settings;

	private Gtk.TreeView treeview;

	construct
	{
		settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.general");

		settings.bind("smart-push",
		              smart_push,
		              "active",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.changed["visible-columns"].connect((k) => {
			var visible_columns = settings.get_strv("visible-columns");

			EnumClass ec = (EnumClass) typeof (Gitg.CommitModelColumns).class_ref ();

			CommitModelColumns[] array_cols = {};
			for (int i = 0; i < visible_columns.length; i++) {
				unowned EnumValue? ev = ec.get_value_by_nick (visible_columns[i]);
				if (ev != null) {
					var cmc = (Gitg.CommitModelColumns)ev.value;
					array_cols += cmc;
				}
			}

			foreach (var col in treeview.get_columns()) {
				var visible = col.get_data<CommitModelColumns>("enum") in array_cols;
				col.visible = visible;
			}
		});
	}


	public PreferencesGeneral(Gitg.CommitListView commit_list_view)
	{
		treeview = commit_list_view;
		string[] visible_columns = settings.get_strv ("visible-columns");
		var listbox = Gitg.UiUtils.build_listbox_visible_columns (treeview);
		treeview.columns_changed.connect (() => {
			Gitg.UiUtils.store_visible_columns_on_gsettings(treeview);
		});
		listbox.row_reorder.connect((from, to) => {
			Gitg.UiUtils.store_visible_columns_on_gsettings(treeview);
		});
		var sw = new Gtk.ScrolledWindow (null, null);
		sw.set_size_request(-1, 350);
		sw.hexpand = true;
		sw.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
		listbox.vadjustment = sw.vadjustment;
		sw.add(listbox);
		sw.show_all();
		visible_columns_grid.attach (sw, 0, 0, 1, 1);

		var switch_box = Gitg.UiUtils.build_switch_show_headers (treeview);
		switch_box.show_all();
		show_column_headers_grid.attach (switch_box, 0, 0, 1, 1);
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
		owned get { return "/org/gnome/gitg/Preferences/General"; }
	}

	public string display_name
	{
		owned get { return _("General"); }
	}
}
}

// vi:ts=4
