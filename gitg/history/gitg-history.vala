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

		private Navigation? d_navigation_model;
		private Gitg.CommitModel? d_commit_list_model;
		private Gee.HashSet<Ggit.OId> d_selected;
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

		[Notify]
		public Gitg.Repository repository
		{
			set
			{
				if (value != null)
				{
					reload();
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

			d_navigation_model = new Navigation(application.repository);
			d_navigation_model.ref_activated.connect((r) => {
				on_ref_activated(d_navigation_model, r);
			});

			d_commit_list_model = new Gitg.CommitModel(application.repository);
			d_commit_list_model.started.connect(on_commit_model_started);
			d_commit_list_model.finished.connect(on_commit_model_finished);

			update_sort_mode();

			application.bind_property("repository", d_navigation_model,
			                          "repository", BindingFlags.DEFAULT);

			application.bind_property("repository", d_commit_list_model,
			                          "repository", BindingFlags.DEFAULT);

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

		private void on_ref_activated(Navigation n, Gitg.Ref? r)
		{
			update_walker(n, r);
		}

		public void activate()
		{
			d_main.navigation_view.expand_all();
			d_main.navigation_view.select_first();
		}

		public void reload()
		{
			double vadj = d_main.navigation_view.get_vadjustment().get_value();

			d_navigation_model.reload();
			d_main.navigation_view.expand_all();
			d_main.navigation_view.select();

			d_main.navigation_view.size_allocate.connect((a) => {
				d_main.navigation_view.get_vadjustment().set_value(vadj);
			});
		}

		private void build_ui()
		{
			d_main = new Paned();

			d_main.navigation_view.model = d_navigation_model;
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
		}

		private void update_walker(Navigation n, Gitg.Ref? head)
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

			d_selected.clear();

			if (id != null)
			{
				d_selected.add(id);
				d_commit_list_model.set_include(new Ggit.OId[] { id });
			}
			else
			{
				var included = new Ggit.OId[] {};

				// Simply push all the refs
				foreach (Gitg.Ref r in n.all)
				{
					try
					{
						var resolved = r.resolve();

						try
						{
							var t = application.repository.lookup<Ggit.Tag>(resolved.get_target());
							included += t.get_target_id();
						}
						catch
						{
							included += resolved.get_target();
						}
					} catch {}
				}

				d_commit_list_model.set_include(included);
			}

			d_commit_list_model.reload();
		}
	}
}

// ex: ts=4 noet
