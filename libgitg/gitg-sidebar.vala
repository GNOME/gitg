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

public class SidebarRendererText : Gtk.CellRendererText
{
	private string d_icon_name;
	private Gdk.Pixbuf d_pixbuf;
	private Gtk.StateFlags d_state;

	public string? icon_name
	{
		get { return d_icon_name;}
		set
		{
			if (d_icon_name != value)
			{
				d_icon_name = value;
				reset_pixbuf();
			}
		}
	}

	public uint hint
	{
		get;
		set;
	}

	construct
	{
		ellipsize = Pango.EllipsizeMode.MIDDLE;
	}

	private void reset_pixbuf()
	{
		d_pixbuf = null;
	}

	private void ensure_pixbuf(Gtk.StyleContext ctx)
	{
		if (d_icon_name == null || (d_pixbuf != null && d_state == ctx.get_state()))
		{
			return;
		}

		d_pixbuf = null;

		d_state = ctx.get_state();

		var screen = ctx.get_screen();
		var settings = Gtk.Settings.get_for_screen(screen);

		int w = 16;
		int h = 16;

		Gtk.icon_size_lookup_for_settings(settings, Gtk.IconSize.MENU, out w, out h);

		var theme = Gtk.IconTheme.get_default();

		Gtk.IconInfo? info = theme.lookup_icon(d_icon_name,
		                                       int.min(w, h),
		                                       Gtk.IconLookupFlags.USE_BUILTIN);

		if (info == null)
		{
			return;
		}

		bool symbolic = false;

		try
		{
			d_pixbuf = info.load_symbolic_for_context(ctx, out symbolic);
		} catch {};

		if (d_pixbuf != null)
		{
			var source = new Gtk.IconSource();
			source.set_pixbuf(d_pixbuf);

			source.set_size(Gtk.IconSize.SMALL_TOOLBAR);
			source.set_size_wildcarded(false);

			d_pixbuf = ctx.render_icon_pixbuf(source, Gtk.IconSize.SMALL_TOOLBAR);
		}
	}

	protected override void get_preferred_width(Gtk.Widget widget,
	                                            out int    minimum_width,
	                                            out int    minimum_height)
	{
		ensure_pixbuf(widget.get_style_context());

		// Size of text
		base.get_preferred_width(widget, out minimum_width, out minimum_height);

		if (d_pixbuf != null)
		{
			minimum_width += d_pixbuf.get_width() + 3;
			minimum_height += d_pixbuf.get_height();
		}
	}

	protected override void get_preferred_height_for_width(Gtk.Widget widget,
	                                                       int        width,
	                                                       out int    minimum_height,
	                                                       out int    natural_height)
	{
		base.get_preferred_height_for_width(widget, width,
		                                    out minimum_height,
		                                    out natural_height);

		ensure_pixbuf(widget.get_style_context());

		if (d_pixbuf != null)
		{
			minimum_height = int.max(minimum_height, d_pixbuf.height);
			natural_height = int.max(natural_height, d_pixbuf.height);
		}
	}

	protected override void render(Cairo.Context         ctx,
	                               Gtk.Widget            widget,
	                               Gdk.Rectangle         background_area,
	                               Gdk.Rectangle         cell_area,
	                               Gtk.CellRendererState state)
	{
		var stx = widget.get_style_context();
		ensure_pixbuf(stx);

		if (d_pixbuf == null)
		{
			base.render(ctx, widget, background_area, cell_area, state);
		}
		else
		{
			// render the text with an additional padding
			Gdk.Rectangle area = cell_area;
			area.x += d_pixbuf.width + 3;

			base.render(ctx, widget, background_area, area, state);

			// render the pixbuf
			int yp = (cell_area.height - d_pixbuf.height) / 2;

			stx.render_icon(ctx, d_pixbuf, cell_area.x, cell_area.y + yp);
		}
	}
}

[GtkTemplate ( ui = "/org/gnome/gitg/gtk/sidebar/sidebar-view.ui" )]
public class Sidebar : Gtk.TreeView
{
	[GtkChild (name = "column")]
	private Gtk.TreeViewColumn d_column;

	[GtkChild (name = "renderer_header")]
	private SidebarRendererText d_renderer_header;

	[GtkChild (name = "renderer_text")]
	private SidebarRendererText d_renderer_text;

	public signal void deselected();

	construct
	{
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
