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

namespace GitgFiles
{

public class TreeStore : Gtk.TreeStore
{
	struct Item
	{
		string root;
		Ggit.TreeEntry entry;
	}

	private uint d_update_id;
	private Ggit.Tree d_tree;

	public Ggit.Tree? tree
	{
		get { return d_tree; }
		set
		{
			d_tree = value;
			update();
		}
	}

	construct
	{
		set_column_types(new Type[] {typeof(Icon), typeof(string), typeof(bool), typeof(Ggit.OId)});

		set_sort_func(0, (model, a, b) => {
			string aname;
			string bname;
			bool aisdir;
			bool bisdir;

			model.get(a, 1, out aname, 2, out aisdir);
			model.get(b, 1, out bname, 2, out bisdir);

			if (aisdir == bisdir)
			{
				return strcmp(aname.collate_key_for_filename(),
				              bname.collate_key_for_filename());
			}
			else if (aisdir)
			{
				return -1;
			}
			else
			{
				return 1;
			}
		});

		set_sort_column_id(0, Gtk.SortType.ASCENDING);
	}

	protected override void dispose()
	{
		if (d_update_id != 0)
		{
			Source.remove(d_update_id);
			d_update_id = 0;
		}

		base.dispose();
	}

	public Ggit.OId get_id(Gtk.TreeIter iter)
	{
		Ggit.OId ret;

		get(iter, 3, out ret);

		return ret;
	}

	public string get_full_path(Gtk.TreeIter iter)
	{
		string ret = get_name(iter);
		Gtk.TreeIter parent;

		while (iter_parent(out parent, iter))
		{
			ret = Path.build_filename(get_name(parent), ret);
			iter = parent;
		}

		return ret;
	}

	public string get_name(Gtk.TreeIter iter)
	{
		string ret;

		get(iter, 1, out ret);

		return ret;
	}

	public bool get_isdir(Gtk.TreeIter iter)
	{
		bool ret;

		get(iter, 2, out ret);

		return ret;
	}

	private Icon get_entry_icon(Ggit.TreeEntry entry)
	{
		Icon icon;
		var isdir = entry.get_file_mode() == Ggit.FileMode.TREE;

		if (isdir)
		{
			icon = new ThemedIcon("folder");
		}
		else
		{
			var ct = ContentType.guess(entry.get_name(), null, null);

			if (ContentType.is_unknown(ct))
			{
				icon = new ThemedIcon("text-x-generic");
			}
			else
			{
				icon = ContentType.get_icon(ct);
			}
		}

		return icon;
	}

	private void update()
	{
		if (d_update_id != 0)
		{
			Source.remove(d_update_id);
			d_update_id = 0;
		}

		clear();

		if (d_tree == null)
		{
			return;
		}

		List<Item?>? items = null;

		try
		{
			d_tree.walk(Ggit.TreeWalkMode.PRE, (root, entry) => {
				var item = Item();
				item.root = root;
				item.entry = entry;
				items.prepend(item);
				return 0;
			});
		} catch (Error e) { }

		if (items == null)
		{
			return;
		}

		items.reverse();

		var paths = new HashTable<string, Gtk.TreePath>(str_hash, str_equal);
		d_update_id = Idle.add(() => {
			if (items == null)
			{
				d_update_id = 0;
				return false;
			}

			Item item = items.data;
			items.remove_link(items);

			var root = item.root;
			var entry = item.entry;
			var isdir = entry.get_file_mode() == Ggit.FileMode.TREE;

			Gtk.TreeIter? parent = null;

			if (root != "")
			{
				get_iter(out parent, paths.lookup(root));
			}

			Icon icon = get_entry_icon(entry);

			Gtk.TreeIter iter;
			append(out iter, parent);
			set(iter,
			    0, icon,
			    1, entry.get_name(),
			    2, isdir,
			    3, entry.get_id());

			if (isdir)
			{
				string path = root + entry.get_name() + Path.DIR_SEPARATOR_S;

				paths.insert(path, get_path(iter));
			}

			return true;
		});
	}
}

}

// vi:ts=4
