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

namespace Gitg
{
	public class DashView : Gtk.ListBox
	{
		private static Gtk.IconSize d_icon_size;
		private string? d_filter_text;

		[GtkTemplate (ui = "/org/gnome/gitg/gtk/dash-view/gitg-dash-view-row.ui")]
		private class DashRow : Gtk.ListBoxRow
		{
			private Repository? d_repository;
			private DateTime d_time;
			private bool d_loading;
			[GtkChild]
			private ProgressBin d_progress_bin;
			[GtkChild]
			private Gtk.Image d_image;
			[GtkChild]
			private Gtk.Label d_repository_label;
			[GtkChild]
			private Gtk.Label d_branch_label;
			[GtkChild]
			private Gtk.Arrow d_arrow;
			[GtkChild]
			private Gtk.Spinner d_spinner;

			public Repository? repository
			{
				get { return d_repository; }
				set
				{
					d_repository = value;

					branch_name = "";
					if (d_repository != null)
					{
						try
						{
							var head = d_repository.get_head();
							branch_name = head.parsed_name.shortname;
						}
						catch {}
					}
				}
			}

			public DateTime time
			{
				get { return d_time; }
				set { d_time = value; }
			}

			public double fraction
			{
				set { d_progress_bin.fraction = value; }
			}

			public string? repository_name
			{
				get { return d_repository_label.get_text(); }
				set { d_repository_label.set_markup("<b>%s</b>".printf(value)); }
			}

			public string? branch_name
			{
				get { return d_branch_label.get_text(); }
				set { d_branch_label.set_markup("<small>%s</small>".printf(value)); }
			}

			public bool loading
			{
				get { return d_loading; }
				set
				{
					d_loading = value;

					if (d_loading)
					{
						d_spinner.stop();
						d_spinner.hide();
						d_arrow.show();
						d_progress_bin.fraction = 0;
					}
					else
					{
						d_arrow.hide();
						d_spinner.show();
						d_spinner.start();
					}
				}
			}

			public DashRow(string name, string branch_name, bool local)
			{
				d_time = new DateTime.now_local();
				repository_name = name;

				// FIXME: Change folder image for a repository uses github remote.
				var folder_icon_name = local ? "folder" : "folder-remote";
				d_image.set_from_icon_name(folder_icon_name, d_icon_size);
				d_branch_label.set_markup("<small>%s</small>".printf(branch_name));
			}
		}

		public signal void repository_activated(Repository repository);

		protected override void row_activated(Gtk.ListBoxRow row)
		{
			var r = row as DashRow;

			if (r.repository != null)
			{
				repository_activated(r.repository);
			}
		}

		construct
		{
			d_icon_size = Gtk.icon_size_register ("gitg", 64, 64);

			set_header_func(update_header);
			set_filter_func(null);
			set_sort_func(compare_widgets);
			show();

			set_selection_mode (Gtk.SelectionMode.NONE);

			add_recent_info();
		}

		private void update_header(Gtk.ListBoxRow row, Gtk.ListBoxRow? before)
		{
			row.set_header(before != null ? new Gtk.Separator(Gtk.Orientation.HORIZONTAL) : null);
		}

		private bool filter(Gtk.ListBoxRow row)
		{
			return (row as DashRow).repository_name.contains(d_filter_text);
		}

		private int compare_widgets(Gtk.ListBoxRow a, Gtk.ListBoxRow b)
		{
			return - (a as DashRow).time.compare((b as DashRow).time);
		}

		private void add_recent_info()
		{
			var recent_manager = Gtk.RecentManager.get_default();
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

					Repository repo;

					try
					{
						repo = new Repository(repo_file, null);
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

		private DashRow get_row_for_repository(Repository repository)
		{
			DashRow? row = null;

			foreach (var child in get_children())
			{
				var d = child as DashRow;
				if (d.repository.get_location().equal(repository.get_location()))
				{
					row = d;
					break;
				}
			}

			return row;
		}

		private void add_repository_to_recent_manager(string uri)
		{
			var recent_manager = Gtk.RecentManager.get_default();
			var item = Gtk.RecentData();
			item.app_name = Environment.get_application_name();
			item.mime_type = "inode/directory";
			item.app_exec = string.join(" ", Environment.get_prgname(), "%f");
			item.groups = { "gitg", null };
			recent_manager.add_full(uri, item);
		}

		public void add_repository(Repository repository)
		{
			DashRow? row = get_row_for_repository(repository);

			if (row == null)
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

				row = new DashRow(repository.name, head_name, local);
				row.repository = repository;
				row.show();
				add(row);
			}
			else
			{
				// to get the item sorted to the beginning of the list
				row.time = new DateTime.now_local();
				invalidate_filter();
			}

			var f = repository.workdir != null ? repository.workdir : repository.location;
			if (f != null)
			{
				add_repository_to_recent_manager(f.get_uri());
			}
		}

		private async Repository? clone(DashRow row, string url, File location, bool is_bare)
		{
			SourceFunc callback = clone.callback;
			Repository? repository = null;

			ThreadFunc<void*> run = () => {
				try
				{
					var options = new Ggit.CloneOptions();
					options.set_is_bare(is_bare);
					options.set_fetch_progress_callback((stats) => {
						row.fraction = (stats.get_received_objects() + stats.get_indexed_objects()) / (double)(2 * stats.get_total_objects());
						return 0;
					});

					repository = Ggit.Repository.clone(url, location, options) as Repository;
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
			DashRow row = new DashRow(subfolder_name, "Cloning...", false);
			row.loading = true;
			row.show();
			add(row);

			clone.begin(row, url, subfolder, is_bare, (obj, res) => {
				Gitg.Repository? repository = clone.end(res);

				// FIXME: show an error
				if (repository != null)
				{
					File? workdir = repository.get_workdir();
					File? repo_file = repository.get_location();
					var uri = (workdir != null) ? workdir.get_uri() : repo_file.get_uri();
					add_repository_to_recent_manager(uri);
				}

				row.repository = repository;
				row.loading = false;
			});
		}

		public void filter_text(string? text)
		{
			d_filter_text = text;

			if (text != null && text != "")
			{
				set_filter_func(filter);
			}
			else
			{
				set_filter_func(null);
			}
		}
	}
}

// ex:ts=4 noet
