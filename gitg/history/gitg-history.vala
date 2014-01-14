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

namespace GitgHistory
{
	/* The main history view. This view shows the equivalent of git log, but
	 * in a nice way with lanes, merges, ref labels etc.
	 */
	public class Activity : Object, GitgExt.UIElement, GitgExt.Activity, GitgExt.History
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }

		private Gitg.CommitModel? d_commit_list_model;

		private Gee.HashSet<Ggit.OId> d_selected;
		private Ggit.OId? d_scroll_to;
		private float d_scroll_y;
		private ulong d_insertsig;
		private Settings d_settings;

		private Paned d_main;

		private Gitg.UIElements<GitgExt.HistoryPanel> d_panels;

		public Activity(GitgExt.Application application)
		{
			Object(application: application);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Activities/History"; }
		}

		private Gitg.Repository d_repository;

		[Notify]
		public Gitg.Repository repository
		{
			get
			{
				return d_repository;
			}

			set
			{
				if (d_repository != value)
				{
					d_repository = value;

					if (value != null)
					{
						reload();
					}
				}
			}
		}

		public void foreach_selected(GitgExt.ForeachCommitSelectionFunc func)
		{
			bool breakit = false;

			d_main.commit_list_view.get_selection().selected_foreach((model, path, iter) => {
				if (!breakit)
				{
					var c = d_commit_list_model.commit_from_iter(iter);

					if (c != null)
					{
						breakit = !func(c);
					}
				}
			});
		}

		construct
		{
			d_settings = new Settings("org.gnome.gitg.preferences.history");
			d_settings.changed["topological-order"].connect((s, k) => {
				update_sort_mode();
			});

			d_selected = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
			                                       (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);

			d_commit_list_model = new Gitg.CommitModel(application.repository);
			d_commit_list_model.started.connect(on_commit_model_started);
			d_commit_list_model.finished.connect(on_commit_model_finished);

			update_sort_mode();

			application.bind_property("repository", this,
			                          "repository", BindingFlags.DEFAULT);
		}

		private void update_sort_mode()
		{
			if (d_settings.get_boolean("topological-order"))
			{
				d_commit_list_model.sort_mode |= Ggit.SortMode.TOPOLOGICAL;
			}
			else
			{
				d_commit_list_model.sort_mode &= ~Ggit.SortMode.TOPOLOGICAL;
			}
		}

		private void on_commit_model_started(Gitg.CommitModel model)
		{
			if (d_insertsig == 0)
			{
				d_insertsig = d_commit_list_model.row_inserted.connect(on_row_inserted_select);
			}
		}

		private void on_row_inserted_select(Gtk.TreeModel model, Gtk.TreePath path, Gtk.TreeIter iter)
		{
			var commit = d_commit_list_model.commit_from_path(path);

			if (d_selected.size == 0 || d_selected.remove(commit.get_id()))
			{
				d_main.commit_list_view.get_selection().select_path(path);

				if (commit.get_id().equal(d_scroll_to))
				{
					d_main.commit_list_view.scroll_to_cell(path,
					                                       null,
					                                       true,
					                                       d_scroll_y,
					                                       0);

					d_scroll_to = null;
				}
			}

			if (d_selected.size == 0)
			{
				d_commit_list_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}
		}

		private void on_commit_model_finished(Gitg.CommitModel model)
		{
			if (d_insertsig != 0)
			{
				d_commit_list_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}
		}

		public bool available
		{
			get { return true; }
		}

		public string display_name
		{
			owned get { return _("History"); }
		}

		public string description
		{
			owned get { return _("Examine the history of the repository"); }
		}

		public string? icon
		{
			owned get { return "view-list-symbolic"; }
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				if (d_main == null)
				{
					build_ui();
				}

				return d_main;
			}
		}

		public bool is_default_for(string action)
		{
			return (action == "" || action == "history");
		}

		public bool enabled
		{
			get { return true; }
		}

		public int negotiate_order(GitgExt.UIElement other)
		{
			return -1;
		}

		private void reload()
		{
			var view = d_main.commit_list_view;

			double vadj = d_main.refs_list.get_adjustment().get_value();

			d_selected.clear();

			d_scroll_to = null;

			Gtk.TreePath startp, endp;

			var isvis = view.get_visible_range(out startp, out endp);

			view.get_selection().selected_foreach((model, path, iter) => {
				var c = d_commit_list_model.commit_from_iter(iter);

				if (c != null)
				{
					d_selected.add(c.get_id());

					if (d_scroll_to == null &&
					    (!isvis || startp.compare(path) <= 0 && endp.compare(path) >= 0))
					{
						if (isvis)
						{
							Gdk.Rectangle rect;
							Gdk.Rectangle visrect;

							view.get_cell_area(path, null, out rect);
							view.get_visible_rect(out visrect);

							int x, y;

							view.convert_tree_to_bin_window_coords(visrect.x,
							                                       visrect.y,
							                                       out x,
							                                       out y);

							// + 2 seems to work correctly here, but this is probably
							// something related to a border or padding of the
							// treeview (i.e. theme related)
							d_scroll_y = (float)(rect.y + rect.height / 2.0 - y + 2) / (float)visrect.height;
						}
						else
						{
							d_scroll_y = 0.5f;
						}

						d_scroll_to = c.get_id();
					}
				}
			});

			// Clears the commit model
			d_commit_list_model.repository = repository;

			// Reloads branches, tags, etc.
			d_main.refs_list.repository = repository;

			ulong sid = 0;

			sid = d_main.refs_list.size_allocate.connect((a) => {
				d_main.refs_list.get_adjustment().set_value(vadj);

				if (sid != 0)
				{
					d_main.refs_list.disconnect(sid);
				}
			});
		}

		private void build_ui()
		{
			d_main = new Paned();

			d_main.commit_list_view.model = d_commit_list_model;

			d_main.commit_list_view.get_selection().changed.connect((sel) => {
				selection_changed();
			});

			var engine = Gitg.PluginsEngine.get_default();

			var extset = new Peas.ExtensionSet(engine,
			                                   typeof(GitgExt.HistoryPanel),
			                                   "history",
			                                   this,
			                                   "application",
			                                   application);

			d_panels = new Gitg.UIElements<GitgExt.HistoryPanel>(extset,
			                                                     d_main.stack_panel);

			d_main.refs_list.ref_activated.connect((r) => {
				update_walker(r);
			});

			application.bind_property("repository", d_main.refs_list,
			                          "repository",
			                          BindingFlags.DEFAULT |
			                          BindingFlags.SYNC_CREATE);
		}

		private void update_walker(Gitg.Ref? head)
		{
			Ggit.OId? id = null;

			if (head != null)
			{
				id = head.get_target();

				if (head.parsed_name.rtype == Gitg.RefType.TAG)
				{
					// See to resolve to the commit
					try
					{
						var t = application.repository.lookup<Ggit.Tag>(id);

						id = t.get_target_id();
					} catch {}
				}
			}

			if (id != null)
			{
				d_commit_list_model.set_include(new Ggit.OId[] { id });
			}
			else
			{
				var included = new Ggit.OId[] {};
				var repo = application.repository;

				try
				{
					repo.references_foreach_name((nm) => {
						Gitg.Ref? r;

						try
						{
							r = repo.lookup_reference(nm);
						} catch { return 0; }

						try
						{
							var resolved = r.resolve();

							try
							{
								var t = repo.lookup<Ggit.Tag>(resolved.get_target());
								included += t.get_target_id();
							}
							catch
							{
								included += resolved.get_target();
							}
						} catch {}

						return 0;
					});
				} catch {}

				try
				{
					if (repo.is_head_detached())
					{
						var resolved = repo.get_head().resolve();
						included += resolved.get_target();
					}
				} catch {}

				d_commit_list_model.set_include(included);
			}

			d_commit_list_model.reload();
		}
	}
}

// ex: ts=4 noet
