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
	public class View : Object, GitgExt.UIElement, GitgExt.View, GitgExt.ObjectSelection
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }

		private Gtk.TreeView d_view;
		private GitgGtk.CommitModel? d_model;
		private Gee.HashSet<Ggit.OId> d_selected;
		private ulong d_insertsig;
		private Settings d_settings;

		private Gtk.Widget d_main;

		public string id
		{
			owned get { return "/org/gnome/gitg/Views/History"; }
		}

		public void foreach_selected(GitgExt.ForeachObjectSelectionFunc func)
		{
			bool breakit = false;

			d_view.get_selection().selected_foreach((model, path, iter) => {
				if (!breakit)
				{
					breakit = !func(d_model.commit_from_iter(iter));
				}
			});
		}

		construct
		{
			d_model = new GitgGtk.CommitModel(application.repository);
			d_selected = new Gee.HashSet<Ggit.OId>(Ggit.OId.hash, (EqualFunc<Ggit.OId>)Ggit.OId.equal);

			d_model.started.connect(on_commit_model_started);
			d_model.finished.connect(on_commit_model_finished);

			d_settings = new Settings("org.gnome.gitg.history.preferences");
			d_settings.changed["topological-order"].connect((s, k) => {
				update_sort_mode();
			});

			update_sort_mode();

			application.bind_property("repository", d_model, "repository", BindingFlags.DEFAULT);

			application.notify["repository"].connect((a, r) => {
				notify_property("available");
			});
		}

		private void update_sort_mode()
		{
			if (d_settings.get_boolean("topological-order"))
			{
				d_model.sort_mode |= Ggit.SortMode.TOPOLOGICAL;
			}
			else
			{
				d_model.sort_mode &= ~Ggit.SortMode.TOPOLOGICAL;
			}
		}

		private void on_commit_model_started(Gitg.CommitModel model)
		{
			if (d_insertsig == 0)
			{
				d_insertsig = d_model.row_inserted.connect(on_row_inserted_select);
			}
		}

		private void on_row_inserted_select(Gtk.TreeModel model, Gtk.TreePath path, Gtk.TreeIter iter)
		{
			var commit = d_model.commit_from_path(path);

			if (d_selected.size == 0 || d_selected.remove(commit.get_id()))
			{
				d_view.get_selection().select_path(path);
			}

			if (d_selected.size == 0)
			{
				d_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}
		}

		private void on_commit_model_finished(Gitg.CommitModel model)
		{
			if (d_insertsig != 0)
			{
				d_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}
		}

		public bool available
		{
			get
			{
				// The history view is available only when there is a repository
				return application.repository != null;
			}
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

		public GitgExt.Navigation? navigation
		{
			owned get
			{
				// Create the sidebar navigation for the history. This navigation
				// will show branches, remotes and tags which can be used to
				// filter the history
				var ret = new Navigation(application);

				ret.ref_activated.connect((r) => on_ref_activated(ret, r));

				return ret;
			}
		}

		public bool is_default_for(string action)
		{
			return application.repository != null && (action == "" || action == "history");
		}

		private void on_ref_activated(Navigation n, Gitg.Ref? r)
		{
			update_walker(n, r);
		}

		private void build_ui()
		{
			var ret = GitgExt.UI.from_builder("history/view-history.ui",
			                                  "scrolled_window_commit_list",
			                                  "commit_list_view",
			                                  "renderer_commit_list_author",
			                                  "renderer_commit_list_author_date");

			d_main = ret["scrolled_window_commit_list"] as Gtk.Widget;

			d_view = ret["commit_list_view"] as Gtk.TreeView;
			d_view.model = d_model;
			d_view.get_selection().changed.connect((sel) => {
				selection_changed();
			});

			(ret["renderer_commit_list_author"] as Gd.StyledTextRenderer).add_class("dim-label");
			(ret["renderer_commit_list_author_date"] as Gd.StyledTextRenderer).add_class("dim-label");

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
						var t = application.repository.lookup(id, typeof(Ggit.Tag)) as Ggit.Tag;

						id = t.get_target_id();
					} catch {}
				}
			}

			d_selected.clear();

			if (id != null)
			{
				d_selected.add(id);
				d_model.set_include(new Ggit.OId[] { id });
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
							var t = application.repository.lookup(resolved.get_target(), typeof(Ggit.Tag)) as Ggit.Tag;
							included += t.get_target_id();
						}
						catch
						{
							included += resolved.get_target();
						}
					} catch {}
				}

				d_model.set_include(included);
			}

			d_model.reload();
		}

		public bool enabled
		{
			get
			{
				return true;
			}
		}

		public int negotiate_order(GitgExt.UIElement other)
		{
			return -1;
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.View),
	                            typeof(GitgHistory.View));

	mod.register_extension_type(typeof(GitgExt.CommandLine),
	                            typeof(GitgHistory.CommandLine));

	mod.register_extension_type(typeof(GitgExt.Preferences),
	                            typeof(GitgHistory.Preferences));
}

// ex: ts=4 noet
