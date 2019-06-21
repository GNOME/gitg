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

	Gdk.RGBA d_color_link;
	Gdk.RGBA color_hovered_link;
	bool hovering_over_link = false;
	Gtk.TextTag hover_tag = null;

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

	private Repository? d_repository;

	public Repository? repository {
		get { return d_repository; }
		set {
			d_repository = value;
			if (d_repository!=null)
			{
				config_file = "%s/.git/config".printf(d_repository.get_workdir().get_path());
				d_commit_details.config_file = config_file;
			}
		}
	}
	public bool new_is_workdir { get; set; }
	private string config_file;

	private GLib.Regex regex_url = /\w+:(\/?\/?)[^\s]+/;

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
		d_text_view_message.event_after.connect (on_event_after);
		d_text_view_message.key_press_event.connect (on_key_press);
		d_text_view_message.motion_notify_event.connect (on_motion_notify_event);
		d_text_view_message.has_tooltip = true;
		d_text_view_message.query_tooltip.connect (on_query_tooltip_event);
		d_text_view_message.style_updated.connect (load_colors_from_theme);

		load_colors_from_theme(d_text_view_message);

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

	private bool on_query_tooltip_event(int x, int y, bool keyboard_tooltip, Gtk.Tooltip tooltip)
	{
		Gtk.TextIter iter;

		if (d_text_view_message.get_iter_at_location (out iter, x, y))
		{
			var tags = iter.get_tags ();
			foreach (Gtk.TextTag tag in tags)
			{
				if (tag.get_data<string>("type") == "url" && tag.get_data<bool>("is_custom_link"))
				{
					string url = tag.get_data<string>("url");
					tooltip.set_text (url);
					return true;
				}
			}
		}
		return false;
	}

	public void apply_link_tags(Gtk.TextBuffer buffer, Regex regex, string? replacement, Gdk.RGBA custom_color_link, bool is_custom_color, bool is_custom_link)
	{
		try
		{
			GLib.MatchInfo matchInfo;

			var buffer_text = buffer.text;
			regex.match (buffer_text, 0, out matchInfo);

			while (matchInfo.matches ())
			{
				Gtk.TextIter start, end;
				int start_pos, end_pos;
				string text = matchInfo.fetch(0);
				matchInfo.fetch_pos (0, out start_pos, out end_pos);
				buffer.get_iter_at_offset(out start, start_pos);
				buffer.get_iter_at_offset(out end, end_pos);

				var tag = buffer.create_tag(null, "underline", Pango.Underline.SINGLE);
				tag.foreground_rgba = custom_color_link;
				tag.set_data("type", "url");
				tag.set_data<Gdk.RGBA?>("color_link", custom_color_link);
				if (replacement != null)
				{
					text = regex.replace(text, text.length, 0, replacement);
				}
				tag.set_data("url", text);
				tag.set_data("is_custom_color_link", is_custom_color);
				tag.set_data("is_custom_link", is_custom_link);
				buffer.apply_tag(tag, start, end);

				matchInfo.next();
			}
		}
		catch(Error e)
		{
		}
	}

	private void load_colors_from_theme(Gtk.Widget widget)
	{
		Gtk.TextView textview = (Gtk.TextView)widget;
		Gtk.StyleContext context = textview.get_style_context ();

		context.save ();
		context.set_state (Gtk.StateFlags.LINK);
		d_color_link = context.get_color (context.get_state ());

		context.set_state (Gtk.StateFlags.LINK | Gtk.StateFlags.PRELIGHT);
		color_hovered_link = context.get_color (context.get_state ());
		context.restore ();

		textview.buffer.tag_table.foreach ((tag) =>
		{
			if (!tag.get_data<bool>("is_custom_color_link"))
			{
				tag.set_data<Gdk.RGBA?>("color_link", d_color_link);
				tag.foreground_rgba = d_color_link;
			}
		});
	}

	private bool on_key_press (Gtk.Widget widget, Gdk.EventKey evt)
	{
		if (evt.keyval == Gdk.Key.Return || evt.keyval == Gdk.Key.KP_Enter)
		{

			Gtk.TextIter iter;
			Gtk.TextView textview = (Gtk.TextView) widget;
			textview.buffer.get_iter_at_mark(out iter, textview.buffer.get_insert());

			follow_if_link (widget, iter);
		}
		return false;
	}

	public void follow_if_link(Gtk.Widget texview, Gtk.TextIter iter)
	{
		var tags = iter.get_tags ();
		foreach (Gtk.TextTag tag in tags)
		{
			if (tag.get_data<string>("type") == "url")
			{
				string url = tag.get_data<string>("url");
				try
				{
					GLib.AppInfo.launch_default_for_uri(url, null);
				}
				catch(Error e)
				{
					warning ("Cannot open %s: %s", url, e.message);
				}
			}
		}

	}

	private void on_event_after (Gtk.Widget widget, Gdk.Event evt)
	{

		Gtk.TextIter start, end, iter;
		Gtk.TextBuffer buffer;
		double ex, ey;
		int x, y;

		if (evt.type == Gdk.EventType.BUTTON_RELEASE)
		{
			Gdk.EventButton event;

			event = (Gdk.EventButton)evt;
			if (event.button != Gdk.BUTTON_PRIMARY)
			return;

			ex = event.x;
			ey = event.y;
		}
		else if (evt.type == Gdk.EventType.TOUCH_END)
		{
			Gdk.EventTouch event;

			event = (Gdk.EventTouch)evt;

			ex = event.x;
			ey = event.y;
		}
		else
		{
			return;
		}

		Gtk.TextView textview = (Gtk.TextView)widget;
		buffer = textview.buffer;

		/* we shouldn't follow a link if the user has selected something */
		buffer.get_selection_bounds (out start, out end);
		if (start.get_offset () != end.get_offset ())
		{
			return;
		}

		textview.window_to_buffer_coords (Gtk.TextWindowType.WIDGET,(int)ex, (int)ey, out x, out y);

		if (textview.get_iter_at_location (out iter, x, y))
		{
			follow_if_link (textview, iter);
		}
	}

	private bool on_motion_notify_event (Gtk.Widget widget, Gdk.EventMotion evt)
	{
		int x, y;

		Gtk.TextView textview = ((Gtk.TextView)widget);

		textview.window_to_buffer_coords (Gtk.TextWindowType.WIDGET,(int)evt.x, (int)evt.y, out x, out y);

		Gtk.TextIter iter;
		bool hovering = false;

		if (textview.get_iter_at_location (out iter, x, y))
		{
			var tags = iter.get_tags ();
			foreach (Gtk.TextTag tag in tags)
			{
				if (tag.get_data<string>("type") == "url")
				{
					hovering = true;
					if (hover_tag != null && hover_tag != tag)
					{
						restore_tag_color_link (hover_tag);
						hovering_over_link = false;
					}
					hover_tag = tag;
					break;
				}
			}
		}

		if (hovering != hovering_over_link)
		{
			hovering_over_link = hovering;

			Gdk.Display display = textview.get_display();
			Gdk.Cursor hand_cursor = new Gdk.Cursor.from_name (display, "pointer");
			Gdk.Cursor regular_cursor = new Gdk.Cursor.from_name (display, "text");

			Gdk.Window window = textview.get_window (Gtk.TextWindowType.TEXT);
			if (hovering_over_link)
			{
				window.set_cursor (hand_cursor);
				if (hover_tag != null)
				{
					hover_tag.foreground_rgba = color_hovered_link;
				}
			}
			else
			{
				window.set_cursor (regular_cursor);
				if (hover_tag != null)
				{
					restore_tag_color_link (hover_tag);
					hover_tag = null;
				}
			}
		}

		return true;
	}

	private void restore_tag_color_link (Gtk.TextTag tag)
	{
		Gdk.RGBA? color = tag.get_data<Gdk.RGBA?>("color_link");
		tag.foreground_rgba = color;
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
			var buffer = d_text_view_message.get_buffer();

			apply_link_tags(buffer, regex_url, null, d_color_link, false, false);

			read_ini_file(buffer);

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

	private void read_ini_file(Gtk.TextBuffer buffer)
	{
		if (config_file != null)
		{
			try
			{
				GLib.KeyFile file = new GLib.KeyFile();
				if (file.load_from_file(config_file , GLib.KeyFileFlags.NONE))
				{
					foreach (string group in file.get_groups())
					{
						if (group.has_prefix("gitg.custom-link"))
						{
							string custom_link_regexp = file.get_string (group, "regexp");
							string custom_link_replacement = file.get_string (group, "replacement");
							bool custom_color = file.has_key (group, "color");
							Gdk.RGBA color = d_color_link;
							if (custom_color)
							{
								string custom_link_color = file.get_string (group, "color");
								color = Gdk.RGBA();
								color.parse(custom_link_color);
							}
							apply_link_tags(buffer, new Regex (custom_link_regexp), custom_link_replacement, color, custom_color, true);
						}
					}
				}
			} catch (Error e)
			{
				warning ("Cannot read %s: %s", config_file, e.message);
			}
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

	public PatchSet[] get_selection()
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
