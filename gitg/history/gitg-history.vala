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
	public class Activity : Object, GitgExt.UIElement, GitgExt.Activity, GitgExt.Selectable, GitgExt.History
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
		private Gitg.PopupMenu d_refs_list_popup;
		private Gitg.PopupMenu d_commit_list_popup;

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

		public void select(Gitg.Commit commit)
		{
			var model = (Gitg.CommitModel)d_main.commit_list_view.model;
			var path = model.path_from_commit(commit);

			if (path != null)
			{
				var sel = d_main.commit_list_view.get_selection();
				sel.select_path(path);

				d_main.commit_list_view.scroll_to_cell(path, null, true, 0.5f, 0);
			}
			else
			{
				stderr.printf("Failed to lookup tree path for commit '%s'\n", commit.get_id().to_string());
			}
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

			var sel = d_main.commit_list_view.get_selection();

			if (d_selected.size == 0 || d_selected.remove(commit.get_id()))
			{
				sel.select_path(path);

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

			if (d_selected.size == 0 || (sel.count_selected_rows() != 0 &&
			                             (sel.mode == Gtk.SelectionMode.SINGLE ||
			                              sel.mode == Gtk.SelectionMode.BROWSE)))
			{
				d_selected.clear();

				d_commit_list_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}
		}

		private void scroll_into_view()
		{
			if (d_main == null)
			{
				return;
			}

			var sel = d_main.commit_list_view.get_selection();

			Gtk.TreeModel m;
			var rows = sel.get_selected_rows(out m);

			if (rows == null)
			{
				return;
			}

			var row = rows.data;

			Gtk.TreePath startp;
			Gtk.TreePath endp;

			if (d_main.commit_list_view.get_visible_range(out startp, out endp))
			{
				if (row.compare(startp) < 0 || row.compare(endp) > 0)
				{
					d_main.commit_list_view.scroll_to_cell(row, null, true, 0, 0);
				}
			}
		}

		private void on_commit_model_finished(Gitg.CommitModel model)
		{
			if (d_insertsig != 0)
			{
				d_commit_list_model.disconnect(d_insertsig);
				d_insertsig = 0;
			}

			scroll_into_view();
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

			d_refs_list_popup = new Gitg.PopupMenu(d_main.refs_list);
			d_refs_list_popup.populate_menu.connect(on_refs_list_populate_menu);

			d_main.refs_list.notify["selection"].connect(() => {
				update_walker();
			});

			d_commit_list_popup = new Gitg.PopupMenu(d_main.commit_list_view);
			d_commit_list_popup.populate_menu.connect(on_commit_list_populate_menu);

			application.bind_property("repository", d_main.refs_list,
			                          "repository",
			                          BindingFlags.DEFAULT |
			                          BindingFlags.SYNC_CREATE);

			bind_property("selectable-mode",
			              d_main,
			              "selectable-mode",
			              BindingFlags.BIDIRECTIONAL);
		}

		private Gtk.Menu? popup_on_ref(Gdk.EventButton? event)
		{
			int cell_x;
			int cell_y;
			int cell_w;
			Gtk.TreePath path;
			Gtk.TreeViewColumn column;

			if (!d_main.commit_list_view.get_path_at_pos((int)event.x,
			                                             (int)event.y,
			                                             out path,
			                                             out column,
			                                             out cell_x,
			                                             out cell_y))
			{
				return null;
			}

			var cell = d_main.commit_list_view.find_cell_at_pos(column, path, cell_x, out cell_w) as Gitg.CellRendererLanes;

			if (cell == null)
			{
				return null;
			}

			var reference = cell.get_ref_at_pos(d_main.commit_list_view, cell_x, cell_w, null);

			if (reference == null)
			{
				return null;
			}

			return popup_menu_for_ref(reference);
		}

		private Gtk.Menu? on_commit_list_populate_menu(Gdk.EventButton? event)
		{
			var ret = popup_on_ref(event);

			if (ret == null)
			{
				selectable_mode = GitgExt.SelectionMode.SELECTION;
			}

			return ret;
		}

		private void add_ref_action(Gee.LinkedList<GitgExt.RefAction> actions,
		                            GitgExt.RefAction?                action)
		{
			if (action != null && action.available)
			{
				actions.add(action);
			}
		}

		private Gtk.Menu? popup_menu_for_ref(Gitg.Ref reference)
		{
			var actions = new Gee.LinkedList<GitgExt.RefAction>();

			var af = new ActionInterface(application, d_main.refs_list);

			add_ref_action(actions, new Gitg.RefActionRename(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionDelete(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCopyName(application, af, reference));

			var exts = new Peas.ExtensionSet(Gitg.PluginsEngine.get_default(),
			                                 typeof(GitgExt.RefAction),
			                                 "application",
			                                 application,
			                                 "action_interface",
			                                 af,
			                                 "reference",
			                                 reference);

			exts.foreach((extset, info, extension) => {
				add_ref_action(actions, extension as GitgExt.RefAction);
			});

			if (actions.is_empty)
			{
				return null;
			}

			Gtk.Menu menu = new Gtk.Menu();

			foreach (var ac in actions)
			{
				ac.populate_menu(menu);
			}

			// To keep actions alive as long as the menu is alive
			menu.set_data("gitg-ext-actions", actions);
			return menu;
		}

		private Gtk.Menu? on_refs_list_populate_menu(Gdk.EventButton? event)
		{
			if (event != null)
			{
				var row = d_main.refs_list.get_row_at_y((int)event.y);
				d_main.refs_list.select_row(row);
			}

			var references = d_main.refs_list.selection;

			if (references.is_empty || references.first() != references.last())
			{
				return null;
			}

			return popup_menu_for_ref(references.first());
		}

		private void update_walker()
		{
			d_selected.clear();

			var include = new Ggit.OId[0];
			var isall = d_main.refs_list.is_all;

			foreach (var r in d_main.refs_list.selection)
			{
				try
				{
					var resolved = r.resolve();
					Ggit.OId? id;

					if (resolved.is_tag())
					{
						var t = application.repository.lookup<Ggit.Tag>(resolved.get_target());

						id = t.get_target_id();
					}
					else
					{
						id = resolved.get_target();
					}

					include += id;

					if (!isall)
					{
						d_selected.add(id);
					}
				}
				catch {}
			}

			d_commit_list_model.set_include(include);
			d_commit_list_model.reload();
		}

		[Notify]
		public GitgExt.SelectionMode selectable_mode
		{
			get; set;
		}

		private void add_commit_action(Gee.LinkedList<GitgExt.CommitAction> actions,
		                               GitgExt.CommitAction?                action)
		{
			if (action != null && action.available)
			{
				actions.add(action);
				action.finished.connect(() => {
					selectable_mode = GitgExt.SelectionMode.NORMAL;
				});
			}
		}

		public Gtk.Widget? action_widget
		{
			owned get
			{
				Gitg.Commit? commit = null;

				foreach_selected((c) => {
					commit = (Gitg.Commit)c;
					return false;
				});

				var af = new ActionInterface(application, d_main.refs_list);

				var actions = new Gee.LinkedList<GitgExt.CommitAction>();

				add_commit_action(actions,
				                  new Gitg.CommitActionCreateBranch(application,
				                                                    af,
				                                                    commit));

				add_commit_action(actions,
				                  new Gitg.CommitActionCreateTag(application,
				                                                 af,
				                                                 commit));

				add_commit_action(actions,
				                  new Gitg.CommitActionCreatePatch(application,
				                                                   af,
				                                                   commit));

				var exts = new Peas.ExtensionSet(Gitg.PluginsEngine.get_default(),
				                                 typeof(GitgExt.CommitAction),
				                                 "application",
				                                 application,
				                                 "action_interface",
				                                 af,
				                                 "commit",
				                                 commit);

				exts.foreach((extset, info, extension) => {
					add_commit_action(actions, extension as GitgExt.CommitAction);
				});

				var ab = new Gtk.ActionBar();
				ab.show();

				var box = new Gtk.Box(Gtk.Orientation.HORIZONTAL, 6);
				box.margin = 6;
				box.homogeneous = true;
				box.show();

				foreach (var action in actions)
				{
					var widget = action.widget;

					if (widget == null)
					{
						var button = new Gtk.Button.with_label(action.display_name);
						button.tooltip_text = action.description;

						button.clicked.connect(() => {
							action.activate();
						});

						widget = button;
					}

					widget.show();
					box.add(widget);
				}

				ab.set_center_widget(box);

				return ab;
			}
		}
	}
}

// ex: ts=4 noet
