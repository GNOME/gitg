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
			public Repository repository;
			public DateTime time;
			public Grid grid;
			public Image image;
			public Label repository_label;
			public Label branch_label;
		}

		public virtual signal void repository_activated(Repository repository)
		{
		}

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

				if (data != null)
				{
					repository_activated(data.repository);
				}
			});

			add_recent_info();
		}

		private void update_separator(ref Widget? separator, Widget widget, Widget? before_widget)
		{
			if (before_widget != null && separator == null)
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

		public void add_repository(Gitg.Repository repository)
		{
			RepositoryData? data = null;
			File? workdir = repository.get_workdir();
			File? repo_file = repository.get_location();

			foreach (var child in d_listbox.get_children())
			{
				var d = child.get_data<RepositoryData>("data");
				if (d.repository.get_location().equal(repository.get_location()))
				{
					data = d;
					break;
				}
			}

			if (data == null)
			{
				data = new RepositoryData();
				data.repository = repository;
				data.time = new DateTime.now_local();
				data.grid = new Grid();
				data.grid.margin = 12;
				data.grid.column_spacing = 10;

				// FIXME: choose the folder image in relation to the next:
				// - the repository is local
				// - the repository has a remote
				// - the repository uses github...
				data.image = new Image.from_icon_name("folder", d_icon_size);
				data.grid.attach(data.image, 0, 0, 1, 2);

				data.repository_label = new Label(null);
				var label_text = (workdir != null) ? workdir.get_basename() : repo_file.get_basename();
				data.repository_label.set_markup("<b>%s</b>".printf(label_text));
				data.repository_label.ellipsize = Pango.EllipsizeMode.END;
				data.repository_label.valign = Align.START;
				data.repository_label.halign = Align.START;
				data.repository_label.hexpand = true;
				data.grid.attach(data.repository_label, 1, 0, 1, 1);

				data.branch_label = new Label("");
				data.branch_label.ellipsize = Pango.EllipsizeMode.END;
				data.branch_label.valign = Align.START;
				data.branch_label.halign = Align.START;
				data.branch_label.get_style_context().add_class("dim-label");
				data.grid.attach(data.branch_label, 1, 1, 1, 1);

				Gitg.Ref? head = null;
				try
				{
					head = repository.get_head();
				}
				catch {}

				// show the active branch
				if (head != null)
				{
					try
					{
						repository.branches_foreach(Ggit.BranchType.LOCAL, (branch_name, branch_type) => {
							try
							{
								Ref? reference = repository.lookup_reference("refs/heads/" + branch_name);

								if (reference != null && reference.get_target().equal(head.get_target()))
								{
									data.branch_label.set_text(branch_name);
									return 1;
								}
							}
							catch {}

							return 0;
						});
					}
					catch {}
				}

				data.grid.attach(new Arrow(ArrowType.RIGHT, ShadowType.NONE), 2, 0, 1, 2);

				data.grid.set_data<RepositoryData>("data", data);
				data.grid.show_all();
				d_listbox.add(data.grid);
			}
			else
			{
				// to get the item sorted to the beginning of the list
				data.time = new DateTime.now_local();
				d_listbox.resort();
			}

			// add repository to recent manager
			var recent_manager = RecentManager.get_default();
			var item = RecentData();
			item.app_name = Environment.get_application_name();
			item.mime_type = "inode/directory";
			item.app_exec = string.join(" ", Environment.get_prgname(), "%f");
			item.groups = { "gitg", null };
			recent_manager.add_full(workdir.get_uri(), item);
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
