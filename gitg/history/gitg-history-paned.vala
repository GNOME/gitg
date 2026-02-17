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

using Gitg;
using Gtk;

namespace GitgHistory
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-history-paned.ui")]
class Paned : AnimatedPaned
{
	[GtkChild]
	private unowned Box d_box_sidebar;

	[GtkChild]
	private unowned Gitg.AnimatedPaned d_paned_panels;

	[GtkChild]
	private unowned StackSwitcher d_stack_switcher_panels;

	[GtkChild]
	private unowned RefsList d_refs_list;

	[GtkChild]
	private unowned Gitg.CommitListView d_commit_list_view;

	[GtkChild]
	private unowned Stack d_stack_panel;

	[GtkChild]
	private unowned ScrolledWindow d_scrolled_window_commit_list;

	[GtkChild]
	private unowned TreeViewColumn sha1_col;

	[GtkChild]
	private unowned TreeViewColumn subject_col;

	[GtkChild]
	private unowned TreeViewColumn message_col;

	[GtkChild]
	private unowned TreeViewColumn author_col;

	[GtkChild]
	private unowned TreeViewColumn author_name_col;

	[GtkChild]
	private unowned TreeViewColumn author_email_col;

	[GtkChild]
	private unowned TreeViewColumn author_date_col;

	[GtkChild]
	private unowned TreeViewColumn committer_col;

	[GtkChild]
	private unowned TreeViewColumn committer_name_col;

	[GtkChild]
	private unowned TreeViewColumn committer_email_col;

	[GtkChild]
	private unowned TreeViewColumn committer_date_col;

	private GLib.Settings general_settings;

	public Orientation inner_orientation
	{
		get { return d_paned_panels.orientation; }

		set
		{
			if (d_paned_panels.orientation != value)
			{
				d_paned_panels.orientation = value;

				// Swap children
				d_paned_panels.remove(d_scrolled_window_commit_list);
				d_paned_panels.remove(d_stack_panel);

				Widget p1;
				Widget p2;

				if (value == Orientation.HORIZONTAL)
				{
					p1 = d_stack_panel;
					p2 = d_scrolled_window_commit_list;
				}
				else
				{
					p1 = d_scrolled_window_commit_list;
					p2 = d_stack_panel;
				}

				d_paned_panels.pack1(p1, true, true);
				d_paned_panels.pack2(p2, false, false);
			}
		}
	}

	private void store_paned_position(Gitg.AnimatedPaned paned, GLib.Settings settings, string key)
	{
		if (paned.is_animating)
		{
			return;
		}

		if (!paned.get_child1().visible || !paned.get_child2().visible)
		{
			return;
		}

		settings.set_int(key, paned.get_position());
	}

	void reorder_columns(Gtk.TreeView tv, string[] ordered_titles) {
		var by_enum = new HashTable<CommitModelColumns, Gtk.TreeViewColumn>(direct_hash, direct_equal);
		foreach (var c in tv.get_columns()) {
			by_enum.insert(c.get_data<CommitModelColumns>("enum"), c);
		}

		Gtk.TreeViewColumn? prev = null;

		EnumClass ec = (EnumClass) typeof (CommitModelColumns).class_ref ();

		foreach (var title in ordered_titles) {
			unowned EnumValue? ev = ec.get_value_by_nick (title);
			if (ev != null) {
				var cmc = (CommitModelColumns)ev.value;
				var col = by_enum.lookup(cmc);
				if (col == null) continue;
				tv.move_column_after(col, prev);
				prev = col;
			}
		}
	}

	private void update_column_visibility() {
		var visible_columns = general_settings.get_strv("visible-columns");
		reorder_columns(commit_list_view, visible_columns);

		EnumClass ec = (EnumClass) typeof (CommitModelColumns).class_ref ();

		CommitModelColumns[] array_cols = {};
		for (int i = 0; i < visible_columns.length; i++) {
			unowned EnumValue? ev = ec.get_value_by_nick (visible_columns[i]);
			if (ev != null) {
				var cmc = (CommitModelColumns)ev.value;
				array_cols += cmc;
			}
		}

		foreach (var col in commit_list_view.get_columns()) {
			var visible = col.get_data<CommitModelColumns>("enum") in array_cols;
			col.visible = visible;
			col.notify["visible"].connect (() => {
				Gitg.UiUtils.store_visible_columns_on_gsettings(commit_list_view);
			});
		}
		commit_list_view.headers_visible = general_settings.get_boolean ("columns-header-visible");
	}

	construct
	{
		sha1_col.set_data("enum", CommitModelColumns.SHA1);
		subject_col.set_data("enum", CommitModelColumns.SUBJECT);
		message_col.set_data("enum", CommitModelColumns.MESSAGE);
		author_col.set_data("enum", CommitModelColumns.AUTHOR);
		author_name_col.set_data("enum", CommitModelColumns.AUTHOR_NAME);
		author_email_col.set_data("enum", CommitModelColumns.AUTHOR_DATE);
		author_date_col.set_data("enum", CommitModelColumns.AUTHOR_DATE);
		committer_col.set_data("enum", CommitModelColumns.COMMITTER);
		committer_name_col.set_data("enum", CommitModelColumns.COMMITTER_NAME);
		committer_email_col.set_data("enum", CommitModelColumns.COMMITTER_EMAIL);
		committer_date_col.set_data("enum", CommitModelColumns.COMMITTER_DATE);

		general_settings = new GLib.Settings(Config.APPLICATION_ID + ".preferences.general");
		general_settings.changed["visible-columns"].connect ( (key) => {
			update_column_visibility ();
		});

		update_column_visibility ();

		var state_settings = new GLib.Settings(Gitg.Config.APPLICATION_ID + ".state.history");

		position = state_settings.get_int("paned-sidebar-position");
		d_paned_panels.position = state_settings.get_int("paned-panels-position");

		notify["position"].connect(() => {
			store_paned_position(this, state_settings, "paned-sidebar-position");
		});

		d_paned_panels.notify["position"].connect(() => {
			store_paned_position(d_paned_panels, state_settings, "paned-panels-position");
		});

		var interface_settings = new GLib.Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("orientation",
		                        this,
		                        "inner_orientation",
		                        SettingsBindFlags.GET);

		d_stack_switcher_panels.set_stack(d_stack_panel);
	}

	public Paned()
	{
		Object(orientation: Orientation.HORIZONTAL);
	}

	public RefsList refs_list
	{
		get { return d_refs_list; }
	}

	public Gitg.CommitListView commit_list_view
	{
		get { return d_commit_list_view; }
	}

	public Gtk.Paned paned_panels
	{
		get { return d_paned_panels; }
	}

	public Stack stack_panel
	{
		get { return d_stack_panel; }
	}

	protected override bool draw(Cairo.Context context)
	{
		var ret = base.draw(context);

		if (!get_child1().visible || !get_child2().visible)
		{
			return ret;
		}

		var window = d_box_sidebar.get_window();
		var handlewin = get_handle_window();

		var c = get_style_context();
		c.save();

		Allocation alloc;
		d_stack_switcher_panels.get_allocation(out alloc);

		var y = alloc.y - d_box_sidebar.spacing;
		var hw = 1;
		var w = position + hw;
		var h = alloc.height + d_box_sidebar.spacing + d_stack_switcher_panels.margin_bottom;

		if (window != null)
		{
			int wx;
			window.get_position(out wx, null);
			c.render_frame(context, wx, y, w, h);
		}

		if (handlewin != null)
		{
			int hx;
			handlewin.get_position(out hx, null);

			c.render_background(context, hx, y, hw, h);
		}

		c.restore();

		return ret;
	}
}

}

// ex: ts=4 noet
