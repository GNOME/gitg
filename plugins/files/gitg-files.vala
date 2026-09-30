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
		private Settings? d_stylesettings;

		private Gtk.ScrolledWindow d_scrolled_files;
		private Gtk.ScrolledWindow d_scrolled;

		private Gtk.Viewport d_imagevp;
		private Gtk.Image d_image;

		private Gitg.WhenMapped d_whenMapped;
		private Gitg.FontManager d_font_manager;

		private Gtk.TreeView d_tree_view;
		private Gtk.Revealer d_revealer_options;
		private BlameRenderer? d_blame_renderer;
		private bool d_blame_active;
		private string? d_current_file_path;
		private string? d_pending_reselect_path;
		private ulong d_loaded_handler_id;
		private uint d_unreveal_options_timeout;

		construct
		{
			d_model = new TreeStore();

			history.selection_changed.connect(on_selection_changed);
			Hdy.StyleManager.get_default ().notify["dark"].connect (() => {
				Gitg.Utils.update_style_by_theme(d_stylesettings);
			});
		}

		public virtual uint? shortcut
		{
			owned get { return Gdk.Key.f; }
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
			d_pending_reselect_path = d_current_file_path;

			if (d_loaded_handler_id != 0)
			{
				d_model.disconnect(d_loaded_handler_id);
				d_loaded_handler_id = 0;
			}

			history.foreach_selected((commit) => {
				d_whenMapped.update(() => {
					d_model.tree = commit.get_tree();

					if (d_pending_reselect_path != null)
					{
						d_loaded_handler_id = d_model.loaded.connect(() => {
							var path = d_pending_reselect_path;
							d_pending_reselect_path = null;
							d_model.disconnect(d_loaded_handler_id);
							d_loaded_handler_id = 0;

							if (path != null)
							{
								select_file_by_path(path);
							}
						});
					}
				}, this);

				return false;
			});
		}

		private void select_file_by_path(string file_path)
		{
			var parts = file_path.split(Path.DIR_SEPARATOR_S);
			Gtk.TreeIter iter;
			Gtk.TreeIter? parent = null;

			for (var i = 0; i < parts.length; i++)
			{
				bool found = false;
				bool valid;

				if (parent == null)
				{
					valid = d_model.iter_children(out iter, null);
				}
				else
				{
					valid = d_model.iter_children(out iter, parent);
				}

				while (valid)
				{
					if (d_model.get_name(iter) == parts[i])
					{
						if (i < parts.length - 1)
						{
							var tree_path = d_model.get_path(iter);
							d_tree_view.expand_row(tree_path, false);
						}

						parent = iter;
						found = true;
						break;
					}
					valid = d_model.iter_next(ref iter);
				}

				if (!found)
				{
					return;
				}
			}

			if (parent != null)
			{
				var tree_path = d_model.get_path(parent);
				d_tree_view.get_selection().select_path(tree_path);
				d_tree_view.scroll_to_cell(tree_path, null, false, 0, 0);
			}
		}

		private void update_style()
		{
			Gitg.Utils.update_buffer_style(d_stylesettings, (Gtk.SourceBuffer)d_source.get_buffer());
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
			                                  "scrolled_window_file",
			                                  "check_button_blame",
			                                  "revealer_options");

			d_tree_view = ret["tree_view_files"] as Gtk.TreeView;
			var tv = d_tree_view;
			tv.model = d_model;

			tv.get_selection().changed.connect(selection_changed);
			tv.row_activated.connect(open_file_externally);
			tv.button_press_event.connect ((event) => {
					Gdk.Event *ev = (Gdk.Event *)(event);
					if (ev->triggers_context_menu()) {
							Gtk.TreePath path;

							tv.get_path_at_pos((int)event.x,
							                   (int)event.y,
							                   out path,
							                   null,
							                   null,
							                   null);
							tv.get_selection().select_path(path);

							Gtk.TreeIter citer;
							if (!d_model.get_iter(out citer, path) || d_model.get_isdir(citer))
							{
								return false;
							}

							Gtk.Menu menu = new Gtk.Menu ();

							Gtk.MenuItem open_item = new Gtk.MenuItem.with_label (_("Open externally"));
							open_item.activate.connect(()=> {
								open_file_externally(path, null);
							});
							menu.add (open_item);

							menu.attach_to_widget (tv, null);
							menu.show_all ();
							menu.popup_at_pointer (event);
							return true;
					}
					return false;
			});
			d_scrolled_files = ret["scrolled_window_files"] as Gtk.ScrolledWindow;
			d_source = ret["source_view_file"] as Gtk.SourceView;
			d_paned = ret["paned_files"] as Gtk.Paned;
			d_scrolled = ret["scrolled_window_file"] as Gtk.ScrolledWindow;

			var blame_check = ret["check_button_blame"] as Gtk.CheckButton;
			blame_check.toggled.connect(() => {
				d_blame_active = blame_check.active;
				if (d_blame_active && d_current_file_path != null)
				{
					load_blame(d_current_file_path);
				}
				else
				{
					clear_blame();
				}
			});

			d_revealer_options = ret["revealer_options"] as Gtk.Revealer;
			d_revealer_options.add_events(Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
			d_revealer_options.enter_notify_event.connect(() => {
				cancel_unreveal_timeout();
				return false;
			});
			d_revealer_options.leave_notify_event.connect(() => {
				if (d_revealer_options.reveal_child)
				{
					start_unreveal_timeout();
				}
				return false;
			});

			d_font_manager = new Gitg.FontManager(d_source, true);

			d_imagevp = new Gtk.Viewport(null, null);
			d_image = new Gtk.Image();
			d_imagevp.add(d_image);
			d_imagevp.show_all();

			d_stylesettings = try_settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
			if (d_stylesettings != null)
			{
				d_stylesettings.changed["style-scheme"].connect(update_style);

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

			clear_blame();

			if (!selection.get_selected(out mod, out iter) || d_model.get_isdir(iter))
			{
				d_current_file_path = null;
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
				d_current_file_path = null;
				set_viewer(d_source);
				return;
			}

			var fname = d_model.get_full_path(iter);
			d_current_file_path = fname;
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

				var len = content.length;
				unowned string raw = (string)content;
				string text;

				if (raw.validate(len))
				{
					text = raw.substring(0, len);
				}
				else
				{
					try
					{
						text = GLib.convert(raw, len, "UTF-8", "ISO-8859-1");
					}
					catch
					{
						text = raw.substring(0, len).make_valid();
					}
				}

				buf.set_text(text);
				buf.language = manager.guess_language(fname, ct);

				wid = d_source;

				if (d_blame_active)
				{
					load_blame(fname);
				}
			}

			set_viewer(wid);
		}

		private void load_blame(string path)
		{
			clear_blame();

			var repo = application.repository;
			var workdir = repo.get_workdir();

			if (workdir == null)
			{
				return;
			}

			var file = workdir.get_child(path);

			new Thread<void>("blame", () => {
				Ggit.Blame? blame = null;
				try
				{
					blame = repo.blame_file(file, null);
				}
				catch (Error e)
				{
					stderr.printf("Failed to load blame: %s\n", e.message);
				}

				Idle.add(() => {
					if (blame != null && d_blame_active && d_blame_renderer == null)
					{
						d_blame_renderer = new BlameRenderer();
						d_blame_renderer.commit_clicked.connect(on_blame_commit_clicked);

						var gutter = d_source.get_gutter(Gtk.TextWindowType.LEFT);
						gutter.insert(d_blame_renderer, 0);
						d_blame_renderer.set_blame(blame);
						d_source.queue_draw();
					}
					return false;
				});
			});
		}

		private void clear_blame()
		{
			if (d_blame_renderer != null)
			{
				var gutter = d_source.get_gutter(Gtk.TextWindowType.LEFT);
				gutter.remove(d_blame_renderer);
				d_blame_renderer = null;
			}
		}

		private void on_blame_commit_clicked(Ggit.OId oid)
		{
			Idle.add(() => {
				try
				{
					var commit = application.repository.lookup<Gitg.Commit>(oid);
					if (commit != null)
					{
						history.select(commit);
					}
				}
				catch (Error e)
				{
					stderr.printf("Failed to lookup commit: %s\n", e.message);
				}
				return false;
			});
		}

		private void open_file_externally(Gtk.TreePath path, Gtk.TreeViewColumn? column)
		{
			Gtk.TreeIter iter;
			bool path_is_valid = d_model.get_iter(out iter, path);

			if (!path_is_valid || d_model.get_isdir(iter))
				return;

			var id = d_model.get_id(iter);
			Ggit.Blob blob;

			try
			{
				blob = application.repository.lookup<Ggit.Blob>(id);
			}
			catch
			{
				return;
			}

			unowned uint8[] content = blob.get_raw_content();

			try {
				string filename = @"$(id.to_string())-$(d_model.get_name(iter))";

				string temp_dir = GLib.Environment.get_tmp_dir();
				string file_path = temp_dir + "/" + filename;

				File file = File.new_for_path(file_path);
				if (file.query_exists())
					file.delete();

				IOStream iostream = file.create_readwrite(FileCreateFlags.PRIVATE);
				OutputStream ostream = iostream.output_stream;
				try
				{
					ostream.write(content);
					ostream.flush();
					ostream.close();
				} catch (Error e) {
					stderr.printf("Could not write to temp file\n");
					return;
				}

				bool success = false;
				try
				{
					success = Gtk.show_uri_on_window((Gtk.Window)d_paned.get_toplevel(), file.get_uri(), Gdk.CURRENT_TIME);
				} catch (Error e) {
					stderr.printf("Failed to open application \n");
					return;
				}

				if (!success)
					stderr.printf("Failed to open application\n");
			} catch (Error e) {
				stderr.printf("Unable to create file\n");
				return;
			}
		}

		public bool enabled
		{
			get
			{
				// TODO
				return true;
			}
		}

		private void start_unreveal_timeout()
		{
			if (d_unreveal_options_timeout != 0)
			{
				Source.remove(d_unreveal_options_timeout);
			}

			d_unreveal_options_timeout = Timeout.add(3000, () => {
				d_unreveal_options_timeout = 0;
				d_revealer_options.reveal_child = false;
				return false;
			});
		}

		private void cancel_unreveal_timeout()
		{
			if (d_unreveal_options_timeout != 0)
			{
				Source.remove(d_unreveal_options_timeout);
				d_unreveal_options_timeout = 0;
			}
		}

		public override void toggle_options()
		{
			if (d_revealer_options != null)
			{
				d_revealer_options.reveal_child = !d_revealer_options.reveal_child;

				if (d_revealer_options.reveal_child)
				{
					start_unreveal_timeout();
				}
				else
				{
					cancel_unreveal_timeout();
				}
			}
		}

		public override void cancel_options_timeout()
		{
			if (d_revealer_options != null && d_revealer_options.reveal_child)
			{
				cancel_unreveal_timeout();
			}
		}

		public override void restart_options_timeout()
		{
			if (d_revealer_options != null && d_revealer_options.reveal_child)
			{
				start_unreveal_timeout();
			}
		}

		public override void navigate_to_file(string path)
		{
			if (d_paned == null)
			{
				build_ui();
			}

			Gtk.TreeIter iter;
			if (d_model.iter_children(out iter, null))
			{
				select_file_by_path(path);
			}
			else
			{
				d_pending_reselect_path = path;

				if (d_loaded_handler_id != 0)
				{
					d_model.disconnect(d_loaded_handler_id);
					d_loaded_handler_id = 0;
				}

				d_loaded_handler_id = d_model.loaded.connect(() => {
					var p = d_pending_reselect_path;
					d_pending_reselect_path = null;
					d_model.disconnect(d_loaded_handler_id);
					d_loaded_handler_id = 0;

					if (p != null)
					{
						select_file_by_path(p);
					}
				});
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
