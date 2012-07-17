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

namespace GitgExt
{

private enum Column
{
	ICON_NAME,
	TEXT,
	HINT,
	SECTION,
	OID
}

private enum Hint
{
	NONE,
	HEADER,
	DEFAULT
}

public delegate void NavigationActivated(int numclick);

public class NavigationTreeModel : Gtk.TreeStore
{
	private class Activated : Object
	{
		private NavigationActivated d_activated;

		public Activated(owned NavigationActivated? activated)
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

	private SList<Gtk.TreeIter?> d_parents;
	private uint d_sections;
	private uint d_oid;
	private Activated[] d_callbacks;

	construct
	{
		set_column_types({typeof(string), typeof(string), typeof(uint), typeof(uint), typeof(uint)});

		d_callbacks = new Activated[100];
		d_callbacks.length = 0;
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

	private void append_one(string text,
	                        string? icon_name,
	                        uint hint,
	                        owned NavigationActivated? callback,
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
		     Column.ICON_NAME, icon_name,
		     Column.TEXT, text,
		     Column.HINT, hint,
		     Column.SECTION, d_sections,
		     Column.OID, d_oid);

		d_callbacks += new Activated((owned)callback);
		++d_oid;
	}

	public NavigationTreeModel begin_header(string text,
	                                        string? icon_name)
	{
		Gtk.TreeIter iter;

		append_one(text, icon_name, Hint.HEADER, null, out iter);
		d_parents.prepend(iter);

		return this;
	}

	public NavigationTreeModel end_header()
	{
		if (d_parents != null)
		{
			d_parents.remove_link(d_parents);
		}

		return this;
	}

	public new NavigationTreeModel append_default(string text,
	                                              string? icon_name,
	                                              owned NavigationActivated? callback)
	{
		Gtk.TreeIter iter;
		append_one(text, icon_name, Hint.DEFAULT, (owned)callback, out iter);

		return this;
	}

	public new NavigationTreeModel append(string text,
	                                      string? icon_name,
	                                      owned NavigationActivated? callback)
	{
		Gtk.TreeIter iter;
		append_one(text, icon_name, Hint.NONE, (owned)callback, out iter);

		return this;
	}

	public uint populate(GitgExt.Navigation? nav)
	{
		if (nav == null)
		{
			return 0;
		}

		uint ret = begin_section();

		nav.populate(this);

		end_section();
		return ret;
	}

	public void remove_section(uint section)
	{
		Gtk.TreeIter iter;

		if (!get_iter_first(out iter))
		{
			return;
		}

		while (true)
		{
			uint s;

			@get(iter, Column.SECTION, out s);

			if (s == section)
			{
				if (!base.remove(ref iter))
				{
					break;
				}
			}
			else
			{
				if (!iter_next(ref iter))
				{
					break;
				}
			}
		}
	}

	public new void clear()
	{
		base.clear();

		d_sections = 0;
		d_oid = 0;

		d_callbacks.length = 0;
	}

	public void activate(Gtk.TreeIter iter, int numclick)
	{
		uint oid;

		@get(iter, Column.OID, out oid);

		if (d_callbacks[oid] != null)
		{
			d_callbacks[oid].activate(numclick);
		}
	}
}

public class NavigationRendererText : Gtk.CellRendererText
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

	public uint hint { get; set; }

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

		Gtk.IconInfo? info = Gtk.IconTheme.get_default().lookup_icon(d_icon_name,
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
	                                            out int minimum_width,
	                                            out int minimum_height)
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
	                                                       int width,
	                                                       out int minimum_height,
	                                                       out int natural_height)
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

	protected override void render(Cairo.Context ctx,
	                               Gtk.Widget widget,
	                               Gdk.Rectangle background_area,
	                               Gdk.Rectangle cell_area,
	                               Gtk.CellRendererState state)
	{
		var stx = widget.get_style_context();
		ensure_pixbuf(stx);

		int xpad = 3;

		if (hint != Hint.HEADER)
		{
			cell_area.x -= 15;
		}

		if (d_pixbuf == null)
		{
			base.render(ctx, widget, background_area, cell_area, state);
		}
		else
		{
			// render the text with an additional padding
			Gdk.Rectangle area = cell_area;
			area.x += d_pixbuf.width + xpad;

			base.render(ctx, widget, background_area, area, state);

			// render the pixbuf
			int ypad = (cell_area.height - d_pixbuf.height) / 2;

			stx.render_icon(ctx, d_pixbuf, cell_area.x, cell_area.y + ypad);
		}
	}
}

public class NavigationTreeView : Gtk.TreeView
{
	private Gdk.RGBA d_header_bg;
	private Gdk.RGBA d_header_fg;

	construct
	{
		var model = new NavigationTreeModel();
		set_model(model);

		var cell = new NavigationRendererText();
		var col = new Gtk.TreeViewColumn.with_attributes("text",
		                                                  cell,
		                                                  "icon_name", Column.ICON_NAME,
		                                                  "text", Column.TEXT,
		                                                  "hint", Column.HINT);

		col.set_cell_data_func(cell, (col, cell, model, iter) => {
			uint hint;

			model.get(iter, Column.HINT, out hint);

			Gtk.CellRendererText t = cell as Gtk.CellRendererText;

			if (hint == Hint.HEADER && (model as Gtk.TreeStore).iter_depth(iter) == 0)
			{
				t.background_rgba = d_header_bg;
				t.foreground_rgba = d_header_fg;
			}
			else
			{
				t.background_set = false;
				t.foreground_set = false;
			}

			if (hint == Hint.HEADER)
			{
				t.weight = Pango.Weight.BOLD;
			}
			else
			{
				t.weight = Pango.Weight.NORMAL;
			}
		});

		append_column(col);

		get_selection().set_select_function((sel, model, path, cursel) => {
			Gtk.TreeIter iter;
			model.get_iter(out iter, path);

			uint hint;

			model.get(iter, Column.HINT, out hint);

			return hint != Hint.HEADER;
		});

		update_header_colors();

		get_selection().changed.connect((sel) => {
			Gtk.TreeIter iter;

			if (sel.get_selected(null, out iter))
			{
				model.activate(iter, 1);
			}
		});
	}

	protected override void style_updated()
	{
		base.style_updated();
		update_header_colors();
	}

	private void update_header_colors()
	{
		get_style_context().lookup_color("insensitive_bg_color", out d_header_bg);
		get_style_context().lookup_color("insensitive_fg_color", out d_header_fg);
	}

	public new NavigationTreeModel model
	{
		get { return base.get_model() as NavigationTreeModel; }
	}

	private bool select_first_in(Gtk.TreeIter? parent, bool seldef)
	{
		Gtk.TreeIter iter;

		if (!model.iter_children(out iter, parent))
		{
			return false;
		}

		while (true)
		{
			uint hint;
			model.get(iter, Column.HINT, out hint);

			if (hint == Hint.HEADER)
			{
				if (select_first_in(iter, seldef))
				{
					return true;
				}
			}

			if (!seldef || hint == Hint.DEFAULT)
			{
				get_selection().select_iter(iter);

				return true;
			}

			if (!model.iter_next(ref iter))
			{
				return false;
			}
		}
	}

	public void select_first()
	{
		select_first_in(null, true) || select_first_in(null, false);
	}

	protected override void row_activated(Gtk.TreePath path, Gtk.TreeViewColumn col)
	{
		Gtk.TreeIter iter;

		model.get_iter(out iter, path);
		model.activate(iter, 2);
	}
}

}

// ex:set ts=4 noet:
