/*
 * This file is part of gitg
 *
 * Copyright (C) 2012-2016 - Ignacio Casal Quinteiro
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
	public enum SelectionMode
	{
		NORMAL,
		SELECTION
	}

	public enum DeleteSources
	{
		CANCEL,
		TRASH,
		DELETE
	}

	public class RepositoryListBox : Gtk.ListBox
	{
		private string? d_filter_text;

		public signal void repository_activated(Repository repository);
		public signal void show_error(string primary_message, string secondary_message);

		[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-repository-list-box-row.ui")]
		public class Row : Gtk.ListBoxRow
		{
			private Repository? d_repository;
			private DateTime d_time = new DateTime.now_local();
			private bool d_loading;
			[GtkChild]
			private unowned ProgressBin d_progress_bin;
			[GtkChild]
			private unowned Gtk.Label d_repository_label;
			[GtkChild]
			private unowned Gtk.Label d_description_label;
			[GtkChild]
			private unowned Gtk.Label d_branch_label;
			[GtkChild]
			private unowned Gtk.Spinner d_spinner;
			[GtkChild]
			private unowned Gtk.CheckButton d_remove_check_button;
			[GtkChild]
			private unowned Gtk.Revealer d_remove_revealer;
			[GtkChild]
			private unowned Gtk.Box d_languages_box;

			public signal void request_remove();
			public signal void request_delete_source();
			public signal void secondary_clicked ();

			private SelectionMode d_mode;
			private string? d_dirname;
			private string? d_branch_name;

			public SelectionMode mode
			{
				get { return d_mode; }

				set
				{
					if (d_mode != value)
					{
						d_mode = value;

						d_remove_revealer.reveal_child = (d_mode == SelectionMode.SELECTION);

						d_remove_check_button.active = false;
					}
				}
			}

			public new bool selected
			{
				get; set;
			}

			construct
			{
				d_remove_check_button.bind_property("active",
				                                    this,
				                                    "selected",
				                                    BindingFlags.BIDIRECTIONAL |
				                                    BindingFlags.SYNC_CREATE);
			}

			public Repository? repository
			{
				get { return d_repository; }
				set
				{
					d_repository = value;
					update_repository_data();
				}
			}

			public bool can_remove
			{
				get { return d_remove_check_button.sensitive; }
				set { d_remove_check_button.sensitive = value; }
			}

			public DateTime time
			{
				get { return d_time; }
				set { d_time = value; }
			}

			public double fraction
			{
				set { d_progress_bin.fraction = value; }
			}

			public string? repository_name
			{
				get { return d_repository_label.get_text(); }
				set { d_repository_label.label = value; }
			}

			public string? dirname
			{
				get { return d_dirname; }
				set
				{
					d_dirname = value;
					update_branch_label();
				}
			}

			public string? branch_name
			{
				get { return d_branch_name; }
				set
				{
					d_branch_name = "\"" + value + "\"";
					update_branch_label();
				}
			}

			private void update_branch_label()
			{
				if (d_branch_name == null || d_branch_name == "")
				{
					// Translators: this is used to construct: "at <directory>", to indicate where the repository is at.
					d_branch_label.label = _("at %s").printf(d_dirname);
				}
				else if (d_dirname == null || d_dirname == "")
				{
					d_branch_label.label = d_branch_name;
				}
				else
				{
					// Translators: this is used to construct: "<branch-name> at <directory>"
					d_branch_label.label = _("%s at %s").printf(d_branch_name, d_dirname);
				}
			}

			private void update_repository_data()
			{
				string head_name = "";
				string head_description = "";
				var doap = new Ide.Doap();

				if (d_repository != null)
				{
					try
					{
						var head = d_repository.get_head();
						head_name = head.parsed_name.shortname;

						var commit = (Ggit.Commit)head.lookup();
						var tree = commit.get_tree();

						Ggit.OId? entry_id = null;

						for (var i = 0; i < tree.size(); i++)
						{
							var entry = tree.get(i);
							var name = entry.get_name();

							if (name != null && name.has_suffix(".doap"))
							{
								entry_id = entry.get_id();
								break;
							}
						}

						if (entry_id != null)
						{
							var blob = d_repository.lookup<Ggit.Blob>(entry_id);

							unowned uint8[] content = blob.get_raw_content();
							doap.load_from_data((string)content, -1);

							head_description = doap.get_shortdesc();

							foreach (var lang in doap.get_languages())
							{
								var frame = new Gtk.Frame(null);
								frame.shadow_type = Gtk.ShadowType.NONE;
								frame.get_style_context().add_class("language-frame");
								frame.show();

								var label = new Gtk.Label(lang);
								var attr_list = new Pango.AttrList();
								attr_list.insert(Pango.attr_scale_new(Pango.Scale.SMALL));
								label.set_attributes(attr_list);
								label.show();

								frame.add(label);
								d_languages_box.add(frame);
							}
						}
					} catch {}
				}


				if (doap.get_name() != null)
				{
					repository_name = doap.get_name();
				} else {
					repository_name = d_repository != null ? d_repository.name : "";
				}

				d_description_label.label = head_description;
				d_description_label.visible = head_description != "";

				branch_name = head_name;
			}

			public bool loading
			{
				get { return d_loading; }
				set
				{
					d_loading = value;

					if (!d_loading)
					{
						d_spinner.stop();
						d_spinner.hide();
						d_progress_bin.fraction = 0;
					}
					else
					{
						d_spinner.show();
						d_spinner.start();
					}
				}
			}

			public Row(Repository? repository, string dirname)
			{
				Object(repository: repository, dirname: dirname);
			}

			protected override bool button_press_event(Gdk.EventButton event)
			{
				if (event.button == Gdk.BUTTON_SECONDARY) secondary_clicked ();

				return base.button_press_event (event);
			}
		}

		public SelectionMode mode { get; set; }

		public bool bookmarks_from_recent_files { get; set; default = true; }

		private File? d_location;
		private uint d_save_repository_bookmarks_id;
		private BookmarkFile d_bookmark_file;

		public File? location
		{
			get
			{
				return d_location;
			}

			set
			{
				if (d_save_repository_bookmarks_id != 0)
				{
					Source.remove(d_save_repository_bookmarks_id);
					save_repository_bookmarks();
				}

				d_location = value;
				d_bookmark_file = new BookmarkFile();

				try
				{
					d_bookmark_file.load_from_file(value.get_path());
				}
				catch (FileError e)
				{
					if (bookmarks_from_recent_files)
					{
						// First time create, copy over from recent file manager
						copy_bookmarks_from_recent_files();
					}
				}
				catch (Error e)
				{
					stderr.printf(@"Failed to read repository bookmarks: $(e.message)\n");
				}
			}
		}

		private void copy_bookmarks_from_recent_files()
		{
			var manager = Gtk.RecentManager.get_default();
			var items = manager.get_items();

			foreach (var item in items)
			{
				if (!item.has_group("gitg"))
				{
					continue;
				}

				var uri = item.get_uri();

				d_bookmark_file.set_mime_type(uri, item.get_mime_type());
				d_bookmark_file.set_groups(uri, item.get_groups());
				d_bookmark_file.set_visited_date_time(uri, new GLib.DateTime.from_unix_utc(item.get_modified()));

				var app_name = Environment.get_application_name();
				var app_exec = "gitg %f";

				try { d_bookmark_file.set_application_info(uri, app_name, app_exec, 1, new GLib.DateTime.now()); } catch {}
			}

			save_repository_bookmarks_timeout();
		}

		protected override void row_activated(Gtk.ListBoxRow row)
		{
			var r = (Row)row;

			if (mode == SelectionMode.SELECTION)
			{
				r.selected = !r.selected;
				return;
			}

			if (r.repository != null)
			{
				repository_activated(r.repository);
			}
		}

		construct
		{
			set_header_func(update_header);
			set_filter_func(filter);
			set_sort_func(compare_widgets);
			show();

			set_selection_mode(Gtk.SelectionMode.NONE);

			d_bookmark_file = new BookmarkFile();
		}

		~RepositoryListBox()
		{
			if (d_save_repository_bookmarks_id != 0)
			{
				Source.remove(d_save_repository_bookmarks_id);
				save_repository_bookmarks();
			}
		}

		private void update_header(Gtk.ListBoxRow row, Gtk.ListBoxRow? before)
		{
			row.set_header(before != null ? new Gtk.Separator(Gtk.Orientation.HORIZONTAL) : null);
		}

		private string normalize(string s)
		{
			return s.normalize(-1, NormalizeMode.ALL).casefold();
		}

		private bool filter(Gtk.ListBoxRow row)
		{
			return d_filter_text != null ? normalize(((Row)row).repository_name).contains(normalize(d_filter_text)) : true;
		}

		private int compare_widgets(Gtk.ListBoxRow a, Gtk.ListBoxRow b)
		{
			return ((Row)b).time.compare(((Row)a).time);
		}

		public void populate_bookmarks()
		{
			var uris = d_bookmark_file.get_uris();

			foreach (var uri in uris)
			{
				try {
					if (!d_bookmark_file.has_group(uri, "gitg"))
					{
						continue;
					}
				} catch { continue; }

				File repo_file = File.new_for_uri(uri);
				Repository repo;

				try
				{
					repo = new Repository(repo_file, null);
				}
				catch
				{
					try
					{
						d_bookmark_file.remove_item(uri);
					} catch {}

					continue;
				}

				DateTime? visited = null;

				try
				{
					visited = d_bookmark_file.get_visited_date_time(uri);
				} catch {};

				add_repository(repo, visited);
			}
		}

		private Row get_row_for_repository(Repository repository)
		{
			Row? row = null;

			foreach (var child in get_children())
			{
				var d = (Row)child;

				if (d.repository.get_location().equal(repository.get_location()))
				{
					row = d;
					break;
				}
			}

			return row;
		}

		private bool save_repository_bookmarks()
		{
			d_save_repository_bookmarks_id = 0;

			if (location == null)
			{
				return false;
			}

			try
			{
				var dir = location.get_parent();
				dir.make_directory_with_parents(null);
			} catch {}

			try
			{
				d_bookmark_file.to_file(location.get_path());
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to save repository bookmarks: $(e.message)\n");
			}

			return false;
		}

		private void add_repository_to_bookmarks(string uri, DateTime? visited = null)
		{
			d_bookmark_file.set_mime_type(uri, "inode/directory");
			d_bookmark_file.set_groups(uri, new string[] { "gitg" });
			d_bookmark_file.set_visited_date_time(uri, visited == null ? new GLib.DateTime.now() : visited);

			var app_name = Environment.get_application_name();
			var app_exec = "gitg %f";

			try { d_bookmark_file.set_application_info(uri, app_name, app_exec, 1, new GLib.DateTime.now()); } catch {}

			save_repository_bookmarks_timeout();
		}

		private void save_repository_bookmarks_timeout()
		{
			if (d_save_repository_bookmarks_id != 0)
			{
				return;
			}

			d_save_repository_bookmarks_id = Timeout.add(300, save_repository_bookmarks);
		}

		public void end_cloning(Row row, Repository? repository)
		{
			if (repository != null)
			{
				File? workdir = repository.get_workdir();
				File? repo_file = repository.get_location();

				var uri = (workdir != null) ? workdir.get_uri() : repo_file.get_uri();
				add_repository_to_bookmarks(uri);

				row.repository = repository;
				row.loading = false;

				connect_repository_row(row);
			}
			else
			{
				remove(row);
			}
		}

		public Row? begin_cloning(File location)
		{
			var row = new Row(null, Utils.replace_home_dir_with_tilde(location.get_parent()));
			row.repository_name = location.get_basename();
			row.branch_name = _("Cloning…");

			row.loading = true;
			row.show();

			add(row);
			return row;
		}

		private void delete_source_clicked(File workdir, string uri, Row row)
		{
			var alert_dialog = new Gtk.MessageDialog((Gtk.Window) row.get_toplevel(),
					Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.NONE,
					_("Deleting repository source files “%s” will delete them from disk and cannot be undone. Are you sure?"), uri);
			alert_dialog.add_button(_("Cancel"), DeleteSources.CANCEL);
			alert_dialog.add_button(_("Move to trash"), DeleteSources.TRASH);
			alert_dialog.add_button(_("Delete permanently"), DeleteSources.DELETE);

			var delete_button = alert_dialog.get_widget_for_response(DeleteSources.DELETE);
			delete_button.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

			alert_dialog.response.connect ((id) => {
				handle_delete_source_response(id, workdir, uri, row);
				alert_dialog.destroy();
			});

			alert_dialog.run();
		}

		private void handle_delete_source_response(int id, File workdir, string uri, Row row)
		{
			Cancellable cancellable = new Cancellable();

			if (id == DeleteSources.DELETE) {
				delete_source.begin(workdir, cancellable, (obj, res) => {
					try {
						delete_source.end (res);
						remove_row(uri, row);
					} catch (Error e) {
						warning("%s", e.message);
					}
				});
			} else if (id == DeleteSources.TRASH) {
				send_to_trash.begin(workdir, cancellable, (obj, res) => {
					try {
						send_to_trash.end (res);
						remove_row(uri, row);
					} catch (Error e) {
						warning("%s", e.message);
					}
				});
			}
		}

		private async void send_to_trash(File file, Cancellable cancellable) throws Error
		{
			if (cancellable.is_cancelled()) {
				return;
			}

			try {
				yield file.trash_async ();
			} catch (Error e) {
				warning("%s", e.message);
				cancellable.cancel();
				throw e;
			}
		}

		private async void delete_source(File file, Cancellable cancellable)throws Error
		{
			if (cancellable.is_cancelled ()) {
				return;
			}
			var dtype = file.query_file_type(FileQueryInfoFlags.NOFOLLOW_SYMLINKS);

			if (dtype == FileType.DIRECTORY) {
				try {
					var dir_in_repository = yield file.enumerate_children_async (FileAttribute.STANDARD_NAME, 0,Priority.DEFAULT);
					GLib.List<FileInfo> content_infos;
					while ((content_infos = yield dir_in_repository.next_files_async (20, Priority.DEFAULT)) != null) {
						foreach (var file_cinfo in content_infos) {
							var files = file.get_child (file_cinfo.get_name());
							yield delete_source (files, cancellable);
						}
					}
				}
				catch(Error e) {
					warning("Warning: %s\n", e.message);
					cancellable.cancel();
					throw e;
				}
			}

			try {
				yield file.delete_async ();
			} catch (Error e) {
				warning("%s", e.message);
				cancellable.cancel();
				throw e;
			}

		}

		private void remove_row(string uri, Row row)
		{
			try {
				d_bookmark_file.remove_item(uri);
			} catch {}

			remove(row);
		}

		private void on_row_secondary_clicked (Row row) {
			if (mode == SelectionMode.NORMAL)
			{
				mode = SelectionMode.SELECTION;
				row.selected = true;
			}
		}

		private void connect_repository_row(Row row)
		{
			var repository = row.repository;
			var workdir = repository.workdir != null ? repository.workdir : repository.location;

			if (workdir != null)
			{
				var uri = workdir.get_uri();
				bind_property("mode", row, "mode");

				row.secondary_clicked.connect (on_row_secondary_clicked);

				row.notify["selected"].connect(() => {
					notify_property("has-selection");
				});

				row.request_remove.connect(() => {
					remove_row(uri, row);
				});

				row.request_delete_source.connect(() => {
					delete_source_clicked(workdir, uri, row);
				});

				row.can_remove = true;
			}
			else
			{
				row.can_remove = false;
			}

		}

		public Row? add_repository(Repository repository, DateTime? visited = null)
		{
			Row? row = get_row_for_repository(repository);

			var f = repository.workdir != null ? repository.workdir : repository.location;

			if (row == null)
			{
				var dirname = Utils.replace_home_dir_with_tilde((repository.workdir != null ? repository.workdir : repository.location).get_parent());

				if (dirname.contains("/")) {
					dirname = dirname.concat("/", repository.name);
				} else {
					dirname = dirname.concat("\\", repository.name);
				}

				row = new Row(repository, dirname);
				row.show();

				connect_repository_row(row);

				add(row);
			}

			row.time = visited != null ? visited : new DateTime.now_local();
			invalidate_sort();

			if (f != null)
			{
				add_repository_to_bookmarks(f.get_uri(), visited);
			}

			return row;
		}

		public Row[] get_selection()
		{
			var ret = new Row[0];

			foreach (var row in get_children())
			{
				var r = (Row)row;

				if (r.selected)
				{
					ret += r;
				}
			}

			return ret;
		}

		public bool has_selection
		{
			get
			{
				foreach (var row in get_children())
				{
					var r = (Row)row;

					if (r.selected)
					{
						return true;
					}
				}

				return false;
			}
		}

		public void filter_text(string? text)
		{
			d_filter_text = text;

			invalidate_filter();
		}
	}
}

// ex:ts=4 noet
