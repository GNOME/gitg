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
	DEFAULT,
	SEPARATOR,
	DUMMY
}

public enum SidebarColumn
{
	ICON_NAME,
	NAME,
	TEXT,
	HEADER,
	HINT,
	SECTION,
	OID
}

public delegate void SidebarActivated(int numclick);

public class SidebarStore : Gtk.TreeStore
{
	private class Activated : Object
	{
		private SidebarActivated d_activated;

		public Activated(owned SidebarActivated? activated)
		{
			d_activated = (owned)activated;
		}

		public void activate(int numclick)
		{
			if (d_activated != null)
			{
				d_activated(numclick);
			}
		}
	}

	private Activated[] d_callbacks;
	private uint d_oid;
	private uint d_sections;
	private SList<Gtk.TreeIter?> d_parents;
	private bool d_clearing;

	construct
	{
		d_callbacks = new Activated[100];
		d_callbacks.length = 0;
	}

	private new void append(string                  text,
	                        string?                 name,
	                        string?                 icon_name,
	                        uint                    hint,
	                        owned SidebarActivated? callback,
	                        out Gtk.TreeIter        iter)
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
		     SidebarColumn.ICON_NAME, icon_name,
		     SidebarColumn.NAME, name,
		     hint == SidebarHint.HEADER ? SidebarColumn.HEADER : SidebarColumn.TEXT, text,
		     SidebarColumn.HINT, hint,
		     SidebarColumn.SECTION, d_sections,
		     SidebarColumn.OID, d_oid);

		d_callbacks += new Activated((owned)callback);
		++d_oid;
	}

	public SidebarStore append_dummy(string                  text,
	                                 string?                 name = null,
	                                 string?                 icon_name = null,
	                                 owned SidebarActivated? callback = null)
	{
		Gtk.TreeIter iter;
		append(text, name, icon_name, SidebarHint.DUMMY, (owned)callback, out iter);

		return this;
	}

	public SidebarStore append_normal(string                  text,
	                                  string?                 name = null,
	                                  string?                 icon_name = null,
	                                  owned SidebarActivated? callback = null)
	{
		Gtk.TreeIter iter;
		append(text, name, icon_name, SidebarHint.NONE, (owned)callback, out iter);

		return this;
	}

	public SidebarStore append_default(string                  text,
	                                   string?                 name = null,
	                                   string?                 icon_name = null,
	                                   owned SidebarActivated? callback = null)
	{
		Gtk.TreeIter iter;
		append(text, name, icon_name, SidebarHint.DEFAULT, (owned)callback, out iter);

		return this;
	}

	public SidebarStore begin_header(string  text,
	                                 string? icon_name = null)
	{
		Gtk.TreeIter iter;

		append(text, null, icon_name, SidebarHint.HEADER, null, out iter);
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

		d_oid = 0;
		d_sections = 0;
		d_callbacks.length = 0;
	}

	public void activate(Gtk.TreeIter iter, int numclick)
	{
		uint oid;

		@get(iter, SidebarColumn.OID, out oid);

		if (d_callbacks[oid] != null)
		{
			d_callbacks[oid].activate(numclick);
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

	construct
	{
		d_column.set_cell_data_func(d_renderer_icon, (layout, cell, model, iter) => {
			string? icon_name;
			model.get(iter, SidebarColumn.ICON_NAME, out icon_name);

			cell.visible = (icon_name != null);
		});

		d_column.set_cell_data_func(d_renderer_header, (layout, cell, model, iter) => {
			SidebarHint hint;
			model.get(iter, SidebarColumn.HINT, out hint);

			cell.visible = (hint == SidebarHint.HEADER);
		});

		d_column.set_cell_data_func(d_renderer_text, (layout, cell, model, iter) => {
			SidebarHint hint;
			model.get(iter, SidebarColumn.HINT, out hint);

			cell.visible = (hint != SidebarHint.HEADER);

			var r = (Gtk.CellRendererText)cell;

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
}

}

// ex: ts=4 noet
