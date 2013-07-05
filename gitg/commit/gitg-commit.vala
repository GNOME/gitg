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

		public GitgExt.Application? application { owned get; construct set; }

		public Activity(GitgExt.Application application)
		{
			Object(application: application);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Activities/Commit"; }
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

		construct
		{
			application.bind_property("repository", this,
			                          "repository", BindingFlags.DEFAULT);
		}

		public string display_name
		{
			owned get { return _("Commit"); }
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

		private string? icon_for_status(Ggit.StatusFlags status)
		{
			if ((status & (Ggit.StatusFlags.INDEX_NEW |
			               Ggit.StatusFlags.WORKING_TREE_NEW)) != 0)
			{
				return "document-new";
			}
			else if ((status & (Ggit.StatusFlags.INDEX_MODIFIED |
			                    Ggit.StatusFlags.INDEX_RENAMED |
			                    Ggit.StatusFlags.INDEX_TYPECHANGE |
			                    Ggit.StatusFlags.WORKING_TREE_MODIFIED |
			                    Ggit.StatusFlags.WORKING_TREE_TYPECHANGE)) != 0)
			{
				return "gtk-edit";
			}
			else if ((status & (Ggit.StatusFlags.INDEX_DELETED |
			                    Ggit.StatusFlags.WORKING_TREE_DELETED)) != 0)
			{
				return "edit-delete";
			}

			return null;
		}

		private delegate void StageUnstageCallback(Gitg.StageStatusFile f, int numclick);

		private void show_unstaged_diff(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.diff_workdir.begin(f, (obj, res) => {
				try
				{
					var d = stage.diff_workdir.end(res);

					d_main.diff_view.unstaged = true;
					d_main.diff_view.staged = false;

					d_main.diff_view.diff = d;
				}
				catch
				{
					// TODO: show error in diff
					d_main.diff_view.diff = null;
				}
			});
		}

		private void stage_file(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.stage_path.begin(f.path, (obj, res) => {
				try
				{
					stage.stage_path.end(res);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the file `%s'").printf(f.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}

				reload();
			});
		}

		private void delete_file(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.delete_path.begin(f.path, (obj, res) => {
				try
				{
					stage.delete_path.end(res);
				}
				catch (Error e)
				{
					var msg = _("Failed to stage the removal of file `%s'").printf(f.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}

				reload();
			});
		}

		private void on_unstaged_activated(Gitg.StageStatusFile f, int numclick)
		{
			if (numclick == 1)
			{
				show_unstaged_diff(f);
			}
			else
			{
				if ((f.flags & Ggit.StatusFlags.WORKING_TREE_DELETED) != 0)
				{
					delete_file(f);
				}
				else
				{
					stage_file(f);
				}
			}
		}

		private void show_staged_diff(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.diff_index.begin(f, (obj, res) => {
				try
				{
					var d = stage.diff_index.end(res);

					d_main.diff_view.unstaged = false;
					d_main.diff_view.staged = true;

					d_main.diff_view.diff = d;
				}
				catch
				{
					// TODO: error reporting
					d_main.diff_view.diff = null;
				}
			});
		}

		private void delete_index_file(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.revert_index_path.begin(f.path, (obj, res) => {
				try
				{
					stage.revert_index_path.end(res);
				}
				catch (Error e)
				{
					var msg = _("Failed to unstage the removal of file `%s'").printf(f.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}

				reload();
			});
		}

		private void unstage_file(Gitg.StageStatusFile f)
		{
			var stage = application.repository.stage;

			stage.unstage_path.begin(f.path, (obj, res) => {
				try
				{
					stage.unstage_path.end(res);
				}
				catch (Error e)
				{
					var msg = _("Failed to unstage the file `%s'").printf(f.path);
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}

				reload();
			});
		}

		private void on_staged_activated(Gitg.StageStatusFile f, int numclick)
		{
			if (numclick == 1)
			{
				show_staged_diff(f);
			}
			else
			{
				if ((f.flags & Ggit.StatusFlags.INDEX_DELETED) != 0)
				{
					delete_index_file(f);
				}
				else
				{
					unstage_file(f);
				}
			}
		}

		private void append_files(Gitg.SidebarStore      model,
		                          Gitg.StageStatusFile[] files,
		                          StageUnstageCallback?  callback)
		{
			foreach (var f in files)
			{
				model.append_normal(f.path, null, icon_for_status(f.flags), (numclick) => {
					if (callback != null)
					{
						callback(f, numclick);
					}
				});
			}
		}

		public void reload()
		{
			var model = d_main.sidebar.model;

			var stage = application.repository.stage;

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

			var workflags = Ggit.StatusFlags.WORKING_TREE_NEW |
			                Ggit.StatusFlags.WORKING_TREE_MODIFIED |
			                Ggit.StatusFlags.WORKING_TREE_DELETED |
			                Ggit.StatusFlags.WORKING_TREE_TYPECHANGE;

			enumerator.next_files.begin(-1, (obj, res) => {
				var files = enumerator.next_files.end(res);

				var staged = new Gitg.StageStatusFile[files.length];
				staged.length = 0;

				var unstaged = new Gitg.StageStatusFile[files.length];
				unstaged.length = 0;

				foreach (var f in files)
				{
					if ((f.flags & indexflags) != 0)
					{
						staged += f;
					}
					else if ((f.flags & workflags) != 0)
					{
						unstaged += f;
					}
				}

				model.clear();
				d_main.diff_view.diff = null;

				model.begin_header(_("Staged"));

				if (staged.length == 0)
				{
					model.append_dummy(_("No staged files"));
				}
				else
				{
					append_files(model, staged, on_staged_activated);
				}

				model.end_header();

				model.begin_header(_("Unstaged"));

				if (unstaged.length == 0)
				{
					model.append_dummy(_("No unstaged files"));
				}
				else
				{
					append_files(model, unstaged, on_unstaged_activated);
				}

				model.end_header();

				d_main.sidebar.expand_all();

				if (staged.length == 0)
				{
					d_main.label_commit_summary.label = _("No files staged to be committed.");
					d_main.button_commit.sensitive = false;
				}
				else
				{
					d_main.label_commit_summary.label =
						ngettext(_("1 file staged to be committed."),
						         _("%d files staged to be commited.").printf(staged.length),
						         staged.length);

					d_main.button_commit.sensitive = true;
				}
			});
		}

		public void activate()
		{
			reload();
		}

		private void do_commit(Dialog dlg)
		{
			var stage = application.repository.stage;

			Gitg.StageCommitOptions opts = 0;

			if (dlg.amend)
			{
				opts |= Gitg.StageCommitOptions.AMEND;
			}

			

			if (dlg.sign_off)
			{
				opts |= Gitg.StageCommitOptions.SIGN_OFF;
			}

			stage.commit.begin(dlg.message, opts, (obj, res) => {
				try
				{
					var o = stage.commit.end(res);
				}
				catch (Error e)
				{
					var msg = _("Failed to commit");
					application.show_infobar(msg, e.message, Gtk.MessageType.ERROR);
				}
			});
		}

		private void on_commit_clicked()
		{
			var dlg = new Dialog();

			dlg.set_transient_for((Gtk.Window)d_main.get_toplevel());
			dlg.set_default_response(Gtk.ResponseType.OK);

			dlg.response.connect((d, id) => {
				if (id == Gtk.ResponseType.OK)
				{
					do_commit(dlg);
				}
				else
				{
					d.destroy();
				}
			});

			dlg.show();
		}

		private void build_ui()
		{
			d_main = new Paned();

			d_main.sidebar.deselected.connect(() => {
				d_main.diff_view.diff = null;
			});

			d_main.button_commit.clicked.connect(() => {
				on_commit_clicked();
			});
		}
	}
}

// ex: ts=4 noet
