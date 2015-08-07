/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

namespace Gitg
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-dash-view.ui")]
class DashView : Gtk.Grid, GitgExt.UIElement, GitgExt.Activity, GitgExt.Selectable, GitgExt.Searchable
{
	private const string version = Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }

	private bool d_search_enabled;
	private bool d_setting_mode;

	[GtkChild( name = "introduction" )]
	private Gtk.Grid d_introduction;

	[GtkChild( name = "scrolled_window" )]
	private Gtk.ScrolledWindow d_scrolled_window;

	[GtkChild( name = "repository_list_box" )]
	private RepositoryListBox d_repository_list_box;

	[GtkChild( name = "action_bar" )]
	private Gtk.ActionBar d_action_bar;

	public GitgExt.SelectionMode selectable_mode
	{
		get
		{
			switch (d_repository_list_box.mode)
			{
			case Gitg.SelectionMode.NORMAL:
				return GitgExt.SelectionMode.NORMAL;
			case Gitg.SelectionMode.SELECTION:
				return GitgExt.SelectionMode.SELECTION;
			}

			return GitgExt.SelectionMode.NORMAL;
		}

		set
		{
			if (selectable_mode == value)
			{
				return;
			}

			d_setting_mode = true;

			switch (value)
			{
			case GitgExt.SelectionMode.NORMAL:
				d_repository_list_box.mode = Gitg.SelectionMode.NORMAL;
				d_action_bar.visible = true;
				break;
			case GitgExt.SelectionMode.SELECTION:
				d_repository_list_box.mode = Gitg.SelectionMode.SELECTION;
				d_action_bar.visible = false;
				break;
			}

			d_setting_mode = false;
		}
	}

	public bool has_repositories
	{
		get { return d_repository_list_box.get_children().length() != 0; }
	}

	public bool selectable_available
	{
		get { return has_repositories; }
	}

	public bool search_available
	{
		get { return has_repositories; }
	}

	public string display_name
	{
		owned get { return "Dash"; }
	}

	public string description
	{
		owned get { return "Dash view"; }
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/dash"; }
	}

	public Gtk.Widget? widget
	{
		owned get { return this; }
	}

	public string? icon
	{
		owned get { return null; }
	}

	private string d_search_text;

	public string search_text
	{
		owned get { return d_search_text; }

		set
		{
			if (d_search_text != value)
			{
				d_search_text = value;
				update_search_text();
			}
		}

		default = "";
	}

	public Gtk.Entry? search_entry
	{
		set {}
	}

	public bool search_visible { get; set; }

	public bool search_enabled
	{
		get { return d_search_enabled; }
		set
		{
			if (d_search_enabled != value)
			{
				d_search_enabled = value;
				update_search_text();
			}
		}
	}

	private void update_search_text()
	{
		if (d_repository_list_box != null)
		{
			if (d_search_enabled && d_search_text != "")
			{
				d_repository_list_box.filter_text(d_search_text);
			}
			else
			{
				d_repository_list_box.filter_text(null);
			}
		}
	}

	public Gtk.Widget? action_widget
	{
		owned get
		{
			var ab = new Gtk.ActionBar();

			var del = new Gtk.Button.with_mnemonic(_("_Delete"));
			del.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

			del.sensitive = false;
			del.show();

			del.clicked.connect(() => {
				foreach (var sel in d_repository_list_box.selection)
				{
					sel.request_remove();
				}

				selectable_mode = GitgExt.SelectionMode.NORMAL;
			});

			d_repository_list_box.bind_property("has-selection", del, "sensitive");

			ab.pack_end(del);

			return ab;

		}
	}

	construct
	{
		d_repository_list_box.notify["mode"].connect(() => {
			if (!d_setting_mode)
			{
				d_action_bar.visible = (selectable_mode == GitgExt.SelectionMode.NORMAL);
				notify_property("selectable-mode");
			}
		});

		d_repository_list_box.repository_activated.connect((repository) => {
			application.repository = repository;
		});

		d_repository_list_box.show_error.connect((primary_message, secondary_message) => {
			application.show_infobar(primary_message, secondary_message, Gtk.MessageType.ERROR);
		});

		bind_property("has-repositories",
		              d_scrolled_window,
		              "visible",
		              BindingFlags.SYNC_CREATE);

		bind_property("has-repositories",
		              d_introduction,
		              "visible",
		              BindingFlags.SYNC_CREATE |
		              BindingFlags.INVERT_BOOLEAN);

		d_repository_list_box.add.connect(update_availability);
		d_repository_list_box.remove.connect(update_availability);
	}

	private void update_availability()
	{
		notify_property("has-repositories");
		notify_property("selectable-available");
		notify_property("search-available");
	}

	public RepositoryListBox.Row? add_repository(Repository repository)
	{
		return d_repository_list_box.add_repository(repository);
	}

	class CloneCallbacks : Ggit.RemoteCallbacks
	{
		private RepositoryListBox.Row d_row;
		private CredentialsManager d_credentials;

		public CloneCallbacks(GitgExt.Application application, Ggit.Config? config, RepositoryListBox.Row row)
		{
			d_row = row;
			d_credentials = new CredentialsManager(config, application as Gtk.Window, false);
		}

		protected override void transfer_progress(Ggit.TransferProgress stats)
		{
			var recvobj = stats.get_received_objects();
			var indxobj = stats.get_indexed_objects();
			var totaobj = stats.get_total_objects();

			Idle.add(() => {
				d_row.fraction = (recvobj + indxobj) / (double)(2 * totaobj);
				return false;
			});
		}

		protected override Ggit.Cred? credentials(string url, string? username_from_url, Ggit.Credtype allowed_types) throws Error
		{
			return d_credentials.credentials(url, username_from_url, allowed_types);
		}
	}

	private async Repository? clone(RepositoryListBox.Row row, string url, File location, bool is_bare) throws Error
	{
		Repository? repository = null;

		yield Async.thread(() => {
			var clone_options = new Ggit.CloneOptions();
			var fetch_options = new Ggit.FetchOptions();
			Ggit.Config? config = null;

			try
			{
				config = new Ggit.Config.default();
			} catch {}

			fetch_options.set_remote_callbacks(new CloneCallbacks(application, config, row));

			clone_options.set_is_bare(is_bare);
			clone_options.set_fetch_options(fetch_options);

			repository = (Repository)Ggit.Repository.clone(url, location, clone_options);
		});

		return repository;
	}

	private void clone_repository(string url, File location, bool is_bare)
	{
		// create subfolder
		var pos = url.last_index_of_char('/');

		if (pos == -1)
		{
			pos = url.last_index_of_char(':');
		}

		var dot_git_suffix = ".git";
		var subfolder_name = url.substring(pos + 1);
		var has_dot_git = subfolder_name.has_suffix(dot_git_suffix);

		if (has_dot_git && !is_bare)
		{
			subfolder_name = subfolder_name.slice(0, - dot_git_suffix.length);
		}
		else if (!has_dot_git && is_bare)
		{
			subfolder_name += dot_git_suffix;
		}

		var subfolder = location.resolve_relative_path(subfolder_name);

		// Clone
		var row = d_repository_list_box.begin_cloning(subfolder_name);

		clone.begin(row, url, subfolder, is_bare, (obj, res) => {
			Gitg.Repository? repository = null;

			try
			{
				repository = clone.end(res);
			}
			catch (Error e)
			{
				application.show_infobar(_("Failed to clone repository"), e.message, Gtk.MessageType.ERROR);
			}

			d_repository_list_box.end_cloning(row, repository);
		});
	}

	[GtkCallback]
	private void clone_repository_clicked()
	{
		var dlg = new CloneDialog(application as Gtk.Window);

		dlg.response.connect((d, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				clone_repository(dlg.url, dlg.location, dlg.is_bare);
			}

			d.destroy();
		});

		dlg.show();
	}

	private void finish_add_repository(Repository repo)
	{
		var row = add_repository(repo);

		if (row != null)
		{
			row.grab_focus();
			d_repository_list_box.grab_focus();
			row.grab_focus();
		}
	}

	private void do_add_repository(File location)
	{
		Repository repo;

		try
		{
			repo = new Repository(location, null);
		}
		catch (Error err)
		{
			application.show_infobar(_("Failed to add repository"), err.message, Gtk.MessageType.ERROR);
			return;
		}

		finish_add_repository(repo);
	}

	private void query_create_repository(File location)
	{
		var q = new GitgExt.UserQuery();
		var name = Utils.replace_home_dir_with_tilde(location);

		name = Markup.escape_text(name);

		q.title = _("Create new repository");

		// Translators: %s is a file name
		q.message = _("The location <i>%s</i> does not appear to be a valid git repository. Would you like to initialize a new git repository at this location?").printf(name);
		q.message_type = Gtk.MessageType.QUESTION;
		q.message_use_markup = true;

		q.responses = new GitgExt.UserQueryResponse[] {
			new GitgExt.UserQueryResponse(_("_Cancel"), Gtk.ResponseType.CANCEL),
			new GitgExt.UserQueryResponse(_("Create repository"), Gtk.ResponseType.OK)
		};

		q.default_response = Gtk.ResponseType.OK;

		q.response.connect((w, r) => {
			if (r == Gtk.ResponseType.OK)
			{
				Repository repo;

				try
				{
					repo = Repository.init_repository(location, false);
				}
				catch (Error err)
				{
					application.show_infobar(_("Failed to create repository"), err.message, Gtk.MessageType.ERROR);
					return true;
				}

				finish_add_repository(repo);
			}

			return true;
		});

		application.user_query(q);
	}

	[GtkCallback]
	private void add_repository_clicked()
	{
		var chooser = new Gtk.FileChooserDialog(_("Add Repository"),
		                                        application as Gtk.Window,
		                                        Gtk.FileChooserAction.SELECT_FOLDER,
		                                        _("_Cancel"), Gtk.ResponseType.CANCEL,
		                                        _("_Add"), Gtk.ResponseType.OK);

		chooser.modal = true;
		chooser.set_default_response(Gtk.ResponseType.OK);

		chooser.response.connect((c, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				var file = chooser.get_file();

				if (file == null)
				{
					file = chooser.get_current_folder_file();
				}

				if (!file.get_child(".git").query_exists())
				{
					query_create_repository(file);
				}
				else
				{
					do_add_repository(file);
				}
			}

			c.destroy();
		});

		chooser.show();
	}
}

}

// ex:ts=4 noet
