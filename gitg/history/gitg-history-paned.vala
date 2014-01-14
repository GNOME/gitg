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
	private Gtk.StackSwitcher d_stack_switcher_panels;

	[GtkChild]
	private RefsList d_refs_list;

	[GtkChild]
	private Gtk.TreeView d_commit_list_view;

	[GtkChild]
	private Gtk.Stack d_stack_panel;

	[GtkChild]
	private Gd.StyledTextRenderer d_renderer_commit_list_author;

	[GtkChild]
	private Gd.StyledTextRenderer d_renderer_commit_list_author_date;

	[GtkChild]
	private Gtk.ScrolledWindow d_scrolled_window_commit_list;

	[Notify]
	public Gtk.Orientation inner_orientation
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

				Gtk.Widget p1;
				Gtk.Widget p2;

				if (value == Gtk.Orientation.HORIZONTAL)
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

	construct
	{
		var state_settings = new Settings("org.gnome.gitg.state.history");

		state_settings.bind("paned-sidebar-position",
		                    this,
		                    "position",
		                    SettingsBindFlags.GET | SettingsBindFlags.SET);

		state_settings.bind("paned-panels-position",
		                    d_paned_panels,
		                    "position",
		                    SettingsBindFlags.GET | SettingsBindFlags.SET);

		var interface_settings = new Settings("org.gnome.gitg.preferences.interface");

		interface_settings.bind("orientation",
		                        this,
		                        "inner_orientation",
		                        SettingsBindFlags.GET);

		d_renderer_commit_list_author.add_class("dim-label");
		d_renderer_commit_list_author_date.add_class("dim-label");

		d_stack_switcher_panels.set_stack(d_stack_panel);
	}

	public Paned()
	{
		Object(orientation: Gtk.Orientation.HORIZONTAL);
	}

	public RefsList refs_list
	{
		get { return d_refs_list; }
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

	protected override bool draw(Cairo.Context context)
	{
		var ret = base.draw(context);

		var window = d_box_sidebar.get_window();
		var handlewin = get_handle_window();

		var c = get_style_context();
		c.save();

		c.add_region("panel-switcher", 0);

		Gtk.Allocation alloc;
		d_stack_switcher_panels.get_allocation(out alloc);

		var y = alloc.y - d_box_sidebar.spacing;
		var hw = handlewin.get_width();
		var w = position + hw;
		var h = alloc.height + d_box_sidebar.spacing + d_stack_switcher_panels.margin_bottom;

		int wx;
		window.get_position(out wx, null);

		c.render_frame(context, wx, y, w, h);

		int hx;
		handlewin.get_position(out hx, null);

		c.render_background(context, hx, y, hw, h);

		c.restore();

		return ret;
	}
}

}

// ex: ts=4 noet
