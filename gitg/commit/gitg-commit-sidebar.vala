/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

class Sidebar : Gitg.Sidebar
{
	[Signal(action = true)]
	public signal void stage_selection();

	[Signal(action = true)]
	public signal void unstage_selection();

	[Signal(action = true)]
	public signal void discard_selection();

	[Signal(action = true)]
	public signal void edit_selection();

	public signal void selected_items_changed(Gitg.SidebarItem[] items);

	public class Item : Object, Gitg.SidebarItem
	{
		public enum Type
		{
			NONE,
			STAGED,
			UNSTAGED,
			UNTRACKED,
			SUBMODULE
		}

		Gitg.StageStatusItem d_item;
		Type d_type;

		public Item(Gitg.StageStatusItem item, Type type)
		{
			d_item = item;
			d_type = type;
		}

		public Gitg.StageStatusItem item
		{
			get { return d_item; }
		}

		public string text
		{
			owned get { return d_item.path; }
		}

		public Type stage_type
		{
			get { return d_type; }
		}

		public string? icon_name
		{
			owned get { return d_item.icon_name; }
		}
	}

	construct
	{
		unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class(get_class());

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.s,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "stage-selection",
		                            0);

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.u,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "unstage-selection",
		                            0);

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.d,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "discard-selection",
		                            0);

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.e,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "edit-selection",
		                            0);

		var sel = get_selection();
		sel.mode = Gtk.SelectionMode.MULTIPLE;
	}

	private Item.Type get_item_type(Gitg.SidebarItem item)
	{
		var header = item as Gitg.SidebarStore.SidebarHeader;

		if (header != null)
		{
			return (Item.Type)header.id;
		}

		var sitem = item as Item;

		if (sitem != null)
		{
			return sitem.stage_type;
		}

		return Item.Type.NONE;
	}

	private Item.Type selected_type()
	{
		foreach (var item in get_selected_items<Gitg.SidebarItem>())
		{
			var tp = get_item_type(item);

			if (tp != Item.Type.NONE)
			{
				return tp;
			}
		}

		return Item.Type.NONE;
	}

	protected override bool select_function(Gtk.TreeSelection sel,
	                                        Gtk.TreeModel     model,
	                                        Gtk.TreePath      path,
	                                        bool              cursel)
	{
		if (cursel)
		{
			return true;
		}

		Gtk.TreeIter iter;
		model.get_iter(out iter, path);

		Gitg.SidebarHint hint;

		var m = model as Gitg.SidebarStore;
		m.get(iter, Gitg.SidebarColumn.HINT, out hint);

		if (hint == Gitg.SidebarHint.DUMMY)
		{
			return false;
		}

		var item = m.item_for_iter(iter);

		// Prevent selection of the untracked and submodule headers
		var header = item as Gitg.SidebarStore.SidebarHeader;

		if (header != null)
		{
			var id = (Item.Type)header.id;

			if (id == Item.Type.UNTRACKED || id == Item.Type.SUBMODULE)
			{
				return false;
			}
		}

		var seltp = selected_type();

		if (seltp == Item.Type.NONE)
		{
			return true;
		}

		// Do not allow multiple selections for submodules
		if (seltp == Item.Type.SUBMODULE)
		{
			return false;
		}

		var tp = get_item_type(item);
		return tp == seltp;
	}

	protected override void selection_changed(Gtk.TreeSelection sel)
	{
		if (model.clearing)
		{
			return;
		}

		var items = get_selected_items<Gitg.SidebarItem>();

		if (items.length == 0)
		{
			deselected();
		}
		else
		{
			selected_items_changed(items);
		}
	}

	public Item[] items_of_type(Item.Type type)
	{
		var ret = new Item[0];

		model.foreach((m, path, iter) => {
			var item = model.item_for_iter(iter);

			if (item == null)
			{
				return false;
			}

			var sitem = item as Item;

			if (sitem != null && sitem.stage_type == type)
			{
				ret += sitem;
			}

			return false;
		});

		return ret;
	}
}

}

// ex: ts=4 noet
