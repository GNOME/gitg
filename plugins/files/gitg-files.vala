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
	public class Panel : Object, GitgExt.UIElement, GitgExt.HistoryPanel
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }
		public GitgExt.History? history { owned get; construct set; }

		private TreeStore d_model;
		private Gtk.Paned d_paned;
		private Gtk.SourceView d_source;
		private Settings? d_fontsettings;
		private Settings? d_stylesettings;

		private Gtk.ScrolledWindow d_scrolled_files;
		private Gtk.ScrolledWindow d_scrolled;

		private Gtk.Viewport d_imagevp;
		private Gtk.Image d_image;

		private Gtk.CssProvider css_provider;
		private Gitg.WhenMapped d_whenMapped;

		construct
		{
			d_model = new TreeStore();

			history.selection_changed.connect(on_selection_changed);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Panels/Files"; }
		}

		public bool available
		{
			get { return true; }
		}

		public string display_name
		{
			owned get { return _("Files"); }
		}

		public string description
		{
			owned get { return _("Show the files in the tree of the selected commit"); }
		}

		public string? icon
		{
			owned get { return "system-file-manager-symbolic"; }
		}

		private void on_selection_changed(GitgExt.History history)
		{
			history.foreach_selected((commit) => {
				d_whenMapped.update(() => {
					d_model.tree = commit.get_tree();
				}, this);

				return false;
			});
		}

		private void update_font()
		{
			var fname = d_fontsettings.get_string("monospace-font-name");
			var font_desc = Pango.FontDescription.from_string(fname);
			var css = "textview { %s }".printf(Dazzle.pango_font_description_to_css(font_desc));
			try
			{
				css_provider.load_from_data(css);
			}
			catch(Error e)
			{
				warning("Error applying font. %s", e.message);
			}
		}

		private void update_style()
		{
			var scheme = d_stylesettings.get_string("style-scheme");
			var manager = Gtk.SourceStyleSchemeManager.get_default();
			var s = manager.get_scheme(scheme);

			if (s != null)
			{
				var buf = d_source.get_buffer() as Gtk.SourceBuffer;
				buf.set_style_scheme(s);
			}
		}

		private Settings? try_settings(string schema_id)
		{
			var source = SettingsSchemaSource.get_default();

			if (source == null)
			{
				return null;
			}

			if (source.lookup(schema_id, true) != null)
			{
				return new Settings(schema_id);
			}

			return null;
		}

		private void build_ui()
		{
			var ret = GitgExt.UI.from_builder("files/view-files.ui",
			                                  "paned_files",
			                                  "scrolled_window_files",
			                                  "tree_view_files",
			                                  "source_view_file",
			                                  "scrolled_window_file");

			var tv = ret["tree_view_files"] as Gtk.TreeView;
			tv.model = d_model;

			tv.get_selection().changed.connect(selection_changed);

			d_scrolled_files = ret["scrolled_window_files"] as Gtk.ScrolledWindow;
			d_source = ret["source_view_file"] as Gtk.SourceView;
			d_paned = ret["paned_files"] as Gtk.Paned;
			d_scrolled = ret["scrolled_window_file"] as Gtk.ScrolledWindow;

			css_provider = new Gtk.CssProvider();
			d_source.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS);
			d_imagevp = new Gtk.Viewport(null, null);
			d_image = new Gtk.Image();
			d_imagevp.add(d_image);
			d_imagevp.show_all();

			d_fontsettings = try_settings("org.gnome.desktop.interface");

			if (d_fontsettings != null)
			{
				d_fontsettings.changed["monospace-font-name"].connect((s, k) => {
					update_font();
				});

				update_font();
			}

			d_stylesettings = try_settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
			if (d_stylesettings != null)
			{
				d_stylesettings.changed["style-scheme"].connect((s, k) => {
					update_style();
				});

				update_style();
			} else {
				var buf = d_source.get_buffer() as Gtk.SourceBuffer;
				var style_scheme_manager = Gtk.SourceStyleSchemeManager.get_default();
				buf.style_scheme = style_scheme_manager.get_scheme("classic");
			}

			d_whenMapped = new Gitg.WhenMapped(d_paned);
			on_selection_changed(history);
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				if (d_paned == null)
				{
					build_ui();
				}

				return d_paned;
			}
		}

		private void set_viewer(Gtk.Widget? wid)
		{
			var child = d_scrolled.get_child();

			if (child != wid)
			{
				if (child != null)
				{
					d_scrolled.remove(d_scrolled.get_child());
				}

				if (wid != null)
				{
					d_scrolled.add(wid);
				}
			}
		}

		private void selection_changed(Gtk.TreeSelection selection)
		{
			Gtk.TreeModel mod;
			Gtk.TreeIter iter;

			var buf = d_source.get_buffer() as Gtk.SourceBuffer;
			buf.set_text("");

			if (!selection.get_selected(out mod, out iter) || d_model.get_isdir(iter))
			{
				set_viewer(d_source);
				return;
			}

			var id = d_model.get_id(iter);
			Ggit.Blob blob;

			try
			{
				blob = application.repository.lookup<Ggit.Blob>(id);
			}
			catch
			{
				set_viewer(d_source);
				return;
			}

			var fname = d_model.get_full_path(iter);
			unowned uint8[] content = blob.get_raw_content();

			var ct = ContentType.guess(fname, content, null);
			Gtk.Widget? wid = null;

			if (ContentType.is_a(ct, "image/*"))
			{
				wid = d_imagevp;
				var mtype = ContentType.get_mime_type(ct);

				d_image.pixbuf = null;

				try
				{
					var loader = new Gdk.PixbufLoader.with_mime_type(mtype);

					if (loader.write(content) && loader.close())
					{
						d_image.pixbuf = loader.get_pixbuf();
					}
				} catch {}
			}
			else if (ContentType.is_a(ct, "text/plain"))
			{
				var manager = Gtk.SourceLanguageManager.get_default();

				buf.set_text((string)content);
				buf.language = manager.guess_language(fname, ct);

				wid = d_source;
			}

			set_viewer(wid);
		}

		public bool enabled
		{
			get
			{
				// TODO
				return true;
			}
		}

		public int negotiate_order(GitgExt.UIElement other)
		{
			// Should appear after the diff
			if (other.id == "/org/gnome/gitg/Panels/Diff")
			{
				return 1;
			}
			else
			{
				return 0;
			}
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.HistoryPanel),
	                            typeof(GitgFiles.Panel));
}

// ex: ts=4 noet
