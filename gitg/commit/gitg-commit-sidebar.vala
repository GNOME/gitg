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

	public signal void selected_items_changed(Gitg.SidebarItem[] items);

	public class File : Object, Gitg.SidebarItem
	{
		public enum Type
		{
			NONE,
			STAGED,
			UNSTAGED,
			UNTRACKED
		}

		Gitg.StageStatusFile d_file;
		Type d_type;

		public File(Gitg.StageStatusFile f, Type type)
		{
			d_file = f;
			d_type = type;
		}

		public Gitg.StageStatusFile file
		{
			get { return d_file; }
		}

		public string text
		{
			owned get { return d_file.path; }
		}

		public Type stage_type
		{
			get { return d_type; }
		}

		private string? icon_for_status(Ggit.StatusFlags status)
		{
			if ((status & (Ggit.StatusFlags.INDEX_NEW |
				           Ggit.StatusFlags.WORKING_TREE_NEW)) != 0)
			{
				return "list-add-symbolic";
			}
			else if ((status & (Ggit.StatusFlags.INDEX_MODIFIED |
				                Ggit.StatusFlags.INDEX_RENAMED |
				                Ggit.StatusFlags.INDEX_TYPECHANGE |
				                Ggit.StatusFlags.WORKING_TREE_MODIFIED |
				                Ggit.StatusFlags.WORKING_TREE_TYPECHANGE)) != 0)
			{
				return "text-editor-symbolic";
			}
			else if ((status & (Ggit.StatusFlags.INDEX_DELETED |
				                Ggit.StatusFlags.WORKING_TREE_DELETED)) != 0)
			{
				return "edit-delete-symbolic";
			}

			return null;
		}

		public string? icon_name
		{
			owned get { return icon_for_status(d_file.flags); }
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

		var sel = get_selection();
		sel.mode = Gtk.SelectionMode.MULTIPLE;
	}

	private File.Type get_item_type(Gitg.SidebarItem item)
	{
		var header = item as Gitg.SidebarStore.SidebarHeader;

		if (header != null)
		{
			return (File.Type)header.id;
		}

		var file = item as File;

		if (file != null)
		{
			return file.stage_type;
		}

		return File.Type.NONE;
	}

	private File.Type selected_type()
	{
		foreach (var item in get_selected_items<Gitg.SidebarItem>())
		{
			var tp = get_item_type(item);

			if (tp != File.Type.NONE)
			{
				return tp;
			}
		}

		return File.Type.NONE;
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

		// Prevent selection of the untracked header
		var header = item as Gitg.SidebarStore.SidebarHeader;

		if (header != null && (File.Type)header.id == File.Type.UNTRACKED)
		{
			return false;
		}

		var seltp = selected_type();

		if (seltp == File.Type.NONE)
		{
			return true;
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

	public File[] items_of_type(File.Type type)
	{
		var ret = new File[0];

		model.foreach((m, path, iter) => {
			var item = model.item_for_iter(iter);

			if (item == null)
			{
				return false;
			}

			var file = item as File;

			if (file != null && file.stage_type == type)
			{
				ret += file;
			}

			return false;
		});

		return ret;
	}
}

}

// ex: ts=4 noet
