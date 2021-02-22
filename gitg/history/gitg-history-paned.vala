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
class Paned : Gitg.AnimatedPaned
{
	[GtkChild]
	private unowned Gtk.Box d_box_sidebar;

	[GtkChild]
	private unowned Gitg.AnimatedPaned d_paned_panels;

	[GtkChild]
	private unowned Gtk.StackSwitcher d_stack_switcher_panels;

	[GtkChild]
	private unowned RefsList d_refs_list;

	[GtkChild]
	private unowned Gitg.CommitListView d_commit_list_view;

	[GtkChild]
	private unowned Gtk.Stack d_stack_panel;

	[GtkChild]
	private unowned Gtk.ScrolledWindow d_scrolled_window_commit_list;

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

	// private void slide_in()
	// {
	// 	slide(Gitg.SlidePanedChild.FIRST, Gitg.SlideDirection.IN);

	// 	Gitg.SlidePanedChild child;

	// 	if (inner_orientation == Gtk.Orientation.HORIZONTAL)
	// 	{
	// 		child = Gitg.SlidePanedChild.FIRST;
	// 	}
	// 	else
	// 	{
	// 		child = Gitg.SlidePanedChild.SECOND;
	// 	}

	// 	d_paned_panels.slide(child, Gitg.SlideDirection.IN);
	// }

	// private void slide_out()
	// {
	// 	slide(Gitg.SlidePanedChild.FIRST, Gitg.SlideDirection.OUT);

	// 	Gitg.SlidePanedChild child;

	// 	if (inner_orientation == Gtk.Orientation.HORIZONTAL)
	// 	{
	// 		child = Gitg.SlidePanedChild.FIRST;
	// 	}
	// 	else
	// 	{
	// 		child = Gitg.SlidePanedChild.SECOND;
	// 	}

	// 	d_paned_panels.slide(child, Gitg.SlideDirection.OUT);
	// }

	private void store_paned_position(Gitg.AnimatedPaned paned, Settings settings, string key)
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

	construct
	{
		var state_settings = new Settings(Gitg.Config.APPLICATION_ID + ".state.history");

		position = state_settings.get_int("paned-sidebar-position");
		d_paned_panels.position = state_settings.get_int("paned-panels-position");

		notify["position"].connect(() => {
			store_paned_position(this, state_settings, "paned-sidebar-position");
		});

		d_paned_panels.notify["position"].connect(() => {
			store_paned_position(d_paned_panels, state_settings, "paned-panels-position");
		});

		var interface_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

		interface_settings.bind("orientation",
		                        this,
		                        "inner_orientation",
		                        SettingsBindFlags.GET);

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

	public Gitg.CommitListView commit_list_view
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

		if (!get_child1().visible || !get_child2().visible)
		{
			return ret;
		}

		var window = d_box_sidebar.get_window();
		var handlewin = get_handle_window();

		var c = get_style_context();
		c.save();

		Gtk.Allocation alloc;
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
