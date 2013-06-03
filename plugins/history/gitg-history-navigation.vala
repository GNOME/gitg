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
	private enum Hint
	{
		NONE,
		HEADER,
		DEFAULT,
		SEPARATOR
	}

	private enum Column
	{
		ICON_NAME,
		NAME,
		TEXT,
		HEADER,
		HINT,
		SECTION,
		OID
	}

	public enum NavigationSide
	{
		LEFT = 0,
		TOP = 1
	}

	public delegate void NavigationActivated(int numclick);

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

	public class Navigation : Gtk.TreeStore
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		private List<Gitg.Ref> d_all;
		private uint d_oid;
		private SList<Gtk.TreeIter?> d_parents;
		private uint d_sections;
		private Activated[] d_callbacks;
		private Gitg.Repository? d_repository;
		private string? d_selected_head;
		private Gtk.TreeIter? d_selected_iter;

		public signal void ref_activated(Gitg.Ref? r);

		public Navigation(Gitg.Repository repo)
		{
			set_column_types({typeof(string),
			                  typeof(string),
			                  typeof(string),
			                  typeof(string),
			                  typeof(uint),
			                  typeof(uint),
			                  typeof(uint)
			});

			d_callbacks = new Activated[100];
			d_callbacks.length = 0;
			d_repository = repo;
			populate(d_repository);
		}

		[Notify]
		public Gitg.Repository repository
		{
			get { return d_repository; }
			set
			{
				d_repository = value;
			}
		}

		public Gtk.TreeIter? selected_iter
		{
			get { return d_selected_iter; }
			set { d_selected_iter = value; }
		}

		private static int sort_refs(Gitg.Ref a, Gitg.Ref b)
		{
			return a.parsed_name.shortname.ascii_casecmp(b.parsed_name.shortname);
		}

		private static int sort_remote_refs(Gitg.Ref a, Gitg.Ref b)
		{
			return a.parsed_name.remote_branch.ascii_casecmp(b.parsed_name.remote_branch);
		}

		private void populate(Gitg.Repository repo)
		{
			List<Gitg.Ref> branches = new List<Gitg.Ref>();
			List<Gitg.Ref> tags = new List<Gitg.Ref>();

			HashTable<string, Gee.LinkedList<Gitg.Ref>> remotes;
			List<string> remotenames = new List<string>();

			remotes = new HashTable<string, Gee.LinkedList<Gitg.Ref>>(str_hash, str_equal);
			d_all = new List<Gitg.Ref>();

			try
			{
				repo.references_foreach(Ggit.RefType.LISTALL, (nm) => {
					Gitg.Ref? r;

					try
					{
						r = repo.lookup_reference(nm);
					} catch { return 0; }

					d_all.prepend(r);

					if (r.parsed_name.rtype == Gitg.RefType.BRANCH)
					{
						branches.insert_sorted(r, sort_refs);
					}
					else if (r.parsed_name.rtype == Gitg.RefType.TAG)
					{
						tags.insert_sorted(r, sort_refs);
					}
					else if (r.parsed_name.rtype == Gitg.RefType.REMOTE)
					{
						Gee.LinkedList<Gitg.Ref> lst;

						string rname = r.parsed_name.remote_name;

						if (!remotes.lookup_extended(rname, null, out lst))
						{
							Gee.LinkedList<Gitg.Ref> nlst = new Gee.LinkedList<Gitg.Ref>();
							nlst.insert(0, r);

							remotes.insert(rname, nlst);
							remotenames.insert_sorted(rname, (a, b) => a.ascii_casecmp(b));
						}
						else
						{
							lst.insert(0, r);
						}
					}

					return 0;
				});
			} catch {}

			d_all.reverse();

			begin_section();

			if (CommandLine.all)
			{
				append_default(_("All commits"), null, null, (nc) => activate_ref(null));
			}
			else
			{
				append_normal(_("All commits"), null, null, (nc) => activate_ref(null));
			}

			// Branches
			begin_header(_("Branches"), null);

			foreach (var item in branches)
			{
				var branch = item as Ggit.Branch;
				string? icon = null;
				bool isdef = false;

				try
				{
					if (branch.is_head())
					{
						icon = "object-select-symbolic";

						if (!CommandLine.all)
						{
							isdef = true;
						}
					}
				}
				catch {}

				if (isdef)
				{
					append_default(item.parsed_name.shortname,
					               item.parsed_name.name,
					               icon,
					               (nc) => activate_ref(item));
				}
				else
				{
					append_normal(item.parsed_name.shortname,
					       item.parsed_name.name,
					       icon,
					       (nc) => activate_ref(item));
				}
			}

			end_header();

			// Remotes
			begin_header(_("Remotes"), null);

			foreach (var rname in remotenames)
			{
				begin_header(rname, null);

				var rrefs = remotes.lookup(rname);

				rrefs.sort((CompareDataFunc)sort_remote_refs);

				foreach (var rref in remotes.lookup(rname))
				{
					var it = rref;

					append_normal(rref.parsed_name.remote_branch,
					       rref.parsed_name.name,
					       null,
					       (nc) => activate_ref(it));
				}

				end_header();
			}

			end_header();

			// Tags
			begin_header(_("Tags"), null);

			foreach (var item in tags)
			{
				var it = item;

				append_normal(item.parsed_name.shortname,
				       item.parsed_name.name,
				       null,
				       (nc) => activate_ref(it));
			}

			end_header();

			end_section();
		}

		public List<Gitg.Ref> all
		{
			get { return d_all; }
		}

		public bool available
		{
			get { return true; }
		}

		public bool show_expanders
		{
			get { return false; }
		}

		public NavigationSide navigation_side
		{
			get { return NavigationSide.LEFT; }
		}

		private new void append(string text,
		                        string? name,
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
			     Column.NAME, name,
			     hint == Hint.HEADER ? Column.HEADER : Column.TEXT, text,
			     Column.HINT, hint,
			     Column.SECTION, d_sections,
			     Column.OID, d_oid);

			if (d_selected_head == name && name != null ||
			    d_selected_head == "--ALL REFS--" && text == _("All commits"))
			{
				d_selected_iter = iter;
			}

			d_callbacks += new Activated((owned)callback);
			++d_oid;
		}

		private Navigation append_normal(string text,
		                                 string? name,
		                                 string? icon_name,
		                                 owned NavigationActivated? callback)
		{
			Gtk.TreeIter iter;
			append(text, name, icon_name, Hint.NONE, (owned)callback, out iter);

			return this;
		}

		private Navigation append_default(string text,
		                                  string? name,
		                                  string? icon_name,
		                                  owned NavigationActivated? callback)
		{
			Gtk.TreeIter iter;
			append(text, name, icon_name, Hint.DEFAULT, (owned)callback, out iter);

			return this;
		}

		private Navigation append_separator()
		{
			Gtk.TreeIter iter;
			append("", null, null, Hint.SEPARATOR, null, out iter);

			return this;
		}

		private Navigation begin_header(string text,
		                                string? icon_name)
		{
			Gtk.TreeIter iter;

			append(text, null, icon_name, Hint.HEADER, null, out iter);
			d_parents.prepend(iter);

			return this;
		}

		private Navigation end_header()
		{
			if (d_parents != null)
			{
				d_parents.remove_link(d_parents);
			}

			return this;
		}

		private uint begin_section()
		{
			d_parents = null;
			return d_sections;
		}

		private void end_section()
		{
			++d_sections;
		}

		private void remove_section(uint section)
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

			d_oid = 0;
			d_sections = 0;
			d_callbacks.length = 0;
		}

		public void reload()
		{
			if (d_repository != null)
			{
				clear();
				populate(d_repository);
			}
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

		private void activate_ref(Gitg.Ref? r) {
			if (r != null)
			{
				d_selected_head = r.parsed_name.name;
			}
			else
			{
				d_selected_head = "--ALL REFS--";
			}
			ref_activated(r);
		}
	}

	public class NavigationView : Gtk.TreeView
	{
		private void build_ui()
		{
			var col = new Gtk.TreeViewColumn();

			var padcell = new Gtk.CellRendererText();
			var headercell = new NavigationRendererText();
			var cell = new NavigationRendererText();

			padcell.xpad = 6;
			headercell.ypad = 6;

			headercell.weight = Pango.Weight.BOLD;

			col.pack_start(padcell, false);
			col.pack_start(headercell, true);
			col.pack_start(cell, true);

			col.set_attributes(headercell,
			                   "icon_name", Column.ICON_NAME,
			                   "text", Column.HEADER);

			col.set_attributes(cell,
			                   "icon_name", Column.ICON_NAME,
			                   "text", Column.TEXT);

			col.set_cell_data_func(headercell, (layout, cell, model, iter) => {
				Hint hint;
				model.get(iter, Column.HINT, out hint);

				cell.visible = (hint == Hint.HEADER);
			});

			col.set_cell_data_func(cell, (layout, cell, model, iter) => {
				Hint hint;
				model.get(iter, Column.HINT, out hint);

				cell.visible = (hint != Hint.HEADER);
			});

			set_row_separator_func((model, iter) => {
				Hint hint;
				model.get(iter, Column.HINT, out hint);

				return hint == Hint.SEPARATOR;
			});

			append_column(col);

			get_selection().set_select_function((sel, model, path, cursel) => {
				Gtk.TreeIter iter;
				model.get_iter(out iter, path);

				uint hint;

				model.get(iter, Column.HINT, out hint);

				return hint != Hint.HEADER;
			});

			get_selection().changed.connect((sel) => {
				Gtk.TreeIter iter;

				if (sel.get_selected(null, out iter))
				{
					model.activate(iter, 1);
				}
			});

			set_show_expanders(model.show_expanders);
			if (model.show_expanders)
			{
				set_level_indentation(0);
			}
			else
			{
				set_level_indentation(12);
			}
		}

		public new Navigation model
		{
			get { return base.get_model() as Navigation; }
			set { base.set_model(value); build_ui(); }
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

		public void select()
		{
			if (model.selected_iter != null) {
				get_selection().select_iter(model.selected_iter);
				model.selected_iter = null;
			}
			else
			{
				select_first();
			}
		}

		protected override void row_activated(Gtk.TreePath path, Gtk.TreeViewColumn col)
		{
			Gtk.TreeIter iter;
			model.get_iter(out iter, path);
			model.activate(iter, 2);
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

		public uint hint
		{ get; set; }

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
}

// ex: ts=4 noet
