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

namespace Gitg
{
	public class CommitListView : Gtk.TreeView, Gtk.Buildable
	{
		public CommitListView(CommitModel model)
		{
			Object(model: model);
		}

		public CommitListView.for_repository(Repository repository)
		{
			this(new CommitModel(repository));
		}

		public Gtk.CellRenderer? find_cell_at_pos(Gtk.TreeViewColumn column,
		                                          Gtk.TreePath       path,
		                                          int                x,
		                                          out int            width)
		{
			Gtk.TreeIter iter;

			model.get_iter(out iter, path);
			column.cell_set_cell_data(model, iter, false, false);

			var cells = column.get_cells();

			foreach (var cell in cells)
			{
				int start;
				int cellw;

				if (!column.cell_get_position(cell, out start, out cellw))
				{
					continue;
				}

				if (x >= start && x <= start + cellw)
				{
					width = cellw;
					return cell;
				}
			}

			width = 0;
			return null;
		}

		private void lanes_data_func(Gtk.CellLayout   layout,
		                             Gtk.CellRenderer cell,
		                             Gtk.TreeModel    model,
		                             Gtk.TreeIter     iter)
		{
			CommitModel? m = model as CommitModel;

			if (m == null)
			{
				return;
			}

			CellRendererLanes lanes = (CellRendererLanes)cell;
			Commit? commit = m.commit_from_iter(iter);

			if (commit == null)
			{
				return;
			}

			var cp = iter;
			Commit? next_commit = null;

			if (m.iter_next(ref cp))
			{
				next_commit = m.commit_from_iter(cp);
			}

			unowned SList<Ref> labels = m.repository.refs_for_id(commit.get_id());

			lanes.commit = commit;
			lanes.next_commit = next_commit;
			lanes.labels = labels;
		}

		private void parser_finished(Gtk.Builder builder)
		{
			base.parser_finished(builder);

			// Check if there is a cell renderer
			foreach (var column in get_columns())
			{
				foreach (var cell in column.get_cells())
				{
					CellRendererLanes? lanes = cell as CellRendererLanes;

					if (lanes == null)
					{
						continue;
					}

					column.set_cell_data_func(lanes,
					                          lanes_data_func);
				}
			}
		}
	}
}

// ex:ts=4 noet
