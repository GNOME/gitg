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

namespace GitgDash
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public class View : Object
	{
		public GitgExt.Application? application { owned get; construct set; }
		private Gtk.Notebook d_main;

		private Gtk.Widget? d_open;
		private int d_openidx;

		private Gtk.Widget? d_create;
		private int d_createidx;

		private Gtk.Widget? d_recent;
		private Gtk.Label? d_recent_path;
		private Gtk.Label? d_recent_last_used;
		private Gtk.Label? d_recent_current_branch;
		private File? d_recent_current_file;
		private int d_recentidx;

		private HashTable<File, Gitg.Repository> d_repos;

		private File? d_open_folder;

		construct
		{
			d_main = new Gtk.Notebook();
			d_main.set_show_tabs(false);
			d_main.show();

			d_repos = new HashTable<File, Gitg.Repository>(File.hash, File.equal);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Views/Dash"; }
		}

		public bool is_available()
		{
			// The dash is always available
			return true;
		}

		public string display_name
		{
			owned get { return "Dashboard"; }
		}

		public Icon? icon
		{
			owned get
			{
				return new ThemedIcon("document-open-recent-symbolic");
			}
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				return d_main;
			}
		}

		public GitgExt.Navigation? navigation
		{
			owned get
			{
				var ret = new Navigation(application);

				ret.show_open.connect(show_open);
				ret.show_create.connect(show_create);
				ret.show_recent.connect(show_recent);
				ret.activate_recent.connect(activate_recent);

				return ret;
			}
		}

		public bool is_default_for(GitgExt.ViewAction action)
		{
			return application.repository == null;
		}

		private Gee.HashMap<string, Object>? from_builder(string path, string[] ids)
		{
			var builder = new Gtk.Builder();

			try
			{
				builder.add_from_resource("/org/gnome/gitg/dash/" + path);
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

		private void connect_chooser_folder(Gtk.FileChooser ch)
		{
			if (d_open_folder == null)
			{
				var path = Environment.get_home_dir();
				d_open_folder = File.new_for_path(path);
			}

			ch.unmap.connect((w) => {
				d_open_folder = ch.get_current_folder_file();
			});

			ch.map.connect((w) => {
				if (d_open_folder != null)
				{
					try
					{
						ch.set_current_folder_file(d_open_folder);
					} catch {};
				}
			});
		}

		public void show_open()
		{
			if (d_open == null)
			{
				var ret = from_builder("view-open.ui", {"view",
				                                        "file_chooser",
				                                        "button_open"});

				d_open = ret["view"] as Gtk.Widget;

				var ch = ret["file_chooser"] as Gtk.FileChooser;
				connect_chooser_folder(ch);

				(ret["button_open"] as Gtk.Button).clicked.connect((b) => {
					application.open(ch.get_current_folder_file());
				});

				d_openidx = d_main.append_page(d_open, null);
			}

			d_main.set_current_page(d_openidx);
		}

		public void show_create()
		{
			if (d_create == null)
			{
				var ret = from_builder("view-create.ui", {"view",
				                                          "file_chooser",
				                                          "button_create"});

				d_create = ret["view"] as Gtk.Widget;

				var ch = ret["file_chooser"] as Gtk.FileChooser;
				connect_chooser_folder(ch);

				(ret["button_create"] as Gtk.Button).clicked.connect((b) => {
					application.create(ch.get_current_folder_file());
				});

				d_createidx = d_main.append_page(d_create, null);
			}

			d_main.set_current_page(d_createidx);
		}

		public void show_recent(string uri)
		{
			var manager = Gtk.RecentManager.get_default();
			Gtk.RecentInfo? info = null;

			foreach (var item in manager.get_items())
			{
				if (item.get_uri() == uri &&
				    item.has_application("gitg") && item.exists())
				{
					info = item;
					break;
				}
			}

			if (info == null)
			{
				return;
			}

			File f = File.new_for_uri(info.get_uri());
			Gitg.Repository? repo;

			if (!d_repos.lookup_extended(f, null, out repo))
			{
				// Try to open the repo
				try
				{
					repo = new Gitg.Repository(f, null);

					d_repos.insert(f, repo);
				}
				catch
				{
					return;
				}
			}

			if (repo == null)
			{
				return;
			}

			if (d_recent == null)
			{
				var ret = from_builder("view-recent.ui", {"view",
				                                          "label_path_i",
				                                          "label_last_used_i",
				                                          "label_current_branch_i",
				                                          "button_open"});

				d_recent = ret["view"] as Gtk.Widget;
				d_recent_path = ret["label_path_i"] as Gtk.Label;
				d_recent_last_used = ret["label_last_used_i"] as Gtk.Label;
				d_recent_current_branch = ret["label_current_branch_i"] as Gtk.Label;

				(ret["button_open"] as Gtk.Button).clicked.connect((b) => {
					application.open(d_recent_current_file);
				});

				d_recentidx = d_main.append_page(d_recent, null);
			}

			d_recent_path.label = Filename.display_name(f.get_path());
			d_recent_current_file = f;

			var dt = new DateTime.from_unix_utc(info.get_visited());
			d_recent_last_used.label = dt.format("%c");

			d_recent_current_branch.label = _("(no branch)");

			try
			{
				var r = repo.get_head();

				if (r != null)
				{
					d_recent_current_branch.label = r.parsed_name.shortname;
				}
			}
			catch {}

			d_main.set_current_page(d_recentidx);
		}

		public void activate_recent(string uri)
		{
			File f = File.new_for_uri(uri);

			application.open(f);
		}

		public bool is_enabled()
		{
			return true;
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	//mod.register_extension_type(typeof(GitgExt.View),
	//                            typeof(GitgDash.View));
}

// ex: ts=4 noet
