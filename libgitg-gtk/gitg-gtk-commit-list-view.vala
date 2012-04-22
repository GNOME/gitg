namespace GitgGtk
{
	public class CommitListView : Gtk.TreeView, Gtk.Buildable
	{
		public CommitListView(GitgGtk.CommitModel model)
		{
			Object(model: model);
		}

		public CommitListView.for_repository(Gitg.Repository repository)
		{
			this(new GitgGtk.CommitModel(repository));
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
			Gitg.Commit? commit = m.commit_from_iter(iter);

			if (commit == null)
			{
				return;
			}

			var cp = iter;
			Gitg.Commit? next_commit = null;

			if (m.iter_next(ref cp))
			{
				next_commit = m.commit_from_iter(cp);
			}

			unowned SList<Gitg.Ref> labels = m.repository.refs_for_id(commit.get_id());

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

// vi:ts=4
