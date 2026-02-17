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
		private string d_main_remote;
		private bool d_ignore_external;

		private Gitg.UIElements<GitgExt.HistoryPanel> _d_panels;

		public Gitg.UIElements<GitgExt.HistoryPanel> d_panels
		{
			get { return _d_panels; }
		}

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

			reload_main_references();

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
					((Gtk.ApplicationWindow)application).activate_action("reload", null);
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

		private void store_changed_gitg_value(string key, string? val)
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

			if (config != null)
			{
				if( val != null && val.length > 0)
				{
					try
					{
						config.set_string(key, val);
					}
					catch (Error e)
					{
						stderr.printf("Failed to set %s: %s\n", key, e.message);
					}
				}
				else
				{
					config.delete_entry(key);
				}
			}
		}

		private void reload_main_references()
		{
			d_reload_when_mapped = null;

			var uniq = new Gee.HashSet<string>();

			d_mainline = new string[0];

			var repository = application.repository;

			if (repository == null)
			{
				return;
			}

			Ggit.Config? config = repository.get_config();
			var ref_names = new string[0];

			string default_branch;

			try
			{
				ref_names = config.snapshot().get_string("gitg.mainline").split(",");
			}
			catch
			{
				try
				{
					default_branch = config.snapshot().get_string("init.defaultBranch");
					ref_names = new string[] {"refs/heads/%s".printf(default_branch)};
				}
				catch
				{
				}
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

			store_changed_gitg_value("gitg.mainline", string.joinv(",", d_mainline));
			try
			{
				d_main_remote = config.snapshot().get_string("gitg.main-remote");
			} catch {}
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

			reload_main_references();

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

		public bool on_key_pressed (Gdk.EventKey event) {
			var mmask = Gtk.accelerator_get_default_mod_mask();

			if ((mmask & event.state) == Gdk.ModifierType.MOD1_MASK)
			{
				foreach(var element in d_panels.get_available_elements()) {
					 GitgExt.HistoryPanel panel = (GitgExt.HistoryPanel)element;
					uint? key = panel.shortcut;
					if (key != null && key == Gdk.keyval_to_lower(event.keyval)) {
						panel.activate();
						return true;
					}
				};
			}
			return false;
		}

		private void build_ui()
		{
			d_main = new Paned();

			d_main.refs_list.application = application;

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

			d_main.refs_list.row_activated.connect(on_ref_list_row_activated);

			var engine = Gitg.PluginsEngine.get_default();

			var extset = new Peas.ExtensionSet(engine,
			                                   typeof(GitgExt.HistoryPanel),
			                                   "history",
			                                   this,
			                                   "application",
			                                   application);

			_d_panels = new Gitg.UIElements<GitgExt.HistoryPanel>(extset,
			                                                     d_main.stack_panel);

			d_refs_list_popup = new Gitg.PopupMenu(d_main.refs_list);
			d_refs_list_popup.populate_menu.connect(on_refs_list_populate_menu);

			d_refs_list_selection_id = d_main.refs_list.notify["selection"].connect(update_walker_idle);
			d_refs_list_changed_id = d_main.refs_list.changed.connect(update_walker_idle);

			d_commit_list_popup = new Gitg.PopupMenu(d_main.commit_list_view);
			d_commit_list_popup.populate_menu.connect(on_commit_list_populate_menu);
			d_commit_list_popup.request_menu_position.connect(on_commit_list_request_menu_position);

			d_main.commit_list_view.set_search_equal_func(search_filter_func);

			d_commit_list_model.begin_clear.connect(on_commit_model_begin_clear);
			d_commit_list_model.end_clear.connect(on_commit_model_end_clear);

			var actions = new Gee.LinkedList<GitgExt.Action>();
			actions.add(new Gitg.AddRemoteAction(application));
			actions.add(new Gitg.FetchAllRemotesAction(application, d_main.refs_list));
			d_main.refs_list.remotes_actions = actions;

			application.bind_property("repository", d_main.refs_list,
			                          "repository",
			                          BindingFlags.DEFAULT |
			                          BindingFlags.SYNC_CREATE);

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

			return popup_menu_for_ref(reference, event);
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
				ret = popup_menu_for_selection(event);
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

		private static Regex regex_custom_actions_commits;
		private static Regex regex_custom_actions_commits_group;

		private Gtk.Menu? populate_menu_for_commit(Gitg.Commit commit, Gdk.EventButton? event)
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
			                  new Gitg.CommitActionCheckout(application,
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

			add_commit_action(actions,
			                  new Gitg.CommitActionPush(application,
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

			var sep = new Gtk.SeparatorMenuItem();
			sep.show();
			menu.append(sep);

			menu.append (add_visible_columns_action());

			sep = new Gtk.SeparatorMenuItem();
			sep.show();
			menu.append(sep);

			// To keep actions alive as long as the menu is alive
			menu.set_data("gitg-ext-actions", actions);

			var conf = d_repository.get_config().snapshot();
			if (regex_custom_actions_commits == null)
				regex_custom_actions_commits = new Regex("gitg\\.actions\\.commits\\.(.+)\\.name", RegexCompileFlags.OPTIMIZE);
			if (regex_custom_actions_commits_group == null)
				regex_custom_actions_commits_group = new Regex("gitg\\.actions\\.commits\\.(.+)\\.group", RegexCompileFlags.OPTIMIZE);

			Gitg.Utils.add_custom_actions(menu, "commits",
			                              conf, regex_custom_actions_commits,
			                              regex_custom_actions_commits_group,
			                              (action_key_prefix, item_groups) => {
			                                return Gitg.Utils.build_custom_action(conf,
			                                                                      action_key_prefix,
			                                                                      item_groups,
			                                                                      (vars, stdout_data, stderr_data) => {
			                                      var dlg = new Gitg.ResultDialog(null,
			                                                                      vars.get("dialog-title"),
			                                                                      vars.get("dialog-label"));
			                                      dlg.response.connect((d, resp) => {
			                                        dlg.destroy();
			                                      });
			                                      dlg.append_message(stdout_data);
			                                      dlg.append_message(stderr_data);
			                                      return dlg;
			                                    },
			                                    () => {
			                                      var object_vars = new Gee.HashMap<string,string> ();
			                                      object_vars.set ("sha", commit.get_id().to_string());
			                                      return object_vars;
			                                    }
			                              );
			});

			return menu;
		}

		private Gtk.MenuItem add_visible_columns_action () {
			var item = new Gtk.MenuItem.with_label ("Visible Columns");

			item.activate.connect (() => {
				show_visible_columns_dialog ();
			});
			item.show();
			return item;
		}

		private void show_visible_columns_dialog () {
			var list_model = new GLib.ListStore(typeof(ListRow));
			var listbox = new DragListBox(list_model);
			listbox.set_selection_mode (Gtk.SelectionMode.NONE);

			var treeview =d_main.commit_list_view;

			listbox.row_reorder.connect((from, to) => {
				sync_listbox_actions(list_model, listbox);
				var cols = treeview.get_columns();
				int n = (int)cols.length();
				if (n == 0)
					return;

				var col = cols.nth_data(from);

				Gtk.TreeViewColumn[] without = new Gtk.TreeViewColumn[n - 1];
				int j = 0;
				for (int i = 0; i < n; i++) {
					var current_col = cols.nth_data(i);
					if (current_col == col)
						continue;
					if (!current_col.visible)
						continue;
					without[j++] = current_col;
				}

				Gtk.TreeViewColumn? base_col = null;
				if (to > 0)
					base_col = without[to - 1];

				treeview.move_column_after(col, base_col);
			});

			list_model.items_changed.connect((p, r, a) => {
				sync_listbox_actions(list_model, listbox);
			});

			sync_listbox_actions(list_model, listbox);

			var sw = new Gtk.ScrolledWindow (null, null);
			sw.set_size_request(-1, 350);
			sw.hexpand = true;
			sw.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.ALWAYS);
			listbox.vadjustment = sw.vadjustment;
			sw.add(listbox);

			var vbox_listbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);
			vbox_listbox.pack_start(sw, true, true, 0);

			var switch = new Gtk.Switch();
			var label = new Gtk.Label("Show columns");
			switch.active = treeview.get_headers_visible();

			switch.state_set.connect ((state) => {
				treeview.headers_visible = switch.active;
				return false;
			});

			var hbox = new Gtk.HBox(false, 5);
			hbox.pack_start(switch, false, false, 0);
			hbox.pack_start(label, false, false, 0);
			vbox_listbox.pack_start(hbox, false, false, 0);
			vbox_listbox.show_all();

			treeview.set_reorderable(true);

			var columns = treeview.get_columns();

			foreach (var column in columns) {
				list_model.append(new ListRow(column.title, column ));
			}

			treeview.columns_changed.connect(() => {
				var cols = treeview.get_columns();

				for (int i = 0; i < cols.length(); i++) {
					var title = cols.nth_data(i).title;
					var children = listbox.get_children();
					int from = -1;
					ListBoxRowDnD rowj = null;
					for (int j = 0; j < children.length(); j++) {
						rowj = listbox.get_row_at_index(j) as ListBoxRowDnD;
						var row_title = rowj.title;
						if (row_title == title) {
							from = j;
							break;
						}
					}
					if (from == -1)
						continue;

					int to = i;

					if (to == from)
						continue;

					var list_row = (ListRow)list_model.get_item(from);
					list_model.remove(from);
					list_model.insert(to, list_row);
				}
			});

			var dlg = new Gtk.Dialog.with_buttons (
				"Visible columns", (Gtk.Window) d_main,
				Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
				"Close", Gtk.ResponseType.CLOSE,
				null
			);
			dlg.set_default_size (300, 120);

			var content_area = dlg.get_content_area();
			content_area.pack_start (vbox_listbox, true, true, 0);

			dlg.show_all ();
			dlg.run ();
			content_area.remove(vbox_listbox);
			dlg.destroy ();
		}

		public void sync_row_actions(GLib.ListStore list_model, ListBoxRowDnD row, int pos) {
			bool up = true;
			bool down = true;
			int count = (int)list_model.get_n_items();

			if (pos == 0) {
				up = false;
			}
			if (pos == count - 1) {
				down = false;
			}
			row.enable_up(up);
			row.enable_down(down);
		}

		public void sync_listbox_actions(GLib.ListStore list_model, DragListBox listbox) {
			int pos = 0;
			var row = listbox.get_row_at_index(pos) as ListBoxRowDnD;
			while( row != null) {
				sync_row_actions(list_model, row, pos);
				row = listbox.get_row_at_index(++pos) as ListBoxRowDnD;
			}
		}

		private Gtk.Menu? popup_menu_for_selection(Gdk.EventButton? event)
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

			return populate_menu_for_commit(commit, event);
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

			return populate_menu_for_commit(commit, event);
		}

		private static Regex regex_custom_actions_reference;
		private static Regex regex_custom_actions_reference_group;

		private Gtk.Menu? popup_menu_for_ref(Gitg.Ref reference, Gdk.EventButton? event)
		{
			var actions = new Gee.LinkedList<GitgExt.RefAction?>();

			var af = new ActionInterface(application, d_main.refs_list);

			af.updated.connect(() => {
				d_ignore_external = true;
			});

			add_ref_action(actions, new Gitg.RefActionCreateBranch(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionSetUpstreamBranch(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCreateTag(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCreatePatch(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCheckout(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionRename(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionDelete(application, af, reference));
			add_ref_action(actions, new Gitg.RefActionCopyName(application, af, reference));

			bool shift_pressed = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;
			var fetch = new Gitg.RefActionFetch(application, af, reference, null, shift_pressed);

			if (fetch.available)
			{
				actions.add(null);
				add_ref_action(actions, fetch);
			}

			var push = new Gitg.RefActionPush(application, af, reference);

			if (push.available)
			{
				actions.add(null);
				add_ref_action(actions, push);
			}

			var merge = new Gitg.RefActionMerge(application, af, reference);

			if (merge.available)
			{
				actions.add(null);
				add_ref_action(actions, merge);
			}

			var info_tag = new Gitg.RefActionTagShowInfo(application, af, reference);

			if (info_tag.available)
			{
				actions.add(null);
				add_ref_action(actions, info_tag);
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

			menu.append (add_visible_columns_action());

			sep = new Gtk.SeparatorMenuItem();
			sep.show();
			menu.append(sep);

			if (regex_custom_actions_reference == null)
				regex_custom_actions_reference = new Regex("gitg\\.actions\\.reference\\.(.+)\\.name", RegexCompileFlags.OPTIMIZE);
			if (regex_custom_actions_reference_group == null)
				regex_custom_actions_reference_group = new Regex("gitg\\.actions\\.reference\\.(.+)\\.group", RegexCompileFlags.OPTIMIZE);

			var conf = repository.get_config().snapshot();
			Gitg.Utils.add_custom_actions(menu, "reference",
			                              conf, regex_custom_actions_reference,
			                              regex_custom_actions_reference_group,
			                              (action_key_prefix, item_groups) => {
			                                return Gitg.Utils.build_custom_action(conf,
			                                                                      action_key_prefix,
			                                                                      item_groups,
			                                                                      (vars, stdout_data, stderr_data) => {
			                                      var dlg = new Gitg.ResultDialog(null,
			                                                                      vars.get("dialog-title"),
			                                                                      vars.get("dialog-label"));
			                                      dlg.response.connect((d, resp) => {
			                                        dlg.destroy();
			                                      });
			                                      dlg.append_message(stdout_data);
			                                      dlg.append_message(stderr_data);
			                                      return dlg;
			                                    },
			                                    () => {
			                                      var object_vars = new Gee.HashMap<string,string> ();
			                                      object_vars.set ("name",          reference.parsed_name.name);
			                                      object_vars.set ("shortname",     reference.parsed_name.shortname);
			                                      object_vars.set ("remote_name",   reference.parsed_name.remote_name);
			                                      object_vars.set ("remote_branch", reference.parsed_name.remote_branch);
			                                      return object_vars;
			                                    }
			                              );
			});

			if (menu.get_data<int>("items") > 0)
			{
				sep = new Gtk.SeparatorMenuItem();
				sep.show();
				menu.append(sep);
			}
			var item = build_set_mainline_action(reference);
			item.show();
			menu.append(item);

			// To keep actions alive as long as the menu is alive
			menu.set_data("gitg-ext-actions", actions);
			return menu;
		}


		public Gtk.MenuItem build_set_mainline_action(Gitg.Ref reference)
		{
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

				store_changed_gitg_value("gitg.mainline", string.joinv(",", d_mainline));
				update_walker();
			});

			return item;
		}

		private Gtk.Menu? on_refs_list_populate_menu(Gdk.EventButton? event)
		{
			Gtk.ListBoxRow selection = null;
			if (event != null)
			{
				var y = d_main.refs_list.y_in_window((int)event.y, event.window);
				var row = d_main.refs_list.get_row_at_y(y);
				selection = row;
				d_main.refs_list.select_row(row);
			}

			var references = d_main.refs_list.selection;

			Gee.LinkedList<GitgExt.Action> actions = null;
			if (selection != null && selection.get_type () == typeof(RefHeader)) {
				var ref_header = ((RefHeader)selection);
				if ((actions = ref_header.actions) != null && actions.size > 0) {
					var menu = new Gtk.Menu();

					foreach (var ac in actions)
					{
						if (ac != null)
						{
							if (ac is GitgExt.FetchAvoidTags)
							{
								var fat = ac as GitgExt.FetchAvoidTags;
								bool shift_pressed = (event.state & Gdk.ModifierType.SHIFT_MASK) != 0;
								fat.no_tags = shift_pressed;
							}
							ac.populate_menu(menu);
						}
						else
						{
							var sep = new Gtk.SeparatorMenuItem();
							sep.show();
							menu.append(sep);
						}
					}

					var item = new Gtk.CheckMenuItem.with_label(_("Main remote"));
					item.active = ref_header.ref_name == d_main_remote;
					item.activate.connect(() => {

						string? main_remote = null;
						if (item.active)
						{
							main_remote = ref_header.ref_name;
						}

						store_changed_gitg_value("gitg.main-remote", main_remote);
						d_main_remote = main_remote;
						((Gtk.ApplicationWindow)application).activate_action("reload", null);
					});

					item.show();
					menu.append(item);
					menu.set_data("gitg-ext-actions", actions);
					return menu;
				} else {
					return null;
				}
			} else if (!references.is_empty && references.first() == references.last()) {
				return popup_menu_for_ref(references.first(), event);
			} else {
				return null;
			}
		}

		private Ggit.OId? id_for_ref(Ggit.Ref r)
		{
			Ggit.OId? id = null;

			try
			{
				var resolved = r.resolve();
				id = resolved.get_target();

				if (resolved.is_tag())
				{
					try
					{
						var t = application.repository.lookup<Ggit.Tag>(id);
						id = t.get_target_id();
					}
					catch {}
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

		private void on_ref_list_row_activated(Gtk.ListBoxRow row)
		{
			var ref_row = row as RefRow;
			if (ref_row == null) {
				return;
			}

			if (ref_row.reference.is_branch() || ref_row.reference.is_remote()) {
				var af = new ActionInterface(application, d_main.refs_list);
				var checkout = new Gitg.RefActionCheckout(application, af, ref_row.reference);
				checkout.activate();
			}
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

			var author = c.get_author();
			if (author.get_name().down().contains(nkey) || author.get_email().down().contains(nkey)) {
				return false;
			}

			var committer = c.get_committer();
			if (committer.get_name().down().contains(nkey) || committer.get_email().down().contains(nkey)) {
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

		public override void search_move(string key, bool up)
		{
			// Move the tree selection by sending key press event,
			// see: https://gitlab.gnome.org/GNOME/gtk/merge_requests/1167
			var search_entry = d_main.commit_list_view.get_search_entry();
			var keyval = up ? Gdk.Key.Up : Gdk.Key.Down;

			Gdk.KeymapKey[] keys;
			if(!Gdk.Keymap.get_for_display(search_entry.get_display()).get_entries_for_keyval(keyval, out keys))
			{
				return;
			}

			search_entry.grab_focus();

			Gdk.EventKey* event = new Gdk.Event(Gdk.EventType.KEY_PRESS);
			event->window = search_entry.get_window();
			event->keyval = keyval;
			event->hardware_keycode = (uint16) keys[0].keycode;
			event->group = (uint8) keys[0].group;
			((Gdk.Event*) event)->put();

			return;
		}

		public override bool show_buttons()
		{
			return true;
		}
	}
}

// ex: ts=4 noet
