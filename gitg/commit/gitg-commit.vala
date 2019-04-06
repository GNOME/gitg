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

namespace GitgCommit
{
	public class Activity : Object, GitgExt.UIElement, GitgExt.Activity
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;
		private Paned? d_main;
		private bool d_reloading;
		private bool d_has_staged;
		private ulong d_externally_changed_id;
		private bool d_ignore_external_changes;
		private Gitg.WhenMapped? d_reload_when_mapped;

		private enum UiType
		{
			DIFF,
			SUBMODULE_HISTORY,
			SUBMODULE_DIFF
		}

		private enum IndexType
		{
			STAGED,
			UNSTAGED
		}

		public GitgExt.Application? application { owned get; construct set; }

		public Activity(GitgExt.Application application)
		{
			Object(application: application);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Activities/Commit"; }
		}

		public Gitg.Repository repository
		{
			set
			{
				reload();
				notify_property("enabled");
			}
		}

		construct
		{
			application.bind_property("repository", this,
			                          "repository", BindingFlags.DEFAULT);

			d_externally_changed_id = application.repository_changed_externally.connect(repository_changed_externally);
		}

		public bool enabled
		{
			get
			{
				return application.repository != null && !application.repository.is_bare;
			}
		}

		public override void dispose()
		{
			if (d_externally_changed_id != 0)
			{
				application.disconnect(d_externally_changed_id);
				d_externally_changed_id = 0;
			}

			base.dispose();
		}

		private void repository_changed_externally(GitgExt.ExternalChangeHint hint)
		{
			if (!d_ignore_external_changes)
			{
				if (d_main != null && (hint & GitgExt.ExternalChangeHint.INDEX) != 0)
				{
					d_reload_when_mapped = new Gitg.WhenMapped(d_main);

					d_reload_when_mapped.update(() => {
						reload();
					}, this);
				}
			}

			d_ignore_external_changes = false;
		}

		public string display_name
		{
			owned get { return C_("Activity", "Commit"); }
		}

		public string description
		{
			owned get { return _("Create new commits and manage the staging area"); }
		}

		public string? icon
		{
			owned get { return "document-save-symbolic"; }
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
			return action == "commit";
		}

		private delegate void StageUnstageCallback(Sidebar.Item item);
		private delegate void StageUnstageSubmoduleCommitCallback(Gitg.Commit commit);

		private delegate void UpdateDiffCallback();
		private UpdateDiffCallback? d_update_diff_callback;

		private bool d_submodule_history_select_first;
		private Gitg.StageStatusSubmodule? d_current_submodule;
		private Gitg.Repository? d_current_submodule_repository;
		private StageUnstageSubmoduleCommitCallback d_stage_unstage_submodule_commit_callback;

		private void show_unstaged_diff(Gitg.StageStatusItem[] items)
		{
			if (items.length == 1 && items[0] is Gitg.StageStatusSubmodule)
			{
				show_submodule_history((Gitg.StageStatusSubmodule)items[0], IndexType.UNSTAGED);
			}
			else
			{
				show_ui(UiType.DIFF);
				show_unstaged_diff_intern(application.repository, d_main.diff_view, items, true);
			}
		}

		private void set_unstaged_diff_update_callback(Gitg.Repository               repository,
		                                               Gitg.DiffView                 view,
		                                               owned Gitg.StageStatusItem[]? items,
		                                               bool                          patchable)
		{
			d_update_diff_callback = () => {
				show_unstaged_diff_intern(repository, view, items, patchable);
			};
		}

		private void show_unstaged_diff_intern(Gitg.Repository         repository,
		                                       Gitg.DiffView           view,
		                                       Gitg.StageStatusItem[]? items,
		                                       bool                    patchable)
		{
			var stage = repository.stage;

			stage.diff_workdir_all.begin(items, view.options, (obj, res) => {
				try
				{
					var d = stage.diff_workdir_all.end(res);

					view.unstaged = patchable;
					view.staged = false;

					d_main.button_stage.label = _("_Stage selection");
					d_main.button_stage.visible = patchable;
					d_main.button_discard.visible = true;

					view.new_is_workdir = true;
					view.diff = d;
				}
				catch
				{
					// TODO: show error in diff
					view.diff = null;
				}
			});

			set_unstaged_diff_update_callback(repository, view, items, patchable);
		}

		private void stage_submodule_at(Gitg.Commit commit)
		{
			stage_submodule.begin(d_current_submodule, commit, (obj, res) => {
				stage_submodule.end(res);

				d_ignore_external_changes = true;
				reload();
			});
		}

		private async bool stage_submodule(Gitg.StageStatusSubmodule sub, Gitg.Commit? commit)
		{
			var stage = application.repository.stage;

			if ((sub.flags & Ggit.SubmoduleStatus.WD_DELETED) != 0)
			{
				try
				{
					yield stage.delete_path(sub.path);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the removal of submodule “%s”").printf(sub.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

					return false;
				}
			}
			else
			{
				Gitg.Repository repo;

				try
				{
					repo = sub.submodule.open() as Gitg.Repository;
				}
				catch (Error e)
				{
					var msg = _("Failed to open the repository of submodule “%s” while trying to stage").printf(sub.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

					return false;
				}

				Ggit.Commit sub_commit = commit;
				if (sub_commit == null)
				{
					try
					{
						sub_commit = repo.lookup<Gitg.Commit>(sub.submodule.get_workdir_id());
					}
					catch (Error e)
					{
						var msg = _("Failed to lookup the working directory commit of submodule “%s” while trying to stage").printf(sub.path);
						application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

						return false;
					}
				}

				try
				{
					yield stage.stage_commit(sub.path, sub_commit);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the submodule “%s”").printf(sub.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

					return false;
				}
			}

			return true;
		}

		private async bool stage_file(Gitg.StageStatusFile file)
		{
			var stage = application.repository.stage;

			if ((file.flags & Ggit.StatusFlags.WORKING_TREE_DELETED) != 0)
			{
				try
				{
					yield stage.delete_path(file.path);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the removal of file “%s”").printf(file.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

					return false;
				}
			}
			else
			{
				try
				{
					yield stage.stage_path(file.path);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the file “%s”").printf(file.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

					return false;
				}
			}

			return true;
		}

		private async void stage_items(owned Gitg.StageStatusItem[] items)
		{
			foreach (var item in items)
			{
				var ok = true;

				if (item is Gitg.StageStatusFile)
				{
					d_ignore_external_changes = true;
					ok = yield stage_file((Gitg.StageStatusFile)item);
				}
				else if (item is Gitg.StageStatusSubmodule)
				{
					d_ignore_external_changes = true;
					ok = yield stage_submodule((Gitg.StageStatusSubmodule)item, null);
				}
				else
				{
					assert_not_reached();
				}

				if (!ok)
				{
					break;
				}
			}

			reload();
		}

		private void show_ui(UiType type)
		{
			d_main.submodule_history_view.set_visible(type == UiType.SUBMODULE_HISTORY);
			d_main.submodule_diff_view.set_visible(type == UiType.SUBMODULE_DIFF);
			d_main.diff_view.set_visible(type == UiType.DIFF);

			if (type != UiType.DIFF)
			{
				d_main.diff_view.diff = null;
			}

			if (type != UiType.SUBMODULE_DIFF)
			{
				var view = d_main.submodule_diff_view;

				view.info.submodule = null;
				view.diff_view_staged.diff = null;
				view.diff_view_unstaged.diff = null;
			}

			if (type != UiType.SUBMODULE_HISTORY)
			{
				var view = d_main.submodule_history_view;
				var model = ((Gitg.CommitModel)view.commit_list_view.model);

				if (model != null)
				{
					model.repository = null;
				}

				view.diff_view.diff = null;
				d_current_submodule = null;
				d_current_submodule_repository = null;
			}
		}

		private void on_unstaged_activated(Gitg.StageStatusItem[] items)
		{
			stage_items.begin(items, (obj, res) => {
				stage_items.end(res);
			});
		}

		private void show_submodule_diff(Gitg.StageStatusSubmodule sub)
		{
			show_ui(UiType.SUBMODULE_DIFF);

			var view = d_main.submodule_diff_view;

			view.info.submodule = sub.submodule;

			Gitg.Repository repo;

			try
			{
				repo = sub.submodule.open() as Gitg.Repository;
			}
			catch (Error e)
			{
				view.diff_view_staged.diff = null;
				view.diff_view_unstaged.diff = null;

				return;
			}

			show_staged_diff_intern(repo, view.diff_view_staged, null, false);
			show_unstaged_diff_intern(repo, view.diff_view_unstaged, null, false);
		}

		private void submodule_history_selection_changed(Gitg.Commit? commit)
		{
			var view = d_main.submodule_history_view;

			if (commit == null)
			{
				view.diff_view.diff = null;
				return;
			}

			if (d_current_submodule_repository == null)
			{
				return;
			}

			var repo = d_current_submodule_repository;

			var commit_tree = commit.get_tree();

			var head = d_current_submodule.submodule.get_head_id();
			Ggit.Tree? head_tree = null;

			if (head != null)
			{
				Ggit.Commit head_commit;

				try
				{
					head_commit = repo.lookup<Gitg.Commit>(head);
				}
				catch (Error e)
				{
					// TODO: show error to user
					stderr.printf("Failed to get head commit: %s\n", e.message);
					return;
				}

				head_tree = head_commit.get_tree();
			}

			Ggit.Diff diff;

			try
			{
				diff = new Ggit.Diff.tree_to_tree(repo, head_tree, commit_tree, view.diff_view.options);
			}
			catch (Error e)
			{
				// TODO: show error to user
				stderr.printf("Failed to get diff: %s\n", e.message);
				return;
			}

			view.diff_view.new_is_workdir = false;
			view.diff_view.diff = diff;
		}

		private void show_submodule_history(Gitg.StageStatusSubmodule sub,
		                                    IndexType                 type)
		{
			show_ui(UiType.SUBMODULE_HISTORY);

			d_current_submodule = null;
			d_current_submodule_repository = null;

			Gitg.Repository repo;
			var submodule = sub.submodule;

			try
			{
				repo = submodule.open() as Gitg.Repository;
			}
			catch (Error e)
			{
				// TODO: show to user
				stderr.printf("Failed to open submodule repository: %s\n", e.message);
				return;
			}

			d_current_submodule = sub;
			d_current_submodule_repository = repo;

			var view = d_main.submodule_history_view;
			var model = (Gitg.CommitModel)view.commit_list_view.model;

			if (model == null)
			{
				model = new Gitg.CommitModel(repo);
				view.commit_list_view.model = model;
			}
			else
			{
				model.repository = repo;
			}

			if (type == IndexType.STAGED)
			{
				model.set_include(new Ggit.OId[] { submodule.get_index_id() });

				var head_id = submodule.get_head_id();

				if (head_id != null)
				{
					model.set_exclude(new Ggit.OId[] { head_id });
				}
				else
				{
					model.set_exclude(new Ggit.OId[0]);
				}

				d_stage_unstage_submodule_commit_callback = (commit) => {
					unstage_submodule_at(commit);
				};
			}
			else
			{
				var index_id = submodule.get_index_id();

				model.set_include(new Ggit.OId[] { submodule.get_workdir_id() });

				if (index_id != null)
				{
					model.set_exclude(new Ggit.OId[] { index_id });
				}
				else
				{
					model.set_exclude(new Ggit.OId[0]);
				}

				d_stage_unstage_submodule_commit_callback = (commit) => {
					stage_submodule_at(commit);
				};
			}

			d_submodule_history_select_first = true;
			model.reload();
		}

		private void set_staged_diff_update_callback(Gitg.Repository               repository,
		                                             Gitg.DiffView                 view,
		                                             owned Gitg.StageStatusItem[]? items,
		                                             bool                          patchable)
		{
			d_update_diff_callback = () => {
				show_staged_diff_intern(repository, view, items, patchable);
			};
		}

		private void show_staged_diff_intern(Gitg.Repository         repository,
		                                     Gitg.DiffView           view,
		                                     Gitg.StageStatusItem[]? items,
		                                     bool                    patchable)
		{
			var stage = repository.stage;

			stage.diff_index_all.begin(items, view.options, (obj, res) => {
				try
				{
					var d = stage.diff_index_all.end(res);

					view.unstaged = false;
					view.staged = patchable;

					d_main.button_stage.label = _("_Unstage selection");
					d_main.button_stage.visible = patchable;
					d_main.button_discard.visible = false;

					view.new_is_workdir = false;
					view.diff = d;
				}
				catch
				{
					// TODO: error reporting
					view.diff = null;
				}
			});

			set_staged_diff_update_callback(repository, view, items, patchable);
		}

		private void show_staged_diff(Gitg.StageStatusItem[] items)
		{
			if (items.length == 1 && items[0] is Gitg.StageStatusSubmodule)
			{
				show_submodule_history((Gitg.StageStatusSubmodule)items[0], IndexType.STAGED);
			}
			else
			{
				show_ui(UiType.DIFF);
				show_staged_diff_intern(application.repository, d_main.diff_view, items, true);
			}
		}

		private async bool unstage_item(Gitg.StageStatusItem item, bool isnew, string removal_msg, string unstage_msg)
		{
			var stage = application.repository.stage;

			if (isnew)
			{
				try
				{
					yield stage.delete_path(item.path);
				}
				catch (Error e)
				{
					application.show_infobar(removal_msg, e.message, Gtk.MessageType.ERROR);
					return false;
				}
			}
			else
			{
				try
				{
					yield stage.unstage_path(item.path);
				}
				catch (Error e)
				{
					application.show_infobar(unstage_msg, e.message, Gtk.MessageType.ERROR);
					return false;
				}
			}

			return true;
		}

		private async bool unstage_file(Gitg.StageStatusFile file)
		{
			return yield unstage_item(file,
			                          (file.flags & Ggit.StatusFlags.INDEX_NEW) != 0,
			                          _("Failed to unstage the removal of file “%s”").printf(file.path),
			                          _("Failed to unstage the file “%s”").printf(file.path));
		}

		private async bool unstage_submodule(Gitg.StageStatusSubmodule sub)
		{
			return yield unstage_item(sub,
			                          (sub.flags & Ggit.SubmoduleStatus.INDEX_ADDED) != 0,
			                          _("Failed to unstage the removal of submodule “%s”").printf(sub.path),
			                          _("Failed to unstage the submodule “%s”").printf(sub.path));
		}

		private void unstage_submodule_at(Gitg.Commit commit)
		{
			var parents = commit.get_parents();

			if (parents.size != 0)
			{
				d_ignore_external_changes = true;
				stage_submodule_at(parents[0] as Gitg.Commit);
			}
			else
			{
				d_ignore_external_changes = true;
				unstage_submodule.begin(d_current_submodule, (obj, res) => {
					unstage_submodule.end(res);
					reload();
				});
			}
		}

		private async void unstage_items(owned Gitg.StageStatusItem[] items)
		{
			foreach (var item in items)
			{
				var ok = true;

				if (item is Gitg.StageStatusFile)
				{
					d_ignore_external_changes = true;
					ok = yield unstage_file((Gitg.StageStatusFile)item);
				}
				else if (item is Gitg.StageStatusSubmodule)
				{
					d_ignore_external_changes = true;
					ok = yield unstage_submodule((Gitg.StageStatusSubmodule)item);
				}
				else
				{
					assert_not_reached();
				}

				if (!ok)
				{
					break;
				}
			}

			reload();
		}

		private void on_staged_activated(Gitg.StageStatusItem[] items)
		{
			unstage_items.begin(items, (obj, res) => {
				unstage_items.end(res);
			});
		}

		private Sidebar.Item[] append_items(Gitg.SidebarStore      model,
		                                    Gitg.StageStatusItem[] items,
		                                    Sidebar.Item.Type      type,
		                                    Gee.HashSet<string>?   selected_paths,
		                                    StageUnstageCallback?  callback)
		{
			var ret = new Sidebar.Item[0];

			var sorted = new Gee.ArrayList<Gitg.StageStatusItem>.wrap(items);

			sorted.sort((a, b) => {
				return a.path.casefold().collate(b.path.casefold());
			});

			foreach (var item in sorted)
			{
				var sitem = new Sidebar.Item(item, type);

				if (selected_paths != null && selected_paths.contains(item.path))
				{
					ret += sitem;
				}

				sitem.activated.connect((numclick) => {
					callback(sitem);
				});

				model.append(sitem);
			}

			return ret;
		}

		private void reload()
		{
			d_reload_when_mapped = null;

			var repository = application.repository;

			if (repository == null || d_reloading)
			{
				return;
			}

			d_reloading = true;

			var sb = d_main.sidebar;
			var model = sb.model;

			Sidebar.Item.Type selected_type;
			Gitg.StageStatusItem[] selected_items;

			selected_items = items_for_items(sb.get_selected_items<Gitg.SidebarItem>(),
			                                 out selected_type);

			var selected_paths = new Gee.HashSet<string>();

			foreach (var item in selected_items)
			{
				selected_paths.add(item.path);
			}

			if (d_main.diff_view.use_gravatar)
			{
				// Preload author avatar
				try
				{
					var author = get_signature("AUTHOR");
					var ac = Gitg.AvatarCache.default();

					ac.load.begin(author.get_email(), 50, null, (obj, res) => {
						ac.load.end(res);
					});
				} catch {}
			}

			var stage = repository.stage;

			var opts = Ggit.StatusOption.INCLUDE_UNTRACKED |
			           Ggit.StatusOption.RECURSE_UNTRACKED_DIRS |
			           Ggit.StatusOption.SORT_CASE_INSENSITIVELY |
			           Ggit.StatusOption.EXCLUDE_SUBMODULES |
			           Ggit.StatusOption.DISABLE_PATHSPEC_MATCH;

			var show = Ggit.StatusShow.INDEX_AND_WORKDIR;

			var options = new Ggit.StatusOptions(opts, show, null);
			var enumerator = stage.file_status(options);

			enumerator.next_items.begin(-1, (obj, res) => {
				var items = enumerator.next_items.end(res);

				var staged = new Gitg.StageStatusItem[items.length];
				staged.length = 0;

				var unstaged = new Gitg.StageStatusItem[items.length];
				unstaged.length = 0;

				var untracked = new Gitg.StageStatusItem[items.length];
				untracked.length = 0;

				var dirty = new Gitg.StageStatusItem[items.length];
				dirty.length = 0;

				bool hassub = false;

				foreach (var item in items)
				{
					if (item.is_staged)
					{
						staged += item;
					}

					if (item.is_unstaged)
					{
						unstaged += item;
					}

					if (item.is_untracked)
					{
						untracked += item;
					}

					var sub = item as Gitg.StageStatusSubmodule;

					if (sub != null)
					{
						hassub = true;

						if (sub.is_dirty)
						{
							dirty += item;
						}
					}
				}

				model.clear();
				d_main.diff_view.diff = null;

				var current_staged = new Sidebar.Item[0];
				var current_unstaged = new Sidebar.Item[0];
				var current_untracked = new Sidebar.Item[0];
				var current_submodules = new Sidebar.Item[0];

				// Populate staged items
				var staged_header = model.begin_header(_("Staged"), (uint)Sidebar.Item.Type.STAGED);

				staged_header.activated.connect((numclick) => {
					on_unstage_selected_items();
				});

				if (staged.length == 0)
				{
					model.append_dummy(_("No staged files"));
				}
				else
				{
					current_staged = append_items(model,
					                              staged,
					                              Sidebar.Item.Type.STAGED,
					                              selected_paths,
					                              (item) => {
						if (d_main.sidebar.is_selected(item))
						{
							on_unstage_selected_items();
						}
						else
						{
							on_staged_activated(new Gitg.StageStatusItem[] {item.item});
						}
					});
				}

				model.end_header();

				// Populate unstaged items
				var unstaged_header = model.begin_header(_("Unstaged"), (uint)Sidebar.Item.Type.UNSTAGED);

				unstaged_header.activated.connect((numclick) => {
					on_stage_selected_items();
				});

				if (unstaged.length == 0)
				{
					model.append_dummy(_("No unstaged files"));
				}
				else
				{
					current_unstaged = append_items(model,
					                                unstaged,
					                                Sidebar.Item.Type.UNSTAGED,
					                                selected_paths,
					                                (item) => {
						if (d_main.sidebar.is_selected(item))
						{
							on_stage_selected_items();
						}
						else
						{
							on_unstaged_activated(new Gitg.StageStatusItem[] {item.item});
						}
					});
				}

				model.end_header();

				// Populate untracked items
				model.begin_header(_("Untracked"), (uint)Sidebar.Item.Type.UNTRACKED);

				if (untracked.length == 0)
				{
					model.append_dummy(_("No untracked files"));
				}
				else
				{
					current_untracked = append_items(model,
					                                 untracked,
					                                 Sidebar.Item.Type.UNTRACKED,
					                                 selected_paths,
					                                 (item) => {
						if (d_main.sidebar.is_selected(item))
						{
							on_stage_selected_items();
						}
						else
						{
							on_unstaged_activated(new Gitg.StageStatusItem[] {item.item});
						}
					});
				}

				model.end_header();

				// Populate submodule items
				if (hassub)
				{
					model.begin_header(_("Submodule"), (uint)Sidebar.Item.Type.SUBMODULE);

					if (dirty.length == 0)
					{
						model.append_dummy(_("No dirty submodules"));
					}
					else
					{
						current_submodules = append_items(model,
						                                  dirty,
						                                  Sidebar.Item.Type.SUBMODULE,
						                                  selected_paths,
						                                  (item) => {
						    if (d_main.sidebar.is_selected(item))
						    {
						    	on_stage_selected_items();
						    }
						    else
						    {
								on_unstaged_activated(new Gitg.StageStatusItem[] {item.item});
							}
						});
					}

					model.end_header();
				}

				d_main.sidebar.expand_all();
				d_has_staged = staged.length != 0;

				d_reloading = false;

				if (selected_paths.size != 0)
				{
					Sidebar.Item[] sel = null;

					switch (selected_type)
					{
					case Sidebar.Item.Type.STAGED:
						sel = current_staged;
						break;
					case Sidebar.Item.Type.UNSTAGED:
						sel = current_unstaged;
						break;
					case Sidebar.Item.Type.UNTRACKED:
						sel = current_untracked;
						break;
					case Sidebar.Item.Type.SUBMODULE:
						sel = current_submodules;
						break;
					}

					if (sel == null || sel.length == 0)
					{
						sel = current_staged;
					}

					if (sel == null || sel.length == 0)
					{
						sel = current_unstaged;
					}

					if (sel == null || sel.length == 0)
					{
						sel = current_untracked;
					}

					if (sel == null || sel.length == 0)
					{
						sel = current_submodules;
					}

					if (sel != null && sel.length != 0)
					{
						foreach (var item in sel)
						{
							d_main.sidebar.select(item);
						}
					}
					else if (selected_type == Sidebar.Item.Type.STAGED)
					{
						d_main.sidebar.select(staged_header);
					}
					else
					{
						d_main.sidebar.select(unstaged_header);
					}
				}
				else
				{
					// Select staged/unstaged header
					if (unstaged.length == 0)
					{
						d_main.sidebar.select(staged_header);
					}
					else
					{
						d_main.sidebar.select(unstaged_header);
					}
				}
			});
		}

		public void activate()
		{
			reload();
		}

		private void do_commit(Dialog         dlg,
		                       bool           skip_hooks,
		                       Ggit.Signature author,
		                       Ggit.Signature committer)
		{
			var stage = application.repository.stage;

			Gitg.StageCommitOptions opts = 0;

			if (dlg.amend)
			{
				opts |= Gitg.StageCommitOptions.AMEND;
			}
			else if (!d_has_staged)
			{
				dlg.show_infobar(_("There are no changes to be committed"),
				                 _("Use amend to change the commit message of the previous commit"),
				                 Gtk.MessageType.WARNING);
				return;
			}

			if (dlg.sign_off)
			{
				opts |= Gitg.StageCommitOptions.SIGN_OFF;
			}

			if (skip_hooks)
			{
				opts |= Gitg.StageCommitOptions.SKIP_HOOKS;
			}

			d_ignore_external_changes = true;
			stage.commit.begin(dlg.pretty_message,
			                   author,
			                   committer,
			                   opts, (obj, res) => {
				try
				{
					stage.commit.end(res);
					reload();

					application.repository_commits_changed();
				}
				catch (Error e)
				{
					var msg = _("Failed to commit");
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}

				dlg.destroy();
			});
		}

		private async bool pre_commit(Ggit.Signature author)
		{
			try
			{
				yield application.repository.stage.pre_commit_hook(author);
			}
			catch (Gitg.StageError e)
			{
				application.show_infobar(_("Failed to pass pre-commit"),
				                         e.message,
				                         Gtk.MessageType.ERROR);

				return false;
			}

			return true;
		}

		private async Gitg.Commit? get_head_commit()
		{
			Gitg.Commit? retval = null;

			try
			{
				yield Gitg.Async.thread(() => {
					var repo = application.repository;

					try
					{
						var head = repo.get_head();
						retval = repo.lookup<Gitg.Commit>(head.get_target());
					} catch {}
				});
			} catch {}

			return retval;
		}

		private async Ggit.Diff? index_diff()
		{
			var opts = new Ggit.DiffOptions();

			opts.flags = Ggit.DiffOption.INCLUDE_UNTRACKED |
			             Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
			             Ggit.DiffOption.RECURSE_UNTRACKED_DIRS;

			opts.n_context_lines = 3;
			opts.n_interhunk_lines = 3;

			var repository = application.repository;

			var stage = repository.stage;

			Ggit.Tree? tree = null;

			try
			{
				if (!repository.is_empty())
				{
					tree = yield stage.get_head_tree();
				}
			}
			catch { return null; }

			Ggit.Diff? diff = null;

			try
			{
				var index = repository.get_index();

				yield Gitg.Async.thread(() => {
					diff = new Ggit.Diff.tree_to_index(repository,
					                                   tree,
					                                   index,
					                                   opts);
				});
			} catch { return null; }

			return diff;
		}

		private void run_commit_dialog(bool           skip_hooks,
		                               Ggit.Signature author,
		                               Ggit.Signature committer)
		{
			index_diff.begin((obj, res) => {
				var diff = index_diff.end(res);

				run_commit_dialog_with_diff(skip_hooks,
				                            author,
				                            committer,
				                            diff);
			});
		}

		private void run_commit_dialog_with_diff(bool           skip_hooks,
		                                         Ggit.Signature author,
		                                         Ggit.Signature committer,
		                                         Ggit.Diff?     diff)
		{
			var dlg = new Dialog(application.repository, author, diff);

			dlg.set_transient_for((Gtk.Window)d_main.get_toplevel());
			dlg.set_default_response(Gtk.ResponseType.OK);

			dlg.response.connect((d, id) => {
				if (id == Gtk.ResponseType.OK)
				{
					do_commit(dlg, skip_hooks, dlg.author, committer);
				}
				else
				{
					d.destroy();
				}
			});

			dlg.notify["amend"].connect((obj, pspec) => {
				if (!dlg.amend)
				{
					dlg.author = author;
				}
				else
				{
					get_head_commit.begin((obj, res) => {
						var commit = get_head_commit.end(res);

						if (commit != null)
						{
							if (dlg.message.strip() == dlg.default_message)
							{
								dlg.message = commit.get_message();
							}

							dlg.author = commit.get_author();
						}
					});
				}
			});

			dlg.show();
		}

		private Ggit.Signature get_signature(string envname) throws Error
		{
			return application.repository.get_signature_with_environment(application.environment, envname);
		}

		private void on_commit_clicked()
		{
			Ggit.Signature? committer;
			Ggit.Signature author;

			committer = application.get_verified_committer();

			if (committer == null)
			{
				return;
			}

			try
			{
				author = application.repository.get_signature_with_environment(application.environment, "AUTHOR");
			}
			catch
			{
				author = committer;
			}

			if (d_main.skip_hooks)
			{
				run_commit_dialog(true, author, committer);
			}
			else
			{
				pre_commit.begin(author, (obj, res) => {
					if (!pre_commit.end(res))
					{
						return;
					}

					run_commit_dialog(false, author, committer);
				});
			}
		}

		private async void stage_unstage_selection(bool staging) throws Error
		{
			var selection = d_main.diff_view.get_selection();
			var stage = application.repository.stage;

			foreach (var pset in selection)
			{
				if (staging)
				{
					yield stage.stage_patch(pset);
				}
				else
				{
					yield stage.unstage_patch(pset);
				}
			}
		}

		private async void discard_selection() throws Error
		{
			var selection = d_main.diff_view.get_selection();
			var stage = application.repository.stage;

			foreach (var pset in selection)
			{
				yield stage.revert_patch(pset);
			}
		}

		private void on_discard_clicked()
		{
			var primary = _("Discard changes");
			var secondary = _("Are you sure you want to permanently discard the selected changes?");

			var q = new GitgExt.UserQuery();

			q.title = primary;
			q.message = secondary;
			q.message_type = Gtk.MessageType.QUESTION;

			q.set_responses(new GitgExt.UserQueryResponse[] {
				new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL),
				new GitgExt.UserQueryResponse(_("Discard"), Gtk.ResponseType.OK),
			});

			q.default_response = Gtk.ResponseType.OK;

			q.response.connect((w, r) => {
				if (r == Gtk.ResponseType.OK)
				{
					return do_discard_selection(q);
				}

				return true;
			});

			application.user_query(q);
		}

		private bool do_discard_selection(GitgExt.UserQuery q)
		{
			application.busy = true;

			d_ignore_external_changes = true;
			discard_selection.begin((obj, res) => {
				try
				{
					discard_selection.end(res);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to discard selection"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				q.quit();
				application.busy = false;

				reload();
			});

			return false;
		}

		private void on_stage_clicked()
		{
			var staging = d_main.diff_view.unstaged;

			d_ignore_external_changes = true;
			stage_unstage_selection.begin(staging, (obj, res) => {
				try
				{
					stage_unstage_selection.end(res);
				}
				catch (Error e)
				{
					string msg;

					if (staging)
					{
						msg = _("Failed to stage selection");
					}
					else
					{
						msg = _("Failed to unstage selection");
					}

					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
					return;
				}

				reload();
			});
		}

		private async void revert_paths(owned string[] paths) throws Error
		{
			var stage = application.repository.stage;

			foreach (var path in paths)
			{
				yield stage.revert_path(path);
			}
		}

		private void do_edit_items(Gitg.StageStatusItem[] items)
		{
			var screen = d_main.get_screen();
			var root = application.repository.get_workdir();

			foreach (var item in items)
			{
				var file = root.get_child(item.path);

				try
				{
					Gtk.show_uri(screen, file.get_uri(), Gdk.CURRENT_TIME);
				}
				catch (Error e)
				{
					stderr.printf("Failed to launch application for %s: %s\n", item.path, e.message);
				}
			}
		}

		private bool do_discard_items(GitgExt.UserQuery q, Gitg.StageStatusItem[] items)
		{
			application.busy = true;

			var paths = new string[items.length];

			for (var i = 0; i < items.length; i++)
			{
				paths[i] = items[i].path;
			}

			d_ignore_external_changes = true;
			revert_paths.begin(paths, (o, ret) => {
				try
				{
					revert_paths.end(ret);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to discard changes"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				application.busy = false;
				q.quit();

				reload();
			});

			return false;
		}

		private void on_discard_menu_activated(Gitg.StageStatusItem[] items)
		{
			var primary = _("Discard changes");
			string secondary;

			if (items.length == 1)
			{
				secondary = _("Are you sure you want to permanently discard all changes made to the file “%s”?").printf(items[0].path);
			}
			else
			{
				var paths = new string[items.length - 1];

				for (var i = 0; i < items.length - 1; i++)
				{
					paths[i] = @"`$(items[i].path)'";
				}

				secondary = _("Are you sure you want to permanently discard all changes made to the files %s and “%s”?").printf(string.joinv(", ", paths), items[items.length - 1].path);
			}

			var q = new GitgExt.UserQuery();

			q.title = primary;
			q.message = secondary;
			q.message_type = Gtk.MessageType.QUESTION;

			q.set_responses(new GitgExt.UserQueryResponse[] {
				new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL),
				new GitgExt.UserQueryResponse(_("Discard"), Gtk.ResponseType.OK)
			});

			q.default_response = Gtk.ResponseType.OK;

			q.response.connect((w, r) => {
				if (r == Gtk.ResponseType.OK)
				{
					return do_discard_items(q, items);
				}

				return true;
			});

			application.user_query(q);
		}

		private async void delete_files(File[] files) throws Error
		{
			SourceFunc cb = delete_files.callback;
			Error? error = null;

			var n = files.length;

			for (var i = 0; i < files.length; i++)
			{
				var file = files[i];

				file.delete_async.begin(Priority.DEFAULT, null, (o, res) => {
					try
					{
						file.delete_async.end(res);
					}
					catch (Error e)
					{
						error = e;
					}

					if (--n == 0)
					{
						cb();
					}
				});
			}

			yield;

			if (error != null)
			{
				throw error;
			}
		}

		private bool do_delete_items(GitgExt.UserQuery q, Gitg.StageStatusItem[] items)
		{
			application.busy = true;

			var files = new File[items.length];

			for (var i = 0; i < items.length; i++)
			{
				files[i] = application.repository.get_workdir().get_child(items[i].path);
			}

			d_ignore_external_changes = true;
			delete_files.begin(files, (o, ret) => {
				try
				{
					delete_files.end(ret);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to delete files"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				application.busy = false;
				q.quit();

				reload();
			});

			return false;
		}

		private void on_delete_menu_activated(Gitg.StageStatusItem[] items)
		{
			var primary = dngettext(null, "Delete file", "Delete files", items.length);
			string secondary;

			if (items.length == 1)
			{
				secondary = _("Are you sure you want to permanently delete the file “%s”?").printf(items[0].path);
			}
			else
			{
				var paths = new string[items.length - 1];

				for (var i = 0; i < items.length - 1; i++)
				{
					paths[i] = @"`$(items[i].path)'";
				}

				secondary = _("Are you sure you want to permanently delete the files %s and “%s”?").printf(string.joinv(", ", paths), items[items.length - 1].path);
			}

			var q = new GitgExt.UserQuery();

			q.title = primary;
			q.message = secondary;
			q.message_type = Gtk.MessageType.QUESTION;

			q.set_responses(new GitgExt.UserQueryResponse[] {
				new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL),
				new GitgExt.UserQueryResponse(primary, Gtk.ResponseType.OK)
			});

			q.default_response = Gtk.ResponseType.OK;
			q.default_is_destructive = true;

			q.response.connect((w, r) => {
				if (r == Gtk.ResponseType.OK)
				{
					return do_delete_items(q, items);
				}

				return true;
			});

			application.user_query(q);
		}

		private void do_populate_menu(Gtk.Menu menu)
		{
			var items = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();

			if (items.length == 0)
			{
				return;
			}

			Sidebar.Item.Type type;

			var sitems = items_for_items(items, out type);
			var hasitems = sitems.length > 0;

			if (type == Sidebar.Item.Type.UNSTAGED ||
			    type == Sidebar.Item.Type.UNTRACKED)
			{
				var stage = new Gtk.MenuItem.with_mnemonic(_("_Stage changes"));
				stage.sensitive = hasitems;

				menu.append(stage);

				stage.activate.connect(() => {
					on_unstaged_activated(sitems);
				});
			}

			if (type == Sidebar.Item.Type.STAGED)
			{
				var stage = new Gtk.MenuItem.with_mnemonic(_("_Unstage changes"));
				stage.sensitive = hasitems;

				menu.append(stage);

				stage.activate.connect(() => {
					on_staged_activated(sitems);
				});
			}

			if (type == Sidebar.Item.Type.UNSTAGED)
			{
				var discard = new Gtk.MenuItem.with_mnemonic(_("_Discard changes"));
				discard.sensitive = hasitems;

				menu.append(discard);

				discard.activate.connect(() => {
					on_discard_menu_activated(sitems);
				});
			}

			if (type == Sidebar.Item.Type.UNTRACKED)
			{
				var del = new Gtk.MenuItem.with_mnemonic(dngettext(null, "D_elete file", "D_elete files", sitems.length));
				del.sensitive = hasitems;

				menu.append(del);

				del.activate.connect(() => {
					on_delete_menu_activated(sitems);
				});
			}

			bool canedit = false;

			if (hasitems)
			{
				canedit = true;

				foreach (var item in sitems)
				{
					var file = item as Gitg.StageStatusFile;

					if (file == null || (file.flags & Ggit.StatusFlags.WORKING_TREE_DELETED) != 0)
					{
						canedit = false;
						break;
					}
				}
			}

			if (canedit)
			{
				var edit = new Gtk.MenuItem.with_mnemonic(_("_Edit file"));
				menu.append(edit);

				edit.activate.connect(() => {
					do_edit_items(sitems);
				});
			}
		}

		private Gitg.StageStatusItem[] items_to_stage_items(Sidebar.Item[] items)
		{
			var ret = new Gitg.StageStatusItem[items.length];

			for (var i = 0; i < ret.length; i++)
			{
				ret[i] = items[i].item;
			}

			return ret;
		}

		private Gitg.StageStatusItem[] stage_status_items_of_type(Sidebar.Item.Type type)
		{
			return items_to_stage_items(d_main.sidebar.items_of_type(type));
		}

		private Gitg.StageStatusItem[] items_for_items(Gitg.SidebarItem[] items, out Sidebar.Item.Type type)
		{
			var ret = new Gitg.StageStatusItem[items.length];
			ret.length = 0;

			type = Sidebar.Item.Type.NONE;

			foreach (var item in items)
			{
				var header = item as Gitg.SidebarStore.SidebarHeader;

				if (header != null)
				{
					type = (Sidebar.Item.Type)header.id;
					return stage_status_items_of_type(type);
				}

				var sitem = item as Sidebar.Item;

				if (sitem != null)
				{
					ret += sitem.item;
					type = sitem.stage_type;
				}
			}

			return ret;
		}

		private void sidebar_selection_changed(Gitg.SidebarItem[] items)
		{
			Sidebar.Item.Type type;

			var sitems = items_for_items(items, out type);

			if (sitems.length == 0)
			{
				show_ui(UiType.DIFF);
				d_main.diff_view.diff = null;
				return;
			}

			if (type == Sidebar.Item.Type.SUBMODULE)
			{
				show_submodule_diff((Gitg.StageStatusSubmodule)sitems[0]);
			}
			else if (type == Sidebar.Item.Type.STAGED)
			{
				show_staged_diff(sitems);
			}
			else
			{
				show_unstaged_diff(sitems);
			}
		}

		private void on_stage_selected_items()
		{
			var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
			Sidebar.Item.Type type;

			var sitems = items_for_items(sel, out type);

			if (sitems.length != 0 && (type == Sidebar.Item.Type.UNSTAGED ||
			                           type == Sidebar.Item.Type.UNTRACKED))
			{
				on_unstaged_activated(sitems);
			}
		}

		private void on_unstage_selected_items()
		{
			var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
			Sidebar.Item.Type type;

			var sitems = items_for_items(sel, out type);

			if (sitems.length != 0 && type == Sidebar.Item.Type.STAGED)
			{
				on_staged_activated(sitems);
			}
		}

		private void build_ui()
		{
			d_main = new Paned();

			d_main.diff_view.options_changed.connect(() => {
				if (d_update_diff_callback != null)
				{
					d_update_diff_callback();
				}
			});

			d_main.diff_view.repository = application.repository;
			d_main.diff_view.default_collapse_all = false;

			d_main.sidebar.deselected.connect(() => {
				d_main.diff_view.diff = null;
			});

			d_main.sidebar.stage_selection.connect(on_stage_selected_items);
			d_main.sidebar.unstage_selection.connect(on_unstage_selected_items);

			d_main.sidebar.discard_selection.connect(() => {
				var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
				Sidebar.Item.Type type;

				var sitems = items_for_items(sel, out type);

				if (sitems.length != 0 && type == Sidebar.Item.Type.UNSTAGED)
				{
					on_discard_menu_activated(sitems);
				}
			});

			d_main.sidebar.edit_selection.connect(() => {
				var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
				Sidebar.Item.Type type;

				var sitems = items_for_items(sel, out type);
				do_edit_items(sitems);
			});

			d_main.sidebar.selected_items_changed.connect(sidebar_selection_changed);

			d_main.button_commit.clicked.connect(() => {
				on_commit_clicked();
			});

			d_main.button_stage.clicked.connect(() => {
				on_stage_clicked();
			});

			d_main.button_discard.clicked.connect(() => {
				on_discard_clicked();
			});

			d_main.submodule_diff_view.info.request_open_repository.connect((submodule) => {
				try
				{
					var app = application.open_new(submodule.open(), "commit");

					((Gtk.Window)app).delete_event.connect(() => {
						reload();
						return false;
					});
				}
				catch (Error e)
				{
					// TODO: show error message
					stderr.printf("Failed to open submodule repository: %s\n", e.message);
				}
			});

			d_main.sidebar.populate_popup.connect(do_populate_menu);

			var view = d_main.submodule_history_view.commit_list_view;
			var model = new Gitg.CommitModel(null);
			view.model = model;

			model.row_inserted.connect_after((model, path, iter) => {
				if (d_submodule_history_select_first)
				{
					d_submodule_history_select_first = false;
					view.get_selection().select_path(path);
				}
			});

			view.get_selection().changed.connect((selection) => {
				Gtk.TreeModel m;
				Gtk.TreeIter iter;

				if (selection.get_selected(out m, out iter))
				{
					submodule_history_selection_changed(model.commit_from_iter(iter));
				}
				else
				{
					submodule_history_selection_changed(null);
				}
			});

			view.row_activated.connect((view, path, column) => {
				d_stage_unstage_submodule_commit_callback(model.commit_from_path(path));
			});

			var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.commit.diff");

			settings.bind("context-lines",
			              d_main.diff_view,
			              "context-lines",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("tab-width",
			              d_main.diff_view,
			              "tab-width",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

			settings.bind("use-gravatar",
			              d_main.diff_view,
			              "use-gravatar",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("enable-diff-highlighting",
			              d_main.diff_view,
			              "highlight",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			d_main.diff_view.bind_property("has-selection",
			                               d_main.button_stage,
			                               "sensitive",
			                               BindingFlags.DEFAULT);

			d_main.diff_view.bind_property("has-selection",
			                               d_main.button_discard,
			                               "sensitive",
			                               BindingFlags.DEFAULT);

			application.bind_property("repository",
			                          d_main.diff_view,
			                          "repository",
			                          BindingFlags.SYNC_CREATE);
		}
	}
}

// ex: ts=4 noet
