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

	protected class SidebarText : Object, SidebarItem
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

	public class SidebarHeader : SidebarText
	{
		private uint d_id;

		public uint id
		{
			get { return d_id; }
		}

		public SidebarHeader(string text, uint id)
		{
			base(text);

			d_id = id;
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

	public SidebarHeader begin_header(string text, uint id = 0)
	{
		Gtk.TreeIter iter;

		var item = new SidebarHeader(text, id);

		append_real(item, SidebarHint.HEADER, out iter);
		d_parents.prepend(iter);

		return item;
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

[GtkTemplate ( ui = "/org/gnome/gitg/ui/gitg-sidebar.ui" )]
public class Sidebar : Gtk.TreeView
{
	[GtkChild (name = "column")]
	private unowned Gtk.TreeViewColumn d_column;

	[GtkChild (name = "renderer_icon")]
	private unowned Gtk.CellRendererPixbuf d_renderer_icon;

	[GtkChild (name = "renderer_header")]
	private unowned Gtk.CellRendererText d_renderer_header;

	[GtkChild (name = "renderer_text")]
	private unowned Gtk.CellRendererText d_renderer_text;

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
				var context = get_style_context();

				context.save();
				context.set_state(Gtk.StateFlags.INSENSITIVE);
				var col = context.get_color(context.get_state());
				context.restore();

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

		sel.set_select_function(select_function);

		sel.changed.connect(selection_changed);
	}

	protected virtual bool select_function(Gtk.TreeSelection sel,
	                                       Gtk.TreeModel     model,
	                                       Gtk.TreePath      path,
	                                       bool              cursel)
	{
		Gtk.TreeIter iter;
		model.get_iter(out iter, path);

		uint hint;

		model.get(iter, SidebarColumn.HINT, out hint);

		return hint != SidebarHint.HEADER && hint != SidebarHint.DUMMY;
	}

	protected virtual void selection_changed(Gtk.TreeSelection sel)
	{
		Gtk.TreeIter iter;

		if (model.clearing)
		{
			return;
		}

		if (get_selected_iter(out iter))
		{
			SidebarHint hint;
			model.get(iter, SidebarColumn.HINT, out hint);

			if (hint != SidebarHint.HEADER && hint != SidebarHint.DUMMY)
			{
				model.activate(iter, 1);
			}
			else
			{
				deselected();
			}
		}
		else
		{
			deselected();
		}
	}

	protected bool get_selected_iter(out Gtk.TreeIter iter)
	{
		var sel = get_selection();

		if (sel.count_selected_rows() == 1)
		{
			Gtk.TreeModel m;

			var rows = sel.get_selected_rows(out m);
			m.get_iter(out iter, rows.data);

			return true;
		}
		else
		{
			iter = Gtk.TreeIter();
		}

		return false;
	}

	public T? get_selected_item<T>()
	{
		Gtk.TreeIter iter;

		if (get_selected_iter(out iter))
		{
			return (T)model.item_for_iter(iter);
		}

		return null;
	}

	public T[] get_selected_items<T>()
	{
		var sel = get_selection();

		Gtk.TreeModel m;
		Gtk.TreeIter iter;

		var rows = sel.get_selected_rows(out m);
		var ret = new T[0];

		foreach (var row in rows)
		{
			m.get_iter(out iter, row);
			ret += (T)model.item_for_iter(iter);
		}

		return ret;
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

	public bool is_selected(SidebarItem item)
	{
		bool retval = false;

		model.foreach((m, path, iter) => {
			if (model.item_for_iter(iter) == item)
			{
				retval = get_selection().iter_is_selected(iter);
				return true;
			}

			return false;
		});

		return retval;
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

	protected override bool key_press_event(Gdk.EventKey event)
	{
		if ((event.state & Gtk.accelerator_get_default_mod_mask()) != 0)
		{
			return base.key_press_event(event);
		}

		switch (event.keyval) {
			case Gdk.Key.Return:
			case Gdk.Key.ISO_Enter:
			case Gdk.Key.KP_Enter:
			case Gdk.Key.space:
			case Gdk.Key.KP_Space:
				Gtk.TreePath? path = null;
				Gtk.TreeIter iter;

				get_cursor(out path, null);

				var sel = get_selection();

				if (path != null)
				{
					if (model.get_iter(out iter, path))
					{
						if (sel.iter_is_selected(iter))
						{
							model.activate(iter, 2);
						}
						else
						{
							sel.unselect_all();
							sel.select_iter(iter);
						}
					}
				}

				return true;
		}

		return base.key_press_event(event);
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

		menu.popup_at_pointer(event);
		return true;
	}

	protected override bool button_press_event(Gdk.EventButton event)
	{
		Gdk.Event *ev = (Gdk.Event *)event;

		if (ev->triggers_context_menu())
		{
			if (get_selection().count_selected_rows() <= 1)
			{
				base.button_press_event(event);
			}

			return do_populate_popup(event);
		}
		else
		{
			return base.button_press_event(event);
		}
	}

	protected override bool popup_menu()
	{
		return do_populate_popup(null);
	}
}

}

// ex: ts=4 noet
