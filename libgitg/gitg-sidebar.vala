/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

public enum SidebarHint
{
	NONE,
	HEADER,
	SEPARATOR,
	DUMMY
}

public enum SidebarColumn
{
	HINT,
	SECTION,
	ITEM
}

public interface SidebarItem : Object
{
	public abstract string text { owned get; }
	public abstract string? icon_name { owned get; }

	public signal void activated(int numclick);

	public virtual void activate(int numclick)
	{
		activated(numclick);
	}
}

public class SidebarStore : Gtk.TreeStore
{
	private uint d_sections;
	private SList<Gtk.TreeIter?> d_parents;
	private bool d_clearing;

	private class SidebarText : Object, SidebarItem
	{
		private string d_text;

		public SidebarText(string text)
		{
			d_text = text;
		}

		public string text
		{
			owned get { return d_text; }
		}

		public string? icon_name
		{
			owned get { return null; }
		}
	}

	private void append_real(SidebarItem      item,
	                         uint             hint,
	                         out Gtk.TreeIter iter)
	{
		if (d_parents != null)
		{
			base.append(out iter, d_parents.data);
		}
		else
		{
			base.append(out iter, null);
		}

		@set(iter,
		     SidebarColumn.ITEM, item,
		     SidebarColumn.HINT, hint,
		     SidebarColumn.SECTION, d_sections);
	}

	public SidebarStore append_dummy(string text)
	{
		Gtk.TreeIter iter;
		append_real(new SidebarText(text), SidebarHint.DUMMY, out iter);

		return this;
	}

	public new SidebarStore append(SidebarItem item)
	{
		Gtk.TreeIter iter;
		append_real(item, SidebarHint.NONE, out iter);

		return this;
	}

	public SidebarStore begin_header(string text)
	{
		Gtk.TreeIter iter;

		append_real(new SidebarText(text), SidebarHint.HEADER, out iter);
		d_parents.prepend(iter);

		return this;
	}

	public SidebarStore end_header()
	{
		if (d_parents != null)
		{
			d_parents.delete_link(d_parents);
		}

		return this;
	}

	public uint begin_section()
	{
		d_parents = null;
		return d_sections;
	}

	public void end_section()
	{
		++d_sections;
	}

	public bool clearing
	{
		get { return d_clearing; }
	}

	public new void clear()
	{
		d_clearing = true;
		base.clear();
		d_clearing = false;

		d_sections = 0;
	}

	public SidebarItem item_for_iter(Gtk.TreeIter iter)
	{
		SidebarItem item;

		@get(iter, SidebarColumn.ITEM, out item);

		return item;
	}

	public void activate(Gtk.TreeIter iter, int numclick)
	{
		SidebarItem? item;

		@get(iter, SidebarColumn.ITEM, out item);

		if (item != null)
		{
			item.activate(numclick);
		}
	}
}

[GtkTemplate ( ui = "/org/gnome/gitg/gtk/sidebar/sidebar-view.ui" )]
public class Sidebar : Gtk.TreeView
{
	[GtkChild (name = "column")]
	private Gtk.TreeViewColumn d_column;

	[GtkChild (name = "renderer_icon")]
	private Gtk.CellRendererPixbuf d_renderer_icon;

	[GtkChild (name = "renderer_header")]
	private Gtk.CellRendererText d_renderer_header;

	[GtkChild (name = "renderer_text")]
	private Gtk.CellRendererText d_renderer_text;

	public signal void deselected();

	public signal void populate_popup(Gtk.Menu menu);

	construct
	{
		d_column.set_cell_data_func(d_renderer_icon, (layout, cell, model, iter) => {
			SidebarItem item;
			model.get(iter, SidebarColumn.ITEM, out item);

			cell.visible = (item.icon_name != null);

			var r = (Gtk.CellRendererPixbuf)cell;
			r.icon_name = item.icon_name;
		});

		d_column.set_cell_data_func(d_renderer_header, (layout, cell, model, iter) => {
			SidebarHint hint;
			SidebarItem item;

			model.get(iter, SidebarColumn.HINT, out hint, SidebarColumn.ITEM, out item);

			cell.visible = (hint == SidebarHint.HEADER);

			var r = (Gtk.CellRendererText)cell;
			r.text = item.text;
		});

		d_column.set_cell_data_func(d_renderer_text, (layout, cell, model, iter) => {
			SidebarHint hint;
			SidebarItem item;

			model.get(iter, SidebarColumn.HINT, out hint, SidebarColumn.ITEM, out item);

			cell.visible = (hint != SidebarHint.HEADER);

			var r = (Gtk.CellRendererText)cell;
			r.text = item.text;

			if (hint == SidebarHint.DUMMY)
			{
				var col = get_style_context().get_color(Gtk.StateFlags.INSENSITIVE);
				r.foreground_rgba = col;
			}
			else
			{
				r.foreground_set = false;
			}
		});

		set_row_separator_func((model, iter) => {
			SidebarHint hint;
			model.get(iter, SidebarColumn.HINT, out hint);

			return hint == SidebarHint.SEPARATOR;
		});

		var sel = get_selection();

		sel.set_select_function((sel, model, path, cursel) => {
			Gtk.TreeIter iter;
			model.get_iter(out iter, path);

			uint hint;

			model.get(iter, SidebarColumn.HINT, out hint);

			return hint != SidebarHint.HEADER && hint != SidebarHint.DUMMY;
		});

		sel.changed.connect((sel) => {
			Gtk.TreeIter iter;

			if (model.clearing)
			{
				return;
			}

			if (sel.get_selected(null, out iter))
			{
				model.activate(iter, 1);
			}
			else
			{
				deselected();
			}
		});
	}

	public T? get_selected_item<T>()
	{
		var sel = get_selection();
		Gtk.TreeIter iter;

		if (sel.get_selected(null, out iter))
		{
			return (T)model.item_for_iter(iter);
		}

		return null;
	}

	public void select(SidebarItem item)
	{
		model.foreach((m, path, iter) => {
			if (model.item_for_iter(iter) == item)
			{
				get_selection().select_iter(iter);
				return true;
			}

			return false;
		});
	}

	protected override void row_activated(Gtk.TreePath path, Gtk.TreeViewColumn column)
	{
		if (model.clearing)
		{
			return;
		}

		Gtk.TreeIter iter;

		if (model.get_iter(out iter, path))
		{
			model.activate(iter, 2);
		}
	}

	public new SidebarStore model
	{
		get { return base.get_model() as SidebarStore; }
		set { base.set_model(value); }
	}

	private bool do_populate_popup(Gdk.EventButton? event)
	{
		Gtk.Menu menu = new Gtk.Menu();

		populate_popup(menu);

		if (menu.get_children() == null)
		{
			return false;
		}

		menu.show_all();
		menu.attach_to_widget(this, null);

		uint button = 0;
		uint32 t = Gdk.CURRENT_TIME;

		if (event != null)
		{
			button = event.button;
			t = event.time;
		}

		menu.popup(null, null, null, button, t);
		return true;
	}

	protected override bool button_press_event(Gdk.EventButton event)
	{
		var ret = base.button_press_event(event);

		Gdk.Event *ev = (Gdk.Event *)event;

		if (ev->triggers_context_menu())
		{
			return do_populate_popup(event);
		}

		return ret;
	}

	protected override bool popup_menu()
	{
		return do_populate_popup(null);
	}
}

}

// ex: ts=4 noet
