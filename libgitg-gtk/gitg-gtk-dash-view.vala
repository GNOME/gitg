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
	public class DashView : Box
	{
		private Egg.ListBox d_listbox;
		private class RepositoryData
		{
			public Repository repository;
			public Grid grid;
			public Label branch_label;
		}

		public virtual signal void repository_activated(Repository repository)
		{
		}

		construct
		{
			d_listbox = new Egg.ListBox();
			var context = d_listbox.get_style_context();
			context.add_class("view");
			context.add_class("content-view");
			d_listbox.set_separator_funcs(update_separator);
			d_listbox.show();
			add(d_listbox);

			d_listbox.set_activate_on_single_click(false);
			d_listbox.child_activated.connect((listbox, child) => {
				var data = child.get_data<RepositoryData>("data");

				if (data != null)
				{
					repository_activated(data.repository);
				}
			});

			var recent_manager = RecentManager.get_default();
			var items = recent_manager.get_items();

			foreach (var item in items)
			{
				if (item.has_group("gitg"))
				{
					add_repository(item);
				}
			}
		}

		private void update_separator(ref Widget? separator, Widget widget, Widget? before_widget)
		{
			if (before_widget != null && separator == null) {
				separator = new Separator(Orientation.HORIZONTAL);
			} else {
				separator = null;
			}
		}

		private void add_repository(RecentInfo info)
		{
			File info_file = File.new_for_uri(info.get_uri());
			File repo_file;

			try
			{
				repo_file = Ggit.Repository.discover(info_file);
			}
			catch
			{
				// TODO: remove from the recent manager
				return;
			}

			Gitg.Repository repo;

			try
			{
				repo = new Gitg.Repository(repo_file, null);
			}
			catch
			{
				return;
			}

			var data = new RepositoryData();
			data.repository = repo;
			data.grid = new Grid();
			data.grid.margin = 12;
			data.grid.set_column_spacing(10);

			File? workdir = repo.get_workdir();
			var label = new Label((workdir != null) ? workdir.get_path() : repo_file.get_path());
			label.set_ellipsize(Pango.EllipsizeMode.END);
			label.set_valign(Align.START);
			label.set_halign(Align.START);
			data.grid.attach(label, 0, 0, 1, 1);

			data.branch_label = new Label("");
			data.branch_label.set_ellipsize(Pango.EllipsizeMode.END);
			data.branch_label.set_valign(Align.START);
			data.branch_label.set_halign(Align.START);
			data.grid.attach(data.branch_label, 0, 1, 1, 1);

			Gitg.Ref? head = null;
			try
			{
				head = repo.get_head();
			}
			catch {}

			// show the active branch
			if (head != null)
			{
				try
				{
					repo.branches_foreach(Ggit.BranchType.LOCAL, (branch_name, branch_type) => {
						try
						{
							Ref? reference = repo.lookup_reference("refs/heads/" + branch_name);

							if (reference != null && reference.get_id().equal(head.get_id()))
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

			data.grid.set_data<RepositoryData>("data", data);
			data.grid.show_all();
			d_listbox.add(data.grid);
		}
	}
}

// ex:ts=4 noet
