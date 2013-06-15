/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Ignacio Casal Quinteiro
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

using Gitg;
using Gtk;

namespace GitgGtk
{
	public class DashView : Grid
	{
		private static Gtk.IconSize d_icon_size;
		private string? d_filter_text;
		private Egg.ListBox d_listbox;
		private class RepositoryData
		{
			public Repository? repository;
			public DateTime time;
			public ProgressBin bin;
			public Image image;
			public Label repository_label;
			public Label branch_label;
			public Arrow arrow;
			public Spinner spinner;
		}

		public signal void repository_activated(Repository repository);

		construct
		{
			d_icon_size = Gtk.icon_size_register ("gitg", 64, 64);

			d_listbox = new Egg.ListBox();
			var context = d_listbox.get_style_context();
			context.add_class("view");
			context.add_class("content-view");
			d_listbox.set_separator_funcs(update_separator);
			d_listbox.set_filter_func(null);
			d_listbox.set_sort_func(compare_widgets);
			d_listbox.show();
			add(d_listbox);

			d_listbox.set_selection_mode (Gtk.SelectionMode.NONE);

			d_listbox.child_activated.connect((listbox, child) => {
				var data = child.get_data<RepositoryData>("data");

				if (data != null && data.repository != null)
				{
					repository_activated(data.repository);
				}
			});

			add_recent_info();
		}

		private void update_separator(ref Widget? separator, Widget widget, Widget? before_widget)
		{
			if (before_widget != null)
			{
				separator = new Separator(Orientation.HORIZONTAL);
			}
			else
			{
				separator = null;
			}
		}

		private bool filter(Widget widget)
		{
			var data = widget.get_data<RepositoryData>("data");
			var text = data.repository_label.get_text();
			return text.contains(d_filter_text);
		}

		private int compare_widgets(Widget a, Widget b)
		{
			var data_a = a.get_data<RepositoryData>("data");
			var data_b = b.get_data<RepositoryData>("data");
			return - data_a.time.compare(data_b.time);
		}

		private void add_recent_info()
		{
			var recent_manager = RecentManager.get_default();
			var reversed_items = recent_manager.get_items();
			reversed_items.reverse();

			foreach (var item in reversed_items)
			{
				if (item.has_group("gitg"))
				{
					File info_file = File.new_for_uri(item.get_uri());
					File repo_file;

					try
					{
						repo_file = Ggit.Repository.discover(info_file);
					}
					catch
					{
						try
						{
							recent_manager.remove_item(item.get_uri());
						}
						catch {}
						return;
					}

					Gitg.Repository repo;

					try
					{
						repo = new Gitg.Repository(repo_file, null);
					}
					catch
					{
						try
						{
							recent_manager.remove_item(item.get_uri());
						}
						catch {}
						return;
					}

					add_repository(repo);
				}
			}
		}

		private RepositoryData get_data_for_repository(Gitg.Repository repository)
		{
			RepositoryData? data = null;

			foreach (var child in d_listbox.get_children())
			{
				var d = child.get_data<RepositoryData>("data");
				if (d.repository.get_location().equal(repository.get_location()))
				{
					data = d;
					break;
				}
			}

			return data;
		}

		private RepositoryData create_repository_data(string name, string branch_name, bool spin, bool local)
		{
			var data = new RepositoryData();
			data.repository = null;
			data.time = new DateTime.now_local();
			data.bin = new ProgressBin();
			var grid = new Grid();
			grid.margin = 12;
			grid.column_spacing = 10;
			data.bin.add(grid);

			// FIXME: Change folder image for a repository uses github remote.
			var folder_icon_name = local ? "folder" : "folder-remote";
			data.image = new Image.from_icon_name(folder_icon_name, d_icon_size);
			grid.attach(data.image, 0, 0, 1, 2);

			data.repository_label = new Label(null);
			data.repository_label.set_markup("<b>%s</b>".printf(name));
			data.repository_label.ellipsize = Pango.EllipsizeMode.END;
			data.repository_label.halign = Align.START;
			data.repository_label.valign = Align.END;
			data.repository_label.hexpand = true;
			grid.attach(data.repository_label, 1, 0, 1, 1);

			data.branch_label = new Label("");
			data.branch_label.set_markup("<small>%s</small>".printf(branch_name));
			data.branch_label.ellipsize = Pango.EllipsizeMode.END;
			data.branch_label.valign = Align.START;
			data.branch_label.halign = Align.START;
			data.branch_label.get_style_context().add_class("dim-label");
			grid.attach(data.branch_label, 1, 1, 1, 1);

			data.arrow = new Arrow(ArrowType.RIGHT, ShadowType.NONE);
			grid.attach(data.arrow, 2, 0, 1, 2);

			data.bin.set_data<RepositoryData>("data", data);
			data.bin.show_all();
			d_listbox.add(data.bin);

			if (spin)
			{
				data.arrow.hide();
				data.spinner = new Spinner();
				grid.attach(data.spinner, 3, 0, 1, 2);
				data.spinner.show();
				data.spinner.start();
			}

			return data;
		}

		private void add_repository_to_recent_manager(string uri)
		{
			var recent_manager = RecentManager.get_default();
			var item = RecentData();
			item.app_name = Environment.get_application_name();
			item.mime_type = "inode/directory";
			item.app_exec = string.join(" ", Environment.get_prgname(), "%f");
			item.groups = { "gitg", null };
			recent_manager.add_full(uri, item);
		}

		public void add_repository(Gitg.Repository repository)
		{
			RepositoryData? data = get_data_for_repository(repository);

			if (data == null)
			{
				string head_name = "";
				bool local = false;

				try
				{
					var head = repository.get_head();
					head_name = head.parsed_name.shortname;
					var remotes = repository.list_remotes();
					if (remotes.length == 0)
					{
						local = true;
					}
				}
				catch {}

				data = create_repository_data(repository.name, head_name, false, local);
				data.repository = repository;
			}
			else
			{
				// to get the item sorted to the beginning of the list
				data.time = new DateTime.now_local();
				d_listbox.resort();
			}

			var f = repository.workdir != null ? repository.workdir : repository.location;
			if (f != null)
			{
				add_repository_to_recent_manager(f.get_uri());
			}
		}

		private async Gitg.Repository? clone(RepositoryData data, string url, File location, bool is_bare)
		{
			SourceFunc callback = clone.callback;
			Gitg.Repository? repository = null;

			ThreadFunc<void*> run = () => {
				try
				{
					var options = new Ggit.CloneOptions();
					options.set_is_bare(is_bare);
					options.set_fetch_progress_callback((stats) => {
						data.bin.fraction = (stats.get_received_objects() + stats.get_indexed_objects()) / (double)(2 * stats.get_total_objects());
						return 0;
					});

					repository = Ggit.Repository.clone(url, location, options) as Gitg.Repository;
				}
				catch (Ggit.Error e)
				{
					warning("error cloning: %s", e.message);
				}
				catch (GLib.Error e)
				{
					warning("error cloning: %s", e.message);
				}

				Idle.add((owned) callback);
				return null;
			};

			try
			{
				new Thread<void*>.try("gitg-clone-thread", (owned)run);
				yield;
			}
			catch {}

			return repository;
		}

		public void clone_repository(string url, File location, bool is_bare)
		{
			// create subfolder
			var subfolder_name = url.substring(url.last_index_of_char('/') + 1);
			if (subfolder_name.has_suffix(".git") && !is_bare)
			{
				subfolder_name = subfolder_name.slice(0, - ".git".length);
			}
			else if (is_bare)
			{
				subfolder_name += ".git";
			}

			var subfolder = location.resolve_relative_path(subfolder_name);

			try
			{
				subfolder.make_directory_with_parents(null);
			}
			catch (GLib.Error e)
			{
				warning("error creating subfolder: %s", e.message);
				return;
			}

			// Clone
			RepositoryData? data = create_repository_data(subfolder_name, "Cloning...", true, false);

			clone.begin(data, url, subfolder, is_bare, (obj, res) => {
				Gitg.Repository? repository = clone.end(res);
				string branch_name = "";

				// FIXME: show an error
				if (repository != null)
				{
					File? workdir = repository.get_workdir();
					File? repo_file = repository.get_location();
					var uri = (workdir != null) ? workdir.get_uri() : repo_file.get_uri();
					add_repository_to_recent_manager(uri);

					try
					{
						var head = repository.get_head();
						branch_name = head.parsed_name.shortname;
					}
					catch {}
				}

				data.repository = repository;
				data.branch_label.set_markup("<small>%s</small>".printf(branch_name));
				data.spinner.stop();
				data.spinner.hide();
				data.arrow.show();
				data.bin.fraction = 0;
			});
		}

		public void filter_text(string? text)
		{
			d_filter_text = text;

			if (text != null && text != "")
			{
				d_listbox.set_filter_func(filter);
			}
			else
			{
				d_listbox.set_filter_func(null);
			}
		}
	}
}

// ex:ts=4 noet
