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
	public enum DefaultSelection
	{
		CURRENT_BRANCH,
		ALL_BRANCHES,
		ALL_COMMITS
	}

	/* The main history view. This view shows the equivalent of git log, but
	 * in a nice way with lanes, merges, ref labels etc.
	 */
	public class Activity : Object, GitgExt.UIElement, GitgExt.Activity, GitgExt.Searchable, GitgExt.History
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
		private uint d_walker_update_idle_id;
		private ulong d_refs_list_selection_id;
		private ulong d_refs_list_changed_id;
		private ulong d_externally_changed_id;
		private ulong d_commits_changed_id;

		private Gitg.WhenMapped? d_reload_when_mapped;

		private Paned d_main;
		private Gitg.PopupMenu d_refs_list_popup;
		private Gitg.PopupMenu d_commit_list_popup;

		private string[] d_mainline;
		private bool d_ignore_external;

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
			d_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.history");

			d_settings.changed["topological-order"].connect((s, k) => {
				update_sort_mode();
			});

			d_settings.changed["mainline-head"].connect((s, k) => {
				update_walker();
			});

			d_settings.changed["show-upstream-with-branch"].connect((s, k) => {
				update_walker();
			});

			d_selected = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
			                                       (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);

			d_commit_list_model = new Gitg.CommitModel(application.repository);
			d_commit_list_model.started.connect(on_commit_model_started);
			d_commit_list_model.finished.connect(on_commit_model_finished);

			update_sort_mode();

			d_repository = application.repository;

			application.bind_property("repository", this,
			                          "repository", BindingFlags.DEFAULT);

			reload_mainline();

			d_externally_changed_id = application.repository_changed_externally.connect(repository_changed_externally);
			d_commits_changed_id = application.repository_commits_changed.connect(repository_commits_changed);
		}

		private void repository_changed_externally(GitgExt.ExternalChangeHint hint)
		{
			if (d_main != null && (hint & GitgExt.ExternalChangeHint.REFS) != 0  && !d_ignore_external)
			{
				reload_when_mapped();
			}

			d_ignore_external = false;
		}

		private void repository_commits_changed()
		{
			if (d_main != null)
			{
				d_ignore_external = true;
				reload_when_mapped();
			}
		}

		private void reload_when_mapped()
		{
			if (d_main != null)
			{
				d_reload_when_mapped = new Gitg.WhenMapped(d_main);

				d_reload_when_mapped.update(() => {
					reload();
				}, this);
			}
		}

		public override void dispose()
		{
			if (d_refs_list_selection_id != 0)
			{
				d_main.refs_list.disconnect(d_refs_list_selection_id);
				d_refs_list_selection_id = 0;
			}

			if (d_refs_list_changed_id != 0)
			{
				d_main.refs_list.disconnect(d_refs_list_changed_id);
				d_refs_list_changed_id = 0;
			}

			if (d_walker_update_idle_id != 0)
			{
				Source.remove(d_walker_update_idle_id);
				d_walker_update_idle_id = 0;
			}

			if (d_externally_changed_id != 0)
			{
				application.disconnect(d_externally_changed_id);
				d_externally_changed_id = 0;
			}

			if (d_commits_changed_id != 0)
			{
				application.disconnect(d_commits_changed_id);
				d_commits_changed_id = 0;
			}

			d_commit_list_model.repository = null;
			base.dispose();
		}

		private void update_sort_mode()
		{
			if (d_settings.get_boolean("topological-order"))
			{
				d_commit_list_model.sort_mode = Ggit.SortMode.TOPOLOGICAL;
			}
			else
			{
				d_commit_list_model.sort_mode = Ggit.SortMode.TIME | Ggit.SortMode.TOPOLOGICAL;
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

		private void on_commit_model_begin_clear(Gitg.CommitModel model)
		{
			d_main.commit_list_view.model = null;
		}

		private void on_commit_model_end_clear(Gitg.CommitModel model)
		{
			d_main.commit_list_view.model = d_commit_list_model;
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

		private void store_changed_mainline()
		{
			var repo = application.repository;

			if (repo == null)
			{
				return;
			}

			Ggit.Config config;

			try
			{
				config = repo.get_config();
			} catch { return; }

			store_mainline(config, string.joinv(",", d_mainline));
		}

		private void store_mainline(Ggit.Config? config, string mainline)
		{
			if (config != null)
			{
				try
				{
					config.set_string("gitg.mainline", mainline);
				}
				catch (Error e)
				{
					stderr.printf("Failed to set gitg.mainline: %s\n", e.message);
				}
			}
		}

		private void reload_mainline()
		{
			d_reload_when_mapped = null;

			var uniq = new Gee.HashSet<string>();

			d_mainline = new string[0];

			var repository = application.repository;

			if (repository == null)
			{
				return;
			}

			Ggit.Config? config = null;
			var ref_names = new string[0];

			try
			{
				config = repository.get_config();
				ref_names = config.snapshot().get_string("gitg.mainline").split(",");
			}
			catch
			{
				ref_names = new string[] {"refs/heads/master"};
			}

			foreach (var name in ref_names)
			{
				Gitg.Ref r;

				try
				{
					r = repository.lookup_reference(name);
				}
				catch (Error e)
				{
					stderr.printf("Failed to lookup reference (%s): %s\n", name, e.message);
					continue;
				}

				var id = id_for_ref(r);

				if (id != null && uniq.add(name))
				{
					d_mainline += name;
				}
			}

			store_mainline(config, string.joinv(",", d_mainline));
		}

		public RefsList refs_list
		{
			get { return d_main.refs_list; }
		}

		private void reload()
		{
			if (d_walker_update_idle_id != 0)
			{
				Source.remove(d_walker_update_idle_id);
				d_walker_update_idle_id = 0;
			}

			var view = d_main.commit_list_view;

			double vadj = d_main.refs_list.get_adjustment().get_value();

			reload_mainline();

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

			d_main.refs_list.remote_lookup = application.remote_lookup;

			d_main.commit_list_view.model = d_commit_list_model;

			d_main.commit_list_view.get_selection().changed.connect((sel) => {
				selection_changed();

				// Set primary selection to sha1 of first selected commit
				var clip = ((Gtk.Widget)application).get_clipboard(Gdk.SELECTION_PRIMARY);

				foreach_selected((commit) => {
					clip.set_text(commit.get_id().to_string(), -1);
					return false;
				});
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

			d_refs_list_selection_id = d_main.refs_list.notify["selection"].connect(update_walker_idle);
			d_refs_list_changed_id = d_main.refs_list.changed.connect(update_walker_idle);

			d_commit_list_popup = new Gitg.PopupMenu(d_main.commit_list_view);
			d_commit_list_popup.populate_menu.connect(on_commit_list_populate_menu);
			d_commit_list_popup.request_menu_position.connect(on_commit_list_request_menu_position);

			application.bind_property("repository", d_main.refs_list,
			                          "repository",
			                          BindingFlags.DEFAULT |
			                          BindingFlags.SYNC_CREATE);

			d_main.commit_list_view.set_search_equal_func(search_filter_func);

			d_commit_list_model.begin_clear.connect(on_commit_model_begin_clear);
			d_commit_list_model.end_clear.connect(on_commit_model_end_clear);
		}

		private void update_walker_idle()
		{
			if (d_repository == null)
			{
				return;
			}

			if (d_walker_update_idle_id == 0)
			{
				d_walker_update_idle_id = Idle.add(() => {
					d_walker_update_idle_id = 0;
					update_walker();
					return false;
				});
			}
		}

		private Gtk.Menu? popup_on_ref(Gdk.EventButton? event)
		{
			int cell_x;
			int cell_y;
			int cell_w;
			Gtk.TreePath path;
			Gtk.TreeViewColumn column;

			if (event == null)
			{
				return null;
			}

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
				ret = popup_menu_for_commit(event);
			}

			// event is most likely null.
			if (ret == null)
			{
				ret = popup_menu_for_selection();
			}

			return ret;
		}

		private Gdk.Rectangle? on_commit_list_request_menu_position()
		{
			var selection = d_main.commit_list_view.get_selection();

			Gtk.TreeModel model;
			Gtk.TreeIter iter;

			if (!selection.get_selected(out model, out iter))
			{
				return null;
			}

			var path = model.get_path(iter);

			Gdk.Rectangle rect = { 0 };

			d_main.commit_list_view.get_cell_area(path, null, out rect);
			d_main.commit_list_view.convert_bin_window_to_widget_coords(rect.x, rect.y,
			                                                            out rect.x, out rect.y);

			return rect;
		}

		private void add_ref_action(Gee.LinkedList<GitgExt.RefAction> actions,
		                            GitgExt.RefAction?                action)
		{
			if (action != null && action.available)
			{
				actions.add(action);
			}
		}

		private Gtk.Menu? populate_menu_for_commit(Gitg.Commit commit)
		{
			var af = new ActionInterface(application, d_main.refs_list);

			af.updated.connect(() => {
				d_ignore_external = true;
			});

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

			add_commit_action(actions,
			                  new Gitg.CommitActionCherryPick(application,
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

			if (actions.size == 0)
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

		private Gtk.Menu? popup_menu_for_selection()
		{
			var selection = d_main.commit_list_view.get_selection();

			Gtk.TreeIter iter;

			if (!selection.get_selected(null, out iter))
			{
				return null;
			}

			var commit = d_commit_list_model.commit_from_iter(iter);

			if (commit == null)
			{
				return null;
			}

			return populate_menu_for_commit(commit);
		}

		private Gtk.Menu? popup_menu_for_commit(Gdk.EventButton? event)
		{
			int cell_x;
			int cell_y;
			Gtk.TreePath path;
			Gtk.TreeViewColumn column;

			if (event == null)
			{
				return null;
			}

			if (!d_main.commit_list_view.get_path_at_pos((int)event.x,
			                                             (int)event.y,
			                                             out path,
			                                             out column,
			                                             out cell_x,
			                                             out cell_y))
			{
				return null;
			}

			var commit = d_commit_list_model.commit_from_path(path);

			if (commit == null)
			{
				return null;
			}

			d_main.commit_list_view.get_selection().select_path(path);

			return populate_menu_for_commit(commit);
		}

		private Gtk.Menu? popup_menu_for_ref(Gitg.Ref reference)
		{
			var actions = new Gee.LinkedList<GitgExt.RefAction?>();

			var af = new ActionInterface(application, d_main.refs_list);

			af.updated.connect(() => {
				d_ignore_external = true;
			});

			add_ref_action(actions, new Gitg.RefActionCheckout(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionRename(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionDelete(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCopyName(application, af, reference));

			var fetch = new Gitg.RefActionFetch(application, af, reference);

			if (fetch.available)
			{
				actions.add(null);
			}

			add_ref_action(actions, fetch);

			var push = new Gitg.RefActionPush(application, af, reference);

			if (push.available)
			{
				actions.add(null);
			}

			add_ref_action(actions, push);

			var merge = new Gitg.RefActionMerge(application, af, reference);

			if (merge.available)
			{
				actions.add(null);
				add_ref_action(actions, merge);
			}

			var exts = new Peas.ExtensionSet(Gitg.PluginsEngine.get_default(),
			                                 typeof(GitgExt.RefAction),
			                                 "application",
			                                 application,
			                                 "action_interface",
			                                 af,
			                                 "reference",
			                                 reference);

			var addedsep = false;

			exts.foreach((extset, info, extension) => {
				if (!addedsep)
				{
					actions.add(null);
					addedsep = true;
				}

				add_ref_action(actions, extension as GitgExt.RefAction);
			});

			if (actions.is_empty)
			{
				return null;
			}

			Gtk.Menu menu = new Gtk.Menu();

			foreach (var ac in actions)
			{
				if (ac != null)
				{
					ac.populate_menu(menu);
				}
				else
				{
					var sep = new Gtk.SeparatorMenuItem();
					sep.show();
					menu.append(sep);
				}
			}

			var sep = new Gtk.SeparatorMenuItem();
			sep.show();
			menu.append(sep);

			var item = new Gtk.CheckMenuItem.with_label(_("Mainline"));
			int pos = 0;

			foreach (var ml in d_mainline)
			{
				if (ml == reference.get_name())
				{
					item.active = true;
					break;
				}

				++pos;
			}

			item.activate.connect(() => {
				if (item.active)
				{
					d_mainline += reference.get_name();
				}
				else
				{
					var nml = new string[d_mainline.length - 1];
					nml.length = 0;

					for (var i = 0; i < d_mainline.length; i++)
					{
						if (i != pos)
						{
							nml += d_mainline[i];
						}
					}

					d_mainline = nml;
				}

				store_changed_mainline();
				update_walker();
			});

			item.show();
			menu.append(item);

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

		private Ggit.OId? id_for_ref(Ggit.Ref r)
		{
			Ggit.OId? id = null;

			try
			{
				var resolved = r.resolve();

				if (resolved.is_tag())
				{
					var t = application.repository.lookup<Ggit.Tag>(resolved.get_target());

					id = t.get_target_id();
				}
				else
				{
					id = resolved.get_target();
				}
			}
			catch {}

			return id;
		}

		private void update_walker()
		{
			d_selected.clear();

			var include = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc)Ggit.OId.hash,
			                                        (Gee.EqualDataFunc)Ggit.OId.equal);

			var isall = d_main.refs_list.is_all;
			var isheader = d_main.refs_list.is_header;

			var perm_uniq = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc)Ggit.OId.hash,
			                                          (Gee.EqualDataFunc)Ggit.OId.equal);

			var permanent = new Ggit.OId[0];

			if (application.repository != null)
			{
				foreach (var ml in d_mainline)
				{
					Ggit.OId id;

					try
					{
						id = id_for_ref(application.repository.lookup_reference(ml));
					} catch { continue; }

					if (id != null && perm_uniq.add(id))
					{
						permanent += id;
					}
				}

				if (d_settings.get_boolean("mainline-head"))
				{
					try
					{
						var head = id_for_ref(application.repository.get_head());

						if (head != null && perm_uniq.add(head))
						{
							permanent += head;
						}
					} catch {}
				}
			}

			var show_upstream_with_branch = d_settings.get_boolean("show-upstream-with-branch");

			foreach (var r in d_main.refs_list.selection)
			{
				var id = id_for_ref(r);

				if (id != null)
				{
					include.add(id);

					if (!isall)
					{
						d_selected.add(id);

						if (!isheader && perm_uniq.add(id))
						{
							permanent += id;
						}
					}

					if (show_upstream_with_branch && r.is_branch())
					{
						var branch = r as Gitg.Branch;

						try
						{
							var upid = id_for_ref(branch.get_upstream());

							if (upid != null)
							{
								include.add(upid);
							}
						} catch {}
					}
				}
			}

			d_commit_list_model.set_permanent_lanes(permanent);
			d_commit_list_model.set_include(include.to_array());
			d_commit_list_model.reload();
		}

		public bool search_available
		{
			get { return true; }
		}

		private void add_commit_action(Gee.LinkedList<GitgExt.CommitAction> actions,
		                               GitgExt.CommitAction?                action)
		{
			if (action != null && action.available)
			{
				actions.add(action);
			}
		}

		private string normalize(string s)
		{
			return s.normalize(-1, NormalizeMode.ALL).casefold();
		}

		private bool search_filter_func(Gtk.TreeModel model, int column, string key, Gtk.TreeIter iter)
		{
			var c = d_commit_list_model.commit_from_iter(iter);

			if (c.get_id().has_prefix(key))
			{
				return false;
			}

			var nkey = normalize(key);
			var subject = normalize(c.get_subject());

			if (subject.contains(nkey))
			{
				return false;
			}

			var message = normalize(c.get_message());

			if (message.contains(nkey))
			{
				return false;
			}

			return true;
		}

		public Gtk.Entry? search_entry
		{
			set
			{
				d_main.commit_list_view.set_search_entry(value);

				if (value != null)
				{
					d_main.commit_list_view.set_search_column(0);
				}
				else
				{
					d_main.commit_list_view.set_search_column(-1);
				}
			}
		}

		public string search_text { owned get; set; default = ""; }
		public bool search_visible { get; set; }
	}
}

// ex: ts=4 noet
