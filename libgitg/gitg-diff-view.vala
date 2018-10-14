/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

[GtkTemplate( ui = "/org/gnome/gitg/ui/gitg-diff-view.ui" )]
public class Gitg.DiffView : Gtk.Grid
{
	[GtkChild( name = "commit_details" )]
	private Gitg.DiffViewCommitDetails d_commit_details;

	[GtkChild( name = "scrolledwindow" )]
	private Gtk.ScrolledWindow d_scrolledwindow;

	[GtkChild( name = "grid_files" )]
	private Gtk.Grid d_grid_files;

	[GtkChild( name = "event_box" )]
	private Gtk.EventBox d_event_box;

	[GtkChild( name = "revealer_options" )]
	private Gtk.Revealer d_revealer_options;

	[GtkChild( name = "diff_view_options" )]
	private DiffViewOptions d_diff_view_options;

	[GtkChild( name = "text_view_message" )]
	private Gtk.TextView d_text_view_message;

	private Ggit.Diff? d_diff;
	private Commit? d_commit;
	private Ggit.DiffOptions? d_options;
	private Cancellable d_cancellable;
	private ulong d_expanded_notify;
	private ulong d_parent_commit_notify;
	private bool d_changes_inline;

	private uint d_reveal_options_timeout;
	private uint d_unreveal_options_timeout;

	private static Gee.HashSet<string> s_image_mime_types;

	public Ggit.DiffOptions options
	{
		get
		{
			if (d_options == null)
			{
				d_options = new Ggit.DiffOptions();
			}

			return d_options;
		}
	}

	public bool has_selection
	{
		get; private set;
	}

	public Ggit.Diff? diff
	{
		get { return d_diff; }
		set
		{
			if (d_diff != value)
			{
				d_diff = value;
				d_commit = null;
			}

			update(false);
		}
	}

	public Commit? commit
	{
		get { return d_commit; }
		set
		{
			if (d_commit != value)
			{
				d_commit = value;
				d_diff = null;
			}

			update(false);
		}
	}

	public virtual signal void options_changed()
	{
		if (d_commit != null)
		{
			update(true);
		}
	}

	public bool wrap_lines { get; construct set; default = true; }
	public bool staged { get; set; default = false; }
	public bool unstaged { get; set; default = false; }
	public bool show_parents { get; set; default = false; }
	public bool default_collapse_all { get; construct set; default = true; }
	public bool use_gravatar { get; construct set; default = true; }
	public int tab_width { get; construct set; default = 4; }
	public bool handle_selection { get; construct set; default = false; }
	public bool highlight { get; construct set; default = true; }
	public Repository repository { get; set; }
	public bool new_is_workdir { get; set; }

	private bool flag_get(Ggit.DiffOption f)
	{
		return (options.flags & f) != 0;
	}

	private void flag_set(Ggit.DiffOption f, bool val)
	{
		var flags = options.flags;

		if (val)
		{
			flags |= f;
		}
		else
		{
			flags &= ~f;
		}

		if (flags != options.flags)
		{
			options.flags = flags;
			options_changed();
		}
	}

	public bool ignore_whitespace
	{
		get { return flag_get(Ggit.DiffOption.IGNORE_WHITESPACE); }
		set { flag_set(Ggit.DiffOption.IGNORE_WHITESPACE, value); }
	}

	public bool changes_inline
	{
		get { return d_changes_inline; }
		set
		{
			if (d_changes_inline != value)
			{
				d_changes_inline = value;

				// TODO
				//options_changed();
			}
		}
	}

	public int context_lines
	{
		get { return options.n_context_lines; }

		construct set
		{
			if (options.n_context_lines != value)
			{
				options.n_context_lines = value;
				options.n_interhunk_lines = value;

				options_changed();
			}
		}
	}

	protected override void constructed()
	{
		d_expanded_notify = d_commit_details.notify["expanded"].connect(update_expanded_files);
		d_parent_commit_notify = d_commit_details.notify["parent-commit"].connect(parent_commit_changed);

		bind_property("use-gravatar", d_commit_details, "use-gravatar", BindingFlags.SYNC_CREATE);

		d_event_box.motion_notify_event.connect(motion_notify_event_on_event_box);
		d_diff_view_options.view = this;
	}

	public override void dispose()
	{
		if (d_cancellable != null)
		{
			d_cancellable.cancel();
		}

		base.dispose();
	}

	private void parent_commit_changed()
	{
		update(false);
	}

	private void update_expanded_files()
	{
		var expanded = d_commit_details.expanded;

		foreach (var file in d_grid_files.get_children())
		{
			(file as Gitg.DiffViewFile).expanded = expanded;
		}
	}

	private static Regex s_message_regexp;

	static construct
	{
		s_image_mime_types = new Gee.HashSet<string>();

		foreach (var format in Gdk.Pixbuf.get_formats())
		{
			foreach (var mime_type in format.get_mime_types())
			{
				s_image_mime_types.add(mime_type);
			}
		}

		try
		{
			s_message_regexp = new Regex(".*(\\R|\\s)*(?P<message>(?:.|\\R)*?)\\s*$");
		} catch (Error e) { stderr.printf(@"Failed to compile regex: $(e.message)\n"); }
	}

	construct
	{
		context_lines = 3;
	}

	private string message_without_subject(Commit commit)
	{
		var message = commit.get_message();
		MatchInfo minfo;

		if (s_message_regexp.match(message, 0, out minfo))
		{
			return minfo.fetch_named("message");
		}

		return "";
	}

	private void update(bool preserve_expanded)
	{
		// If both `d_diff` and `d_commit` are null, clear
		// the diff content
		if (d_diff == null && d_commit == null)
		{
			d_commit_details.hide();
			d_scrolledwindow.hide();
			return;
		}

		d_commit_details.show();
		d_scrolledwindow.show();

		// Cancel running operations
		d_cancellable.cancel();
		d_cancellable = new Cancellable();

		if (d_commit != null)
		{
			SignalHandler.block(d_commit_details, d_parent_commit_notify);
			d_commit_details.commit = d_commit;
			SignalHandler.unblock(d_commit_details, d_parent_commit_notify);

			int parent = 0;
			var parents = d_commit.get_parents();

			var parent_commit = d_commit_details.parent_commit;

			if (parent_commit != null)
			{
				for (var i = 0; i < parents.size; i++)
				{
					var id = parents.get_id(i);

					if (id.equal(parent_commit.get_id()))
					{
						parent = i;
						break;
					}
				}
			}

			d_diff = d_commit.get_diff(options, parent);
			d_commit_details.show();

			var message = message_without_subject(d_commit);

			d_text_view_message.buffer.set_text(message);
			d_text_view_message.visible = (message != "");
		}
		else
		{
			d_commit_details.commit = null;
			d_commit_details.hide();

			d_text_view_message.hide();
		}

		if (d_diff != null)
		{
			update_diff(d_diff, preserve_expanded, d_cancellable);
		}
	}

	private void auto_change_expanded(bool expanded)
	{
		SignalHandler.block(d_commit_details, d_expanded_notify);
		d_commit_details.expanded = expanded;
		SignalHandler.unblock(d_commit_details, d_expanded_notify);
	}

	private void on_selection_changed()
	{
		bool something_selected = false;

		foreach (var file in d_grid_files.get_children())
		{
			var selectable = (file as Gitg.DiffViewFile).renderer as DiffSelectable;

			if (selectable.has_selection)
			{
				something_selected = true;
				break;
			}
		}

		if (has_selection != something_selected)
		{
			has_selection = something_selected;
		}
	}

	private string? primary_path(Ggit.DiffDelta delta)
	{
		var path = delta.get_old_file().get_path();

		if (path == null)
		{
			path = delta.get_new_file().get_path();
		}

		return path;
	}

	private delegate void Anon();

	private string key_for_delta(Ggit.DiffDelta delta)
	{
		var new_file = delta.get_new_file();
		var new_path = new_file.get_path();

		if (new_path != null)
		{
			return @"path:$(new_path)";
		}

		var old_file = delta.get_old_file();
		var old_path = old_file.get_path();

		if (old_path != null)
		{
			return @"path:$(old_path)";
		}

		return "";
	}

	private void update_diff(Ggit.Diff diff, bool preserve_expanded, Cancellable? cancellable)
	{
		var nqueries = 0;
		var finished = false;
		var infomap = new Gee.HashMap<string, DiffViewFileInfo>();

		Anon check_finish = () => {
			if (nqueries == 0 && finished && (cancellable == null || !cancellable.is_cancelled()))
			{
				finished = false;
				update_diff_hunks(diff, preserve_expanded, infomap, cancellable);
			}
		};

		// Collect file info asynchronously first
		for (var i = 0; i < diff.get_num_deltas(); i++)
		{
			var delta = diff.get_delta(i);
			var info = new DiffViewFileInfo(repository, delta, new_is_workdir);

			nqueries++;

			info.query.begin(cancellable, (obj, res) => {
				info.query.end(res);

				infomap[key_for_delta(delta)] = info;

				nqueries--;

				check_finish();
			});
		}

		finished = true;
		check_finish();
	}

	private void update_diff_hunks(Ggit.Diff diff, bool preserve_expanded, Gee.HashMap<string, DiffViewFileInfo> infomap, Cancellable? cancellable)
	{
		var files = new Gee.ArrayList<Gitg.DiffViewFile>();

		Gitg.DiffViewFile? current_file = null;
		Ggit.DiffHunk? current_hunk = null;
		Gee.ArrayList<Ggit.DiffLine>? current_lines = null;
		var current_is_binary = false;

		var maxlines = 0;

		Anon add_hunk = () => {
			if (current_hunk != null)
			{
				current_file.add_hunk(current_hunk, current_lines);

				current_lines = null;
				current_hunk = null;
			}
		};

		Anon add_file = () => {
			add_hunk();

			if (current_file != null)
			{
				current_file.show();
				current_file.renderer.notify["has-selection"].connect(on_selection_changed);	

				files.add(current_file);

				current_file = null;
			}
		};

		try
		{
			diff.foreach(
				(delta, progress) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					add_file();

					DiffViewFileInfo? info = null;
					var deltakey = key_for_delta(delta);

					if (infomap.has_key(deltakey))
					{
						info = infomap[deltakey];
					}
					else
					{
						info = new DiffViewFileInfo(repository, delta, new_is_workdir);
					}

					current_is_binary = ((delta.get_flags() & Ggit.DiffFlag.BINARY) != 0);

					// List of known binary file types that may be wrongly classified by
					// libgit2 because it does not contain any null bytes in the first N
					// bytes. E.g. PDF
					var known_binary_files_types = new string[] {"application/pdf"};

					// Ignore binary based on content type
					if (info != null && info.new_file_content_type in known_binary_files_types)
					{
						current_is_binary = true;
					}

					string? mime_type_for_image = null;

					if (info == null || info.new_file_content_type == null)
					{
						// Guess mime type from old file name in the case of a deleted file
						var oldpath = delta.get_old_file().get_path();

						if (oldpath != null)
						{
							bool uncertain;
							var ctype = ContentType.guess(Path.get_basename(oldpath), null, out uncertain);

							if (ctype != null)
							{
								mime_type_for_image = ContentType.get_mime_type(ctype);
							}
						}
					}
					else
					{
						mime_type_for_image = ContentType.get_mime_type(info.new_file_content_type);
					}

					if (mime_type_for_image != null && s_image_mime_types.contains(mime_type_for_image))
					{
						current_file = new Gitg.DiffViewFile.image(repository, delta);
					}
					else if (current_is_binary)
					{
						current_file = new Gitg.DiffViewFile.binary(repository, delta);
					}
					else
					{
						current_file = new Gitg.DiffViewFile.text(info, handle_selection);
						this.bind_property("highlight", current_file.renderer, "highlight", BindingFlags.SYNC_CREATE);
					}

					return 0;
				},

				(delta, binary) => {
					// FIXME: do we want to handle binary data?
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					return 0;
				},

				(delta, hunk) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					if (!current_is_binary)
					{
						maxlines = int.max(maxlines, hunk.get_old_start() + hunk.get_old_lines());
						maxlines = int.max(maxlines, hunk.get_new_start() + hunk.get_new_lines());

						add_hunk();

						current_hunk = hunk;
						current_lines = new Gee.ArrayList<Ggit.DiffLine>();
					}

					return 0;
				},

				(delta, hunk, line) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					if (!current_is_binary)
					{
						current_lines.add(line);
					}

					return 0;
				}
			);
		} catch {}

		add_hunk();
		add_file();

		var file_widgets = d_grid_files.get_children();
		var was_expanded = new Gee.HashSet<string>();

		foreach (var file in file_widgets)
		{
			var f = file as Gitg.DiffViewFile;

			if (preserve_expanded && f.expanded)
			{
				var path = primary_path(f.delta);

				if (path != null)
				{
					was_expanded.add(path);
				}
			}

			f.destroy();
		}

		d_commit_details.expanded = (files.size <= 1 || !default_collapse_all);
		d_commit_details.expander_visible = (files.size > 1);

		for (var i = 0; i < files.size; i++)
		{
			var file = files[i];
			var path = primary_path(file.delta);

			file.expanded = d_commit_details.expanded || (path != null && was_expanded.contains(path));

			var renderer_text = file.renderer as DiffViewFileRendererText;

			if (renderer_text != null)
			{
				renderer_text.maxlines = maxlines;

				this.bind_property("wrap-lines", renderer_text, "wrap-lines", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
				this.bind_property("tab-width", renderer_text, "tab-width", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
			}

			if (i == files.size - 1)
			{
				file.vexpand = true;
			}

			d_grid_files.add(file);

			file.notify["expanded"].connect(auto_update_expanded);
		}
	}

	private void auto_update_expanded()
	{
		foreach (var file in d_grid_files.get_children())
		{
			if (!(file as Gitg.DiffViewFile).expanded)
			{
				auto_change_expanded(false);
				return;
			}
		}

		auto_change_expanded(true);
	}

	public PatchSet[] selection
	{
		owned get
		{
			var ret = new PatchSet[0];

			foreach (var file in d_grid_files.get_children())
			{
				var sel = (file as Gitg.DiffViewFile).renderer as DiffSelectable;

				if (sel != null && sel.has_selection && sel.selection.patches.length != 0)
				{
					ret += sel.selection;
				}
			}

			return ret;
		}
	}

	private void update_hide_show_options(Gdk.Window window, int ex, int ey)
	{
		void *data;
		window.get_user_data(out data);

		var w = data as Gtk.Widget;

		if (w == null)
		{
			return;
		}

		int x, y;
		w.translate_coordinates(d_event_box, ex, ey, out x, out y);

		Gtk.Allocation alloc, revealer_alloc;

		d_event_box.get_allocation(out alloc);
		d_revealer_options.get_allocation(out revealer_alloc);

		if (!d_revealer_options.reveal_child && y >= alloc.height - 18 && x >= alloc.width - 150 && d_reveal_options_timeout == 0)
		{
			if (d_unreveal_options_timeout != 0)
			{
				Source.remove(d_unreveal_options_timeout);
				d_unreveal_options_timeout = 0;
			}

			d_reveal_options_timeout = Timeout.add(300, () => {
				d_reveal_options_timeout = 0;
				d_revealer_options.reveal_child = true;
				return false;
			});
		}
		else if (d_revealer_options.reveal_child)
		{
			var above = (y <= alloc.height - 6 - revealer_alloc.height);

			if (above && d_unreveal_options_timeout == 0)
			{
				if (d_reveal_options_timeout != 0)
				{
					Source.remove(d_reveal_options_timeout);
					d_reveal_options_timeout = 0;
				}

				d_unreveal_options_timeout = Timeout.add(1000, () => {
					d_unreveal_options_timeout = 0;
					d_revealer_options.reveal_child = false;
					return false;
				});
			}
			else if (!above && d_unreveal_options_timeout != 0)
			{
				Source.remove(d_unreveal_options_timeout);
				d_unreveal_options_timeout = 0;
			}
		}
	}

	[GtkCallback]
	private bool leave_notify_event_on_event_box(Gtk.Widget widget, Gdk.EventCrossing event)
	{
		update_hide_show_options(event.window, (int)event.x, (int)event.y);
		return false;
	}

	[GtkCallback]
	private bool enter_notify_event_on_event_box(Gtk.Widget widget, Gdk.EventCrossing event)
	{
		update_hide_show_options(event.window, (int)event.x, (int)event.y);
		return false;
	}

	[GtkCallback]
	private bool motion_notify_event_on_event_box(Gtk.Widget widget, Gdk.EventMotion event)
	{
		update_hide_show_options(event.window, (int)event.x, (int)event.y);
		return false;
	}
}

// ex:ts=4 noet
