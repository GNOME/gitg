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
	public enum SelectionMode
	{
		NORMAL,
		SELECTION
	}

	public class RepositoryListBox : Gtk.ListBox
	{
		private string? d_filter_text;

		public signal void repository_activated(Repository repository);
		public signal void show_error(string primary_message, string secondary_message);

		[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-repository-list-box-row.ui")]
		public class Row : Gtk.ListBoxRow
		{
			private Repository? d_repository;
			private DateTime d_time;
			private bool d_loading;
			private bool d_has_remote;
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
			[GtkChild]
			private Gtk.CheckButton d_remove_check_button;
			[GtkChild]
			private Gtk.Revealer d_remove_revealer;
			[GtkChild]
			private Gtk.Box d_submodule_box;

			public signal void request_remove();

			private SelectionMode d_mode;

			private static Gtk.IconSize s_icon_size;

			static construct
			{
				s_icon_size = Gtk.icon_size_register("gitg", 64, 64);
			}

			public SelectionMode mode
			{
				get { return d_mode; }

				set
				{
					if (d_mode != value)
					{
						d_mode = value;

						d_remove_revealer.reveal_child = (d_mode == SelectionMode.SELECTION);

						d_remove_check_button.active = false;
					}
				}
			}

			[Notify]
			public new bool selected
			{
				get; set;
			}

			construct
			{
				d_remove_check_button.bind_property("active",
				                                    this,
				                                    "selected",
				                                    BindingFlags.BIDIRECTIONAL |
				                                    BindingFlags.SYNC_CREATE);
			}

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

			public bool can_remove
			{
				get { return d_remove_check_button.sensitive; }
				set { d_remove_check_button.sensitive = value; }
			}

			public DateTime time
			{
				get { return d_time; }
				set { d_time = value; }
				default = new DateTime.now_local();
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

			public bool has_remote
			{
				get { return d_has_remote; }
				set
				{
					d_has_remote = value;

					var folder_icon_name = d_has_remote ? "folder-remote" : "folder";
					d_image.set_from_icon_name(folder_icon_name, s_icon_size);
				}
			}

			public Row(string name, string branch_name, bool has_remote)
			{
				Object(repository_name: name, branch_name: branch_name, has_remote: has_remote);
			}

			public void add_submodule(Ggit.Submodule module)
			{
				var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 3);
				var tip = @"$(module.get_path())/ ($(module.get_url()))";
				box.set_tooltip_text(tip);
				box.show();

				var icon = new Gtk.Image.from_icon_name("folder-remote-symbolic",
				                                        Gtk.IconSize.MENU);
				icon.show();

				var name = Path.get_basename(module.get_url());

				if (name.has_suffix(".git"))
				{
					name = name[0:-4];
				}

				var labelName = new Gtk.Label(name);
				labelName.show();

				var arrow = new Gtk.Arrow(Gtk.ArrowType.RIGHT, Gtk.ShadowType.NONE);
				arrow.show();

				var path = module.get_path();
				var labelPath = new Gtk.Label(@"$path/");
				labelPath.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
				labelPath.show();

				box.add(icon);
				box.add(labelName);
				box.add(arrow);
				box.add(labelPath);

				d_submodule_box.add(box);
			}
		}

		[Notify]
		public SelectionMode mode { get; set; }

		protected override bool button_press_event(Gdk.EventButton event)
		{
			Gdk.Event *ev = (Gdk.Event *)event;

			if (ev->triggers_context_menu() && mode == SelectionMode.NORMAL)
			{
				mode = SelectionMode.SELECTION;

				var row = get_row_at_y((int)event.y) as Row;

				if (row != null)
				{
					row.selected = true;
				}

				return true;
			}

			return base.button_press_event(event);
		}

		protected override void row_activated(Gtk.ListBoxRow row)
		{
			var r = (Row)row;

			if (mode == SelectionMode.SELECTION)
			{
				r.selected = !r.selected;
				return;
			}

			if (r.repository != null)
			{
				repository_activated(r.repository);
			}
		}

		construct
		{
			set_header_func(update_header);
			set_filter_func(filter);
			set_sort_func(compare_widgets);
			show();

			set_selection_mode(Gtk.SelectionMode.NONE);

			add_recent_info();
		}

		private void update_header(Gtk.ListBoxRow row, Gtk.ListBoxRow? before)
		{
			row.set_header(before != null ? new Gtk.Separator(Gtk.Orientation.HORIZONTAL) : null);
		}

		private bool filter(Gtk.ListBoxRow row)
		{
			return d_filter_text != null ? ((Row)row).repository_name.contains(d_filter_text) : true;
		}

		private int compare_widgets(Gtk.ListBoxRow a, Gtk.ListBoxRow b)
		{
			return - ((Row)a).time.compare(((Row)b).time);
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

		private Row get_row_for_repository(Repository repository)
		{
			Row? row = null;

			foreach (var child in get_children())
			{
				var d = (Row)child;

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
			Row? row = get_row_for_repository(repository);

			var f = repository.workdir != null ? repository.workdir : repository.location;

			if (row == null)
			{
				string head_name = "";
				bool has_remote = true;

				try
				{
					var head = repository.get_head();
					head_name = head.parsed_name.shortname;
					var remotes = repository.list_remotes();
					if (remotes.length == 0)
					{
						has_remote = false;
					}
				}
				catch {}

				row = new Row(repository.name, head_name, has_remote);
				row.repository = repository;
				row.show();

				try
				{
					repository.submodule_foreach((module) => {
						row.add_submodule(module);
						return 0;
					});
				}
				catch {}

				if (f != null)
				{
					bind_property("mode",
					              row,
					              "mode");
				}

				if (f != null)
				{
					row.notify["selected"].connect(() => {
						notify_property("has-selection");
					});

					row.request_remove.connect(() => {
						try
						{
							var recent_manager = Gtk.RecentManager.get_default();
							recent_manager.remove_item(f.get_uri());
						} catch {}

						remove(row);
					});

					row.can_remove = true;
				}
				else
				{
					row.can_remove = false;
				}

				add(row);
			}
			else
			{
				// to get the item sorted to the beginning of the list
				row.time = new DateTime.now_local();
				invalidate_sort();
			}

			if (f != null)
			{
				add_repository_to_recent_manager(f.get_uri());
			}
		}

		public Row[] selection
		{
			owned get
			{
				var ret = new Row[0];

				foreach (var row in get_children())
				{
					var r = (Row)row;

					if (r.selected)
					{
						ret += r;
					}
				}

				return ret;
			}
		}

		public bool has_selection
		{
			get
			{
				foreach (var row in get_children())
				{
					var r = (Row)row;

					if (r.selected)
					{
						return true;
					}
				}

				return false;
			}
		}

		class CloneProgress : Ggit.RemoteCallbacks
		{
			private Row d_row;

			public CloneProgress(Row row)
			{
				d_row = row;
			}

			protected override void transfer_progress(Ggit.TransferProgress stats)
			{
				var recvobj = stats.get_received_objects();
				var indxobj = stats.get_indexed_objects();
				var totaobj = stats.get_total_objects();

				d_row.fraction = (recvobj + indxobj) / (double)(2 * totaobj);
			}
		}

		private async Repository? clone(Row row, string url, File location, bool is_bare)
		{
			SourceFunc callback = clone.callback;
			Repository? repository = null;

			ThreadFunc<void*> run = () => {
				try
				{
					var clone_options = new Ggit.CloneOptions();
					var fetch_options = new Ggit.FetchOptions();

					clone_options.set_is_bare(is_bare);
					clone_options.set_fetch_options(fetch_options);
					fetch_options.set_remote_callbacks(new CloneProgress(row));

					repository = (Repository)Ggit.Repository.clone(url, location, clone_options);
				}
				catch (Ggit.Error e)
				{
					show_error("Gitg could not clone the git repository.", e.message);
				}
				catch (GLib.Error e)
				{
					show_error("Gitg could not clone the git repository.", e.message);
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
				show_error("Gitg could not clone the git repository.", e.message);
				return;
			}

			// Clone
			var row = new Row(subfolder_name, "Cloning...", true);
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

			invalidate_filter();
		}
	}
}

// ex:ts=4 noet
