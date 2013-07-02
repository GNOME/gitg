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

namespace GitgHistory
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-history-paned.ui")]
class Paned : Gtk.Paned
{
	[GtkChild]
	private Gtk.Box d_box_sidebar;

	[GtkChild]
	private Gtk.Paned d_paned_panels;

	[GtkChild]
	private Gtk.Toolbar d_toolbar_panels;

	[GtkChild]
	private NavigationView d_navigation_view;

	[GtkChild]
	private Gtk.TreeView d_commit_list_view;

	[GtkChild]
	private Gtk.Stack d_stack_panel;

	[GtkChild]
	private Gd.StyledTextRenderer d_renderer_commit_list_author;

	[GtkChild]
	private Gd.StyledTextRenderer d_renderer_commit_list_author_date;

	construct
	{
		var state_settings = new Settings("org.gnome.gitg.state.history");

		state_settings.bind("paned-views-position",
		                    this,
		                    "position",
		                    SettingsBindFlags.GET | SettingsBindFlags.SET);

		state_settings.bind("paned-panels-position",
		                    d_paned_panels,
		                    "position",
		                    SettingsBindFlags.GET | SettingsBindFlags.SET);

		var interface_settings = new Settings("org.gnome.gitg.preferences.interface");

		interface_settings.bind("orientation",
		                        d_paned_panels,
		                        "orientation",
		                        SettingsBindFlags.GET);

		d_renderer_commit_list_author.add_class("dim-label");
		d_renderer_commit_list_author_date.add_class("dim-label");
	}

	public Paned()
	{
		Object(orientation: Gtk.Orientation.HORIZONTAL);
	}

	public NavigationView navigation_view
	{
		get { return d_navigation_view; }
	}

	public Gtk.TreeView commit_list_view
	{
		get { return d_commit_list_view; }
	}

	public Gtk.Paned paned_panels
	{
		get { return d_paned_panels; }
	}

	public Gtk.Stack stack_panel
	{
		get { return d_stack_panel; }
	}
}

}

// ex: ts=4 noet
