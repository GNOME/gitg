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
	public class Panel : Object, GitgExt.UIElement, GitgExt.Panel
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }
		private GitgExt.ObjectSelection? d_view;

		private TreeStore d_model;
		private Gtk.Paned d_paned;
		private GtkSource.View d_source;
		private Settings d_fontsettings;
		private Settings d_stylesettings;

		construct
		{
			d_model = new TreeStore();
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Panels/Files"; }
		}

		public bool is_available()
		{
			var view = application.current_view;

			if (view == null)
			{
				return false;
			}

			return (view is GitgExt.ObjectSelection);
		}

		public string display_name
		{
			owned get { return _("Files"); }
		}

		public Icon? icon
		{
			owned get { return new ThemedIcon("system-file-manager-symbolic"); }
		}

		private void on_selection_changed(GitgExt.ObjectSelection selection)
		{
			selection.foreach_selected((commit) => {
				var c = commit as Ggit.Commit;

				if (c != null)
				{
					d_model.tree = c.get_tree();
					return false;
				}

				return true;
			});
		}

		private Gee.HashMap<string, Object>? from_builder(string path, string[] ids)
		{
			var builder = new Gtk.Builder();

			try
			{
				builder.add_from_resource("/org/gnome/gitg/files/" + path);
			}
			catch (Error e)
			{
				warning("Failed to load ui: %s", e.message);
				return null;
			}

			Gee.HashMap<string, Object> ret = new Gee.HashMap<string, Object>();

			foreach (string id in ids)
			{
				ret[id] = builder.get_object(id);
			}

			return ret;
		}

		private void update_font()
		{
			var fname = d_fontsettings.get_string("monospace-font-name");
			d_source.override_font(Pango.FontDescription.from_string(fname));
		}

		private void update_style()
		{
			var scheme = d_stylesettings.get_string("scheme");
			var manager = GtkSource.StyleSchemeManager.get_default();
			var s = manager.get_scheme(scheme);

			if (s != null)
			{
				var buf = d_source.get_buffer() as GtkSource.Buffer;
				buf.set_style_scheme(s);
			}
		}

		private void build_ui()
		{
			var ret = from_builder("view-files.ui", {"paned_files", "tree_view_files", "source_view_file"});

			var tv = ret["tree_view_files"] as Gtk.TreeView;
			tv.model = d_model;

			tv.get_selection().changed.connect(selection_changed);

			d_source = ret["source_view_file"] as GtkSource.View;
			d_paned = ret["paned_files"] as Gtk.Paned;

			d_fontsettings = new Settings("org.gnome.desktop.interface");

			if (d_fontsettings != null)
			{
				d_fontsettings.changed["monospace-font-name"].connect((s, k) => {
					update_font();
				});
			}

			d_stylesettings = new Settings("org.gnome.gedit.preferences.editor");

			if (d_stylesettings != null)
			{
				d_stylesettings.changed["scheme"].connect((s, k) => {
					update_style();
				});

				update_style();
			}

			update_font();
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				var objsel = (GitgExt.ObjectSelection)application.current_view;

				if (objsel != d_view)
				{
					if (d_view != null)
					{
						d_view.selection_changed.disconnect(on_selection_changed);
					}

					d_view = objsel;
					d_view.selection_changed.connect(on_selection_changed);

					on_selection_changed(objsel);
				}

				if (d_paned == null)
				{
					build_ui();
				}

				return d_paned;
			}
		}

		private void selection_changed(Gtk.TreeSelection selection)
		{
			Gtk.TreeModel mod;
			Gtk.TreeIter iter;

			selection.get_selected(out mod, out iter);

			var buf = d_source.get_buffer() as GtkSource.Buffer;
			buf.set_text("");

			if (d_model.get_isdir(iter))
			{
				return;
			}

			var id = d_model.get_id(iter);
			Ggit.Blob blob;

			try
			{
				blob = application.repository.lookup(id, typeof(Ggit.Blob)) as Ggit.Blob;
			} catch
			{
				return;
			}

			var fname = d_model.get_full_path(iter);
			unowned uint8[] content = blob.get_content();

			var ct = ContentType.guess(fname, content, null);

			if (ContentType.is_a(ct, "text/plain"))
			{
				var manager = GtkSource.LanguageManager.get_default();

				buf.set_text((string)content);
				buf.language = manager.guess_language(fname, ct);
			}
		}

		public bool is_enabled()
		{
			// TODO
			return true;
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.Panel),
	                            typeof(GitgFiles.Panel));
}

// ex: ts=4 noet
