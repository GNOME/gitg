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

		public GitgExt.Application? application { owned get; construct set; }

		public Activity(GitgExt.Application application)
		{
			Object(application: application);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Activities/Commit"; }
		}

		public bool supports_search
		{
			get { return false; }
		}

		[Notify]
		public Gitg.Repository repository
		{
			set
			{
				reload();
			}
		}

		construct
		{
			application.bind_property("repository", this,
			                          "repository", BindingFlags.DEFAULT);
		}

		public string display_name
		{
			owned get { return _("Commit"); }
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

		private delegate void StageUnstageCallback(Sidebar.File f);

		private delegate void UpdateDiffCallback();
		private UpdateDiffCallback? d_update_diff_callback;

		private void show_unstaged_diff(Gitg.StageStatusFile[] files)
		{
			var stage = application.repository.stage;

			stage.diff_workdir_all.begin(files, d_main.diff_view.options, (obj, res) => {
				try
				{
					var d = stage.diff_workdir_all.end(res);

					d_main.diff_view.unstaged = true;
					d_main.diff_view.staged = false;

					d_main.button_stage.label = _("_Stage selection");
					d_main.button_discard.visible = true;

					d_main.diff_view.diff = d;
				}
				catch
				{
					// TODO: show error in diff
					d_main.diff_view.diff = null;
				}
			});

			d_update_diff_callback = () => {
				show_unstaged_diff(files);
			};
		}

		private async void stage_files(owned Gitg.StageStatusFile[] files)
		{
			var stage = application.repository.stage;

			foreach (var f in files)
			{
				if ((f.flags & Ggit.StatusFlags.WORKING_TREE_DELETED) != 0)
				{
					try
					{
						yield stage.delete_path(f.path);
					}
					catch (Error e)
					{
						var msg = _("Failed to stage the removal of file `%s'").printf(f.path);
						application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

						break;
					}
				}
				else
				{
					try
					{
						yield stage.stage_path(f.path);
					}
					catch (Error e)
					{
						var msg = _("Failed to stage the file `%s'").printf(f.path);
						application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

						break;
					}
				}
			}

			reload();
		}

		private void on_unstaged_activated(Gitg.StageStatusFile[] files)
		{
			stage_files.begin(files, (obj, res) => {
				stage_files.end(res);
			});
		}

		private void show_staged_diff(Gitg.StageStatusFile[] files)
		{
			var stage = application.repository.stage;

			stage.diff_index_all.begin(files, d_main.diff_view.options, (obj, res) => {
				try
				{
					var d = stage.diff_index_all.end(res);

					d_main.diff_view.unstaged = false;
					d_main.diff_view.staged = true;

					d_main.button_stage.label = _("_Unstage selection");
					d_main.button_discard.visible = false;

					d_main.diff_view.diff = d;
				}
				catch
				{
					// TODO: error reporting
					d_main.diff_view.diff = null;
				}
			});

			d_update_diff_callback = () => {
				show_staged_diff(files);
			};
		}

		private async void unstage_files(owned Gitg.StageStatusFile[] files)
		{
			var stage = application.repository.stage;

			foreach (var f in files)
			{
				if ((f.flags & Ggit.StatusFlags.INDEX_NEW) != 0)
				{
					try
					{
						yield stage.delete_path(f.path);
					}
					catch (Error e)
					{
						var msg = _("Failed to unstage the removal of file `%s'").printf(f.path);
						application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

						break;
					}
				}
				else
				{
					try
					{
						yield stage.unstage_path(f.path);
					}
					catch (Error e)
					{
						var msg = _("Failed to unstage the file `%s'").printf(f.path);
						application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);

						break;
					}
				}
			}

			reload();
		}

		private void on_staged_activated(Gitg.StageStatusFile[] files)
		{
			unstage_files.begin(files, (obj, res) => {
				unstage_files.end(res);
			});
		}

		private Sidebar.File[] append_files(Gitg.SidebarStore      model,
		                                    Gitg.StageStatusFile[] files,
		                                    Sidebar.File.Type      type,
		                                    Gee.HashSet<string>?   selected_paths,
		                                    StageUnstageCallback?  callback)
		{
			var ret = new Sidebar.File[0];

			foreach (var f in files)
			{
				var item = new Sidebar.File(f, type);

				if (selected_paths != null && selected_paths.contains(f.path))
				{
					ret += item;
				}

				item.activated.connect((numclick) => {
					callback(item);
				});

				model.append(item);
			}

			return ret;
		}

		private void reload()
		{
			var repository = application.repository;

			if (repository == null || d_reloading)
			{
				return;
			}

			d_reloading = true;

			var sb = d_main.sidebar;
			var model = sb.model;

			Sidebar.File.Type selected_type;
			Gitg.StageStatusFile[] selected_files;

			selected_files = files_for_items(sb.get_selected_items<Gitg.SidebarItem>(),
			                                 out selected_type);

			var selected_paths = new Gee.HashSet<string>();

			foreach (var f in selected_files)
			{
				selected_paths.add(f.path);
			}

			// Preload author avatar
			try
			{
				var author = get_signature("AUTHOR");
				var ac = Gitg.AvatarCache.default();

				ac.load.begin(author.get_email(), null, (obj, res) => {
					ac.load.end(res);
				});
			} catch {}

			var stage = repository.stage;

			var opts = Ggit.StatusOption.INCLUDE_UNTRACKED |
			           Ggit.StatusOption.RECURSE_UNTRACKED_DIRS |
			           Ggit.StatusOption.SORT_CASE_INSENSITIVELY |
			           Ggit.StatusOption.EXCLUDE_SUBMODULES |
			           Ggit.StatusOption.DISABLE_PATHSPEC_MATCH;

			var show = Ggit.StatusShow.INDEX_AND_WORKDIR;

			var options = new Ggit.StatusOptions(opts, show, null);
			var enumerator = stage.file_status(options);

			var indexflags = Ggit.StatusFlags.INDEX_NEW |
			                 Ggit.StatusFlags.INDEX_MODIFIED |
			                 Ggit.StatusFlags.INDEX_DELETED |
			                 Ggit.StatusFlags.INDEX_RENAMED |
			                 Ggit.StatusFlags.INDEX_TYPECHANGE;

			var workflags = Ggit.StatusFlags.WORKING_TREE_MODIFIED |
			                Ggit.StatusFlags.WORKING_TREE_DELETED |
			                Ggit.StatusFlags.WORKING_TREE_TYPECHANGE;

			var untrackedflags = Ggit.StatusFlags.WORKING_TREE_NEW;

			enumerator.next_files.begin(-1, (obj, res) => {
				var files = enumerator.next_files.end(res);

				var staged = new Gitg.StageStatusFile[files.length];
				staged.length = 0;

				var unstaged = new Gitg.StageStatusFile[files.length];
				unstaged.length = 0;

				var untracked = new Gitg.StageStatusFile[files.length];
				untracked.length = 0;

				foreach (var f in files)
				{
					if ((f.flags & indexflags) != 0)
					{
						staged += f;
					}

					if ((f.flags & workflags) != 0)
					{
						unstaged += f;
					}

					if ((f.flags & untrackedflags) != 0)
					{
						untracked += f;
					}
				}

				model.clear();
				d_main.diff_view.diff = null;

				var staged_header = model.begin_header(_("Staged"), (uint)Sidebar.File.Type.STAGED);

				var current_staged = new Sidebar.File[0];
				var current_unstaged = new Sidebar.File[0];

				if (staged.length == 0)
				{
					model.append_dummy(_("No staged files"));
				}
				else
				{
					current_staged = append_files(model,
					                              staged,
					                              Sidebar.File.Type.STAGED,
					                              selected_paths,
					                              (f) => {
						                                on_staged_activated(new Gitg.StageStatusFile[] {f.file});
					                              });
				}

				model.end_header();

				var unstaged_header = model.begin_header(_("Unstaged"), (uint)Sidebar.File.Type.UNSTAGED);

				if (unstaged.length == 0)
				{
					model.append_dummy(_("No unstaged files"));
				}
				else
				{
					current_unstaged = append_files(model,
					                                unstaged,
					                                Sidebar.File.Type.UNSTAGED,
					                                selected_paths,
					                                (f) => {
						                                on_unstaged_activated(new Gitg.StageStatusFile[] {f.file});
					                                });
				}

				model.end_header();

				model.begin_header(_("Untracked"), (uint)Sidebar.File.Type.UNTRACKED);

				if (untracked.length == 0)
				{
					model.append_dummy(_("No untracked files"));
				}
				else
				{
					append_files(model,
					             untracked,
					             Sidebar.File.Type.UNTRACKED,
					             null,
					             (f) => {
					                 on_unstaged_activated(new Gitg.StageStatusFile[] {f.file});
					             });
				}

				model.end_header();

				d_main.sidebar.expand_all();
				d_has_staged = staged.length != 0;

				d_reloading = false;

				if (selected_paths.size != 0)
				{
					Sidebar.File[] sel;

					if (selected_type == Sidebar.File.Type.STAGED)
					{
						sel = (current_staged.length != 0) ? current_staged : current_unstaged;
					}
					else
					{
						sel = (current_unstaged.length != 0) ? current_unstaged : current_staged;
					}

					if (sel.length != 0)
					{
						foreach (var item in sel)
						{
							d_main.sidebar.select(item);
						}
					}
					else if (selected_type == Sidebar.File.Type.STAGED)
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
					// Select unstaged header
					d_main.sidebar.select(unstaged_header);
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
				                 Gtk.MessageType.INFO);
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

			stage.commit.begin(dlg.pretty_message,
			                   author,
			                   committer,
			                   opts, (obj, res) => {
				try
				{
					stage.commit.end(res);
					reload();
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

			var stage = application.repository.stage;

			Ggit.Tree tree;

			try
			{
				tree = yield stage.get_head_tree();
			}
			catch { return null; }

			Ggit.Diff? diff = null;

			try
			{
				var index = application.repository.get_index();

				yield Gitg.Async.thread(() => {
					diff = new Ggit.Diff.tree_to_index(application.repository,
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
			var dlg = new Dialog(author, diff);

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
							if (dlg.message.strip() == "")
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
			string? user = null;
			string? email = null;
			Ggit.Signature? committer = null;
			Ggit.Signature? author = null;

			try
			{
				committer = get_signature("COMMITTER");
				author = get_signature("AUTHOR");

				user = committer.get_name();
				email = committer.get_email();

				if (user == "")
				{
					user = null;
				}

				if (email == "")
				{
					email = null;
				}
			}
			catch {}

			if (user == null || email == null)
			{
				string secmsg;

				if (user == null && email == null)
				{
					secmsg = _("Your user name and email are not configured yet. Please go to the user configuration and provide your name and email.");
				}
				else if (user == null)
				{
					secmsg = _("Your user name is not configured yet. Please go to the user configuration and provide your name.");
				}
				else
				{
					secmsg = _("Your email is not configured yet. Please go to the user configuration and provide your email.");
				}
			
				// TODO: better to show user info dialog directly or something
				application.show_infobar(_("Failed to pass pre-commit"),
				                         secmsg,
				                         Gtk.MessageType.ERROR);

				return;
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
			var selection = yield d_main.diff_view.get_selection();
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
			var selection = yield d_main.diff_view.get_selection();
			var stage = application.repository.stage;

			foreach (var pset in selection)
			{
				yield stage.revert_patch(pset);
			}
		}

		private void on_discard_clicked()
		{
			var primary = _("Discard changes");
			var secondary = _("Are you sure you want to permanently discard the selected changes?").printf();

			var q = new GitgExt.UserQuery();

			q.title = primary;
			q.message = secondary;
			q.message_type = Gtk.MessageType.QUESTION;

			q.responses = new GitgExt.UserQueryResponse[] {
				new GitgExt.UserQueryResponse(_("Discard"), Gtk.ResponseType.OK),
				new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL)
			};

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

		private async void revert_paths(string[] paths) throws Error
		{
			var stage = application.repository.stage;

			foreach (var path in paths)
			{
				yield stage.revert_path(path);
			}
		}

		private bool do_discard_files(GitgExt.UserQuery q, Gitg.StageStatusFile[] files)
		{
			application.busy = true;

			var paths = new string[files.length];

			for (var i = 0; i < files.length; i++)
			{
				paths[i] = files[i].path;
			}

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

		private void on_discard_menu_activated(Gitg.StageStatusFile[] files)
		{
			var primary = _("Discard changes");
			string secondary;

			if (files.length == 1)
			{
				secondary = _("Are you sure you want to permanently discard all changes made to the file `%s'?").printf(files[0].path);
			}
			else
			{
				var paths = new string[files.length - 1];

				for (var i = 0; i < files.length - 1; i++)
				{
					paths[i] = @"`$(files[i].path)'";
				}

				secondary = _("Are you sure you want to permanently discard all changes made to the files %s and `%s'?").printf(string.joinv(", ", paths), files[files.length - 1].path);
			}

			var q = new GitgExt.UserQuery();

			q.title = primary;
			q.message = secondary;
			q.message_type = Gtk.MessageType.QUESTION;

			q.responses = new GitgExt.UserQueryResponse[] {
				new GitgExt.UserQueryResponse(_("Discard"), Gtk.ResponseType.OK),
				new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL)
			};

			q.default_response = Gtk.ResponseType.OK;

			q.response.connect((w, r) => {
				if (r == Gtk.ResponseType.OK)
				{
					return do_discard_files(q, files);
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

			Sidebar.File.Type type;

			var files = files_for_items(items, out type);

			if (type == Sidebar.File.Type.UNSTAGED ||
			    type == Sidebar.File.Type.UNTRACKED)
			{
				var stage = new Gtk.MenuItem.with_mnemonic(_("_Stage changes"));
				menu.append(stage);

				stage.activate.connect(() => {
					on_unstaged_activated(files);
				});
			}

			if (type == Sidebar.File.Type.STAGED)
			{
				var stage = new Gtk.MenuItem.with_mnemonic(_("_Unstage changes"));
				menu.append(stage);

				stage.activate.connect(() => {
					on_staged_activated(files);
				});
			}

			if (type == Sidebar.File.Type.UNSTAGED)
			{
				var discard = new Gtk.MenuItem.with_mnemonic(_("_Discard changes"));
				menu.append(discard);

				discard.activate.connect(() => {
					on_discard_menu_activated(files);
				});
			}
		}

		private Gitg.StageStatusFile[] files_to_stage_files(Sidebar.File[] files)
		{
			var ret = new Gitg.StageStatusFile[files.length];

			for (var i = 0; i < ret.length; i++)
			{
				ret[i] = files[i].file;
			}

			return ret;
		}

		private Gitg.StageStatusFile[] stage_status_files_of_type(Sidebar.File.Type type)
		{
			return files_to_stage_files(d_main.sidebar.items_of_type(type));
		}

		private Gitg.StageStatusFile[] files_for_items(Gitg.SidebarItem[] items, out Sidebar.File.Type type)
		{
			var files = new Gitg.StageStatusFile[items.length];
			files.length = 0;

			type = Sidebar.File.Type.NONE;

			foreach (var item in items)
			{
				var header = item as Gitg.SidebarStore.SidebarHeader;

				if (header != null)
				{
					type = (Sidebar.File.Type)header.id;
					return stage_status_files_of_type(type);
				}

				var file = item as Sidebar.File;

				if (file != null)
				{
					files += file.file;
					type = file.stage_type;
				}
			}

			return files;
		}

		private void sidebar_selection_changed(Gitg.SidebarItem[] items)
		{
			Sidebar.File.Type type;

			var files = files_for_items(items, out type);

			if (files.length == 0)
			{
				d_main.diff_view.diff = null;
				return;
			}

			if (type == Sidebar.File.Type.STAGED)
			{
				show_staged_diff(files);
			}
			else
			{
				show_unstaged_diff(files);
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

			d_main.sidebar.deselected.connect(() => {
				d_main.diff_view.diff = null;
			});

			d_main.sidebar.stage_selection.connect(() => {
				var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
				Sidebar.File.Type type;

				var files = files_for_items(sel, out type);

				if (files.length != 0 && (type == Sidebar.File.Type.UNSTAGED ||
				                          type == Sidebar.File.Type.UNTRACKED))
				{
					on_unstaged_activated(files);
				}
			});

			d_main.sidebar.unstage_selection.connect(() => {
				var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
				Sidebar.File.Type type;

				var files = files_for_items(sel, out type);

				if (files.length != 0 && type == Sidebar.File.Type.STAGED)
				{
					on_staged_activated(files);
				}
			});

			d_main.sidebar.discard_selection.connect(() => {
				var sel = d_main.sidebar.get_selected_items<Gitg.SidebarItem>();
				Sidebar.File.Type type;

				var files = files_for_items(sel, out type);

				if (files.length != 0 && type == Sidebar.File.Type.UNSTAGED)
				{
					on_discard_menu_activated(files);
				}
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

			d_main.sidebar.populate_popup.connect(do_populate_menu);

			var settings = new Settings("org.gnome.gitg.preferences.commit.diff");

			settings.bind("context-lines",
			              d_main.diff_view,
			              "context-lines",
			              SettingsBindFlags.GET |
			              SettingsBindFlags.SET);

			settings.bind("tab-width",
			              d_main.diff_view,
			              "tab-width",
			              SettingsBindFlags.GET |
			              SettingsBindFlags.SET);

			d_main.diff_view.bind_property("has-selection",
			                               d_main.button_stage,
			                               "sensitive",
			                               BindingFlags.DEFAULT);

			d_main.diff_view.bind_property("has-selection",
			                               d_main.button_discard,
			                               "sensitive",
			                               BindingFlags.DEFAULT);
		}
	}
}

// ex: ts=4 noet
