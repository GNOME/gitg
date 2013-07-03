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

namespace GitgCommit
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-paned.ui")]
class Paned : Gtk.Paned
{
	[GtkChild (name = "tree_view_files")]
	private Gitg.Sidebar d_tree_view_files;

	[GtkChild (name = "diff_view")]
	private Gitg.DiffView d_diff_view;

	public Gitg.Sidebar tree_view_files
	{
		get { return d_tree_view_files; }
	}

	public Gitg.DiffView diff_view
	{
		get { return d_diff_view; }
	}

	construct
	{
		var state_settings = new Settings("org.gnome.gitg.state.commit");

		state_settings.bind("paned-sidebar-position",
		                    this,
		                    "position",
		                    SettingsBindFlags.GET | SettingsBindFlags.SET);
	}

	public Paned()
	{
		Object(orientation: Gtk.Orientation.HORIZONTAL);
	}
}

}

// ex: ts=4 noet
