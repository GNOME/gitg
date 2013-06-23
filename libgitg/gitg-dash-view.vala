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

namespace Gitg
{
	public class DashView : ListBox
	{
		private static Gtk.IconSize d_icon_size;
		private string? d_filter_text;

		private class DashRow : ListBoxRow
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

		protected override void row_activated(ListBoxRow row)
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

		private void update_header(ListBoxRow row, ListBoxRow? before)
		{
			row.set_header(before != null ? new Separator(Orientation.HORIZONTAL) : null);
		}

		private bool filter(ListBoxRow row)
		{
			var text = (row as DashRow).repository_label.get_text();
			return text.contains(d_filter_text);
		}

		private int compare_widgets(ListBoxRow a, ListBoxRow b)
		{
			return - (a as DashRow).time.compare((b as DashRow).time);
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

		private DashRow get_row_for_repository(Gitg.Repository repository)
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

		private DashRow create_repository_row(string name, string branch_name, bool spin, bool local)
		{
			var row = new DashRow();
			row.repository = null;
			row.time = new DateTime.now_local();
			row.bin = new ProgressBin();
			row.add(row.bin);
			var grid = new Grid();
			grid.margin = 12;
			grid.column_spacing = 10;
			row.bin.add(grid);

			// FIXME: Change folder image for a repository uses github remote.
			var folder_icon_name = local ? "folder" : "folder-remote";
			row.image = new Image.from_icon_name(folder_icon_name, d_icon_size);
			grid.attach(row.image, 0, 0, 1, 2);

			row.repository_label = new Label(null);
			row.repository_label.set_markup("<b>%s</b>".printf(name));
			row.repository_label.ellipsize = Pango.EllipsizeMode.END;
			row.repository_label.halign = Align.START;
			row.repository_label.valign = Align.END;
			row.repository_label.hexpand = true;
			grid.attach(row.repository_label, 1, 0, 1, 1);

			row.branch_label = new Label("");
			row.branch_label.set_markup("<small>%s</small>".printf(branch_name));
			row.branch_label.ellipsize = Pango.EllipsizeMode.END;
			row.branch_label.valign = Align.START;
			row.branch_label.halign = Align.START;
			row.branch_label.get_style_context().add_class("dim-label");
			grid.attach(row.branch_label, 1, 1, 1, 1);

			row.arrow = new Arrow(ArrowType.RIGHT, ShadowType.NONE);
			grid.attach(row.arrow, 2, 0, 1, 2);

			row.show_all();
			add(row);

			if (spin)
			{
				row.arrow.hide();
				row.spinner = new Spinner();
				grid.attach(row.spinner, 3, 0, 1, 2);
				row.spinner.show();
				row.spinner.start();
			}

			return row;
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

				row = create_repository_row(repository.name, head_name, false, local);
				row.repository = repository;
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

		private async Gitg.Repository? clone(DashRow row, string url, File location, bool is_bare)
		{
			SourceFunc callback = clone.callback;
			Gitg.Repository? repository = null;

			ThreadFunc<void*> run = () => {
				try
				{
					var options = new Ggit.CloneOptions();
					options.set_is_bare(is_bare);
					options.set_fetch_progress_callback((stats) => {
						row.bin.fraction = (stats.get_received_objects() + stats.get_indexed_objects()) / (double)(2 * stats.get_total_objects());
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
			DashRow? row = create_repository_row(subfolder_name, "Cloning...", true, false);

			clone.begin(row, url, subfolder, is_bare, (obj, res) => {
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

				row.repository = repository;
				row.branch_label.set_markup("<small>%s</small>".printf(branch_name));
				row.spinner.stop();
				row.spinner.hide();
				row.arrow.show();
				row.bin.fraction = 0;
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
