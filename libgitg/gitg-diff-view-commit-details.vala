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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-commit-details.ui")]
class Gitg.DiffViewCommitDetails : Gtk.Grid
{
	[GtkChild( name = "image_avatar" )]
	private Gtk.Image d_image_avatar;

	[GtkChild( name = "label_author" )]
	private Gtk.Label d_label_author;

	[GtkChild( name = "label_author_date" )]
	private Gtk.Label d_label_author_date;

	[GtkChild( name = "label_committer" )]
	private Gtk.Label d_label_committer;

	[GtkChild( name = "label_committer_date" )]
	private Gtk.Label d_label_committer_date;

	[GtkChild( name = "textview_subject" )]
	private Gtk.TextView d_label_subject;

	[GtkChild( name = "label_sha1" )]
	private Gtk.Label d_label_sha1;

	[GtkChild( name = "grid_parents_container" )]
	private Gtk.Grid d_grid_parents_container;

	[GtkChild( name = "grid_parents" )]
	private Gtk.Grid d_grid_parents;

	[GtkChild( name = "expander_files" )]
	private Gtk.Expander d_expander_files;

	[GtkChild( name = "label_expand_collapse_files" )]
	private Gtk.Label d_label_expand_collapse_files;

	private Gdk.RGBA d_color_link;
	private Gdk.RGBA color_hovered_link;
	private bool hovering_over_link = false;
	private Gtk.TextTag hover_tag = null;
	public Repository repository { get; set; }
	public bool new_is_workdir { get; set; }

	public bool expanded
	{
		get { return d_expander_files.expanded; }
		set
		{
			if (d_expander_files.expanded != value)
			{
				d_expander_files.expanded = value;
			}
		}
	}

	public bool expander_visible
	{
		get { return d_expander_files.visible; }

		set
		{
			d_expander_files.visible = value;
			d_label_expand_collapse_files.visible = value;
		}
	}

	private Cancellable? d_avatar_cancel;

	private Ggit.Commit? d_commit;

	public Ggit.Commit? commit
	{
		get { return d_commit; }
		construct set
		{
			if (d_commit != value)
			{
				d_commit = value;
				update();
			}
		}
	}

	private Ggit.Commit d_parent_commit;

	public Ggit.Commit parent_commit
	{
		get { return d_parent_commit; }
		set
		{
			if (d_parent_commit != value)
			{
				d_parent_commit = value;

				if (value != null)
				{
					var button = d_parents_map[value.get_id()];

					if (button != null)
					{
						button.active = true;
					}
				}
			}
		}
	}

	public DiffViewCommitDetails(Ggit.Commit? commit)
	{
		Object(commit: commit);
	}

	protected override void constructed()
	{
		d_label_subject.event_after.connect (on_event_after);
		d_label_subject.key_press_event.connect (on_key_press);
		d_label_subject.motion_notify_event.connect (on_motion_notify_event);
		d_label_subject.has_tooltip = true;
		d_label_subject.query_tooltip.connect (on_query_tooltip_event);
		d_label_subject.style_updated.connect (load_colors_from_theme);
		load_colors_from_theme(d_label_subject);
	}

	private bool on_query_tooltip_event(int x, int y, bool keyboard_tooltip, Gtk.Tooltip tooltip)
	{
		Gtk.TextIter iter;

		if (d_label_subject.get_iter_at_location (out iter, x, y))
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

	public void  apply_link_tags(Gtk.TextBuffer buffer, Regex regex, string? replacement, Gdk.RGBA custom_color_link, bool is_custom_color, bool is_custom_link)
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
					message("Cannot open "+url+" "+e.message);
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

		if (evt.type == Gdk.BUTTON_RELEASE)
		{
			Gdk.EventButton event;

			event = (Gdk.EventButton)evt;
			if (event.button != Gdk.BUTTON_PRIMARY)
			return;

			ex = event.x;
			ey = event.y;
		}
		else if (evt.type == Gdk.TOUCH_END)
		{
			Gdk.EventTouch event;

			event = (Gdk.EventTouch)evt;

			ex = event.x;
			ey = event.y;
		}
		else
			return;

		Gtk.TextView textview = (Gtk.TextView)widget;
		buffer = textview.buffer;

		/* we shouldn't follow a link if the user has selected something */
		buffer.get_selection_bounds (out start, out end);
		if (start.get_offset () != end.get_offset ())
			return;

		textview.window_to_buffer_coords (Gtk.TextWindowType.WIDGET,(int)ex, (int)ey, out x, out y);

		if (textview.get_iter_at_location (out iter, x, y))
			follow_if_link (textview, iter);
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

	public void restore_tag_color_link (Gtk.TextTag tag)
	{
		Gdk.RGBA? color = tag.get_data<Gdk.RGBA?>("color_link");
		tag.foreground_rgba = color;
	}

	private bool d_use_gravatar;

	public bool use_gravatar
	{
		get { return d_use_gravatar; }
		construct set
		{
			d_use_gravatar = value;
			update_avatar();
		}
	}

	private Gee.HashMap<Ggit.OId, Gtk.RadioButton> d_parents_map;

	construct
	{
		d_expander_files.notify["expanded"].connect(() => {
			if (d_expander_files.expanded)
			{
				d_label_expand_collapse_files.label = _("Collapse all");
			}
			else
			{
				d_label_expand_collapse_files.label = _("Expand all");
			}

			notify_property("expanded");
		});

		use_gravatar = true;
	}

	protected override void dispose()
	{
		if (d_avatar_cancel != null)
		{
			d_avatar_cancel.cancel();
		}

		base.dispose();
	}

	private string author_to_markup(Ggit.Signature author)
	{
		var name = Markup.escape_text(author.get_name());
		var email = Markup.escape_text(author.get_email());

		return "%s &lt;<a href=\"mailto:%s\">%s</a>&gt;".printf(name, email, email);
	}

	private void update()
	{
		d_parents_map = new Gee.HashMap<Ggit.OId, Gtk.RadioButton>((oid) => oid.hash(), (o1, o2) => o1.equal(o2));

		foreach (var child in d_grid_parents.get_children())
		{
			child.destroy();
		}

		if (commit == null)
		{
			return;
		}
		d_label_subject.buffer.set_text(commit.get_subject());
		var buffer = d_label_subject.get_buffer();
		apply_link_tags(buffer, /\w+:(\/?\/?)[^\s]+/, null, d_color_link, false, false);

		var ini_file = "%s/.git/config".printf(repository.get_workdir().get_path());
		read_ini_file(buffer, ini_file);
		d_label_sha1.label = commit.get_id().to_string();

		var author = commit.get_author();

		d_label_author.label = author_to_markup(author);
		d_label_author_date.label = author.get_time().to_timezone(author.get_time_zone()).format("%x %X %z");

		var committer = commit.get_committer();

		if (committer.get_name() != author.get_name() ||
		    committer.get_email() != author.get_email() ||
		    committer.get_time().compare(author.get_time()) != 0)
		{
			d_label_committer.label = _("Committed by %s").printf(author_to_markup(committer));
			d_label_committer_date.label = committer.get_time().to_timezone(committer.get_time_zone()).format("%x %X %z");
		}
		else
		{
			d_label_committer.label = "";
			d_label_committer_date.label = "";
		}

		var parents = commit.get_parents();
		var first_parent = parents.size == 0 ? null : parents.get(0);

		parent_commit = first_parent;

		if (parents.size > 1)
		{
			d_grid_parents_container.show();
			var grp = new SList<Gtk.RadioButton>();

			Gtk.RadioButton? first = null;

			foreach (var parent in parents)
			{
				var pid = parent.get_id().to_string().substring(0, 6);
				var psubj = parent.get_subject();

				var button = new Gtk.RadioButton.with_label(grp, @"$pid: $psubj");

				if (first == null)
				{
					first = button;
				}

				button.group = first;

				d_parents_map[parent.get_id()] = button;

				button.show();
				d_grid_parents.add(button);

				var par = parent;

				button.toggled.connect(() => {
					if (button.active) {
						parent_commit = par;
					}
				});
			}
		}
		else
		{
			d_grid_parents_container.hide();
		}

		update_avatar();
	}

	private void read_ini_file(Gtk.TextBuffer buffer, string config_file)
	{
		GLib.KeyFile file = new GLib.KeyFile();

		try
		{
			if (file.load_from_file(config_file , GLib.KeyFileFlags.NONE))
			{
				foreach (string group in file.get_groups())
				{
					if (group.has_prefix("gitg.custom-link"))
					{
						string custom_link_regexp = file.get_string (group, "regexp");
						string custom_link_replacement = file.get_string (group, "replacement");
						bool is_custom_color = file.has_key (group, "color");
						Gdk.RGBA color = d_color_link;
						if (is_custom_color)
						{
							string custom_link_color = file.get_string (group, "color");
							color = Gdk.RGBA();
							color.parse(custom_link_color);
						}
						apply_link_tags(buffer, new Regex (custom_link_regexp), custom_link_replacement, color, is_custom_color, true);
					}
				}
			}
		} catch (Error e)
		{
			message("Cannot read %s: %s", config_file, e.message);
		}
	}

	private void update_avatar()
	{
		if (commit == null)
		{
			return;
		}

		if (d_use_gravatar)
		{
			if (d_avatar_cancel != null)
			{
				d_avatar_cancel.cancel();
			}

			d_avatar_cancel = new Cancellable();
			var cancel = d_avatar_cancel;

			var cache = AvatarCache.default();

			cache.load.begin(commit.get_author().get_email(), d_image_avatar.pixel_size, cancel, (obj, res) => {
				if (!cancel.is_cancelled())
				{
					var pixbuf = cache.load.end(res);

					if (pixbuf != null)
					{
						d_image_avatar.pixbuf = pixbuf;
						d_image_avatar.get_style_context().remove_class("dim-label");
					}
					else
					{
						d_image_avatar.icon_name = "avatar-default-symbolic";
						d_image_avatar.get_style_context().add_class("dim-label");
					}
				}

				if (cancel == d_avatar_cancel)
				{
					d_avatar_cancel = null;
				}
			});
		}
		else
		{
			d_image_avatar.icon_name = "avatar-default-symbolic";
			d_image_avatar.get_style_context().add_class("dim-label");
		}
	}

	[GtkCallback]
	private bool button_press_on_event_box_expand_collapse(Gdk.EventButton event)
	{
		if (event.button == Gdk.BUTTON_PRIMARY)
		{
			d_expander_files.expanded = !d_expander_files.expanded;
			return true;
		}

		return false;
	}
}

// ex:ts=4 noet
