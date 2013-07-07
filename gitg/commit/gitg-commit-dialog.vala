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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-dialog.ui")]
class Dialog : Gtk.Dialog
{
	[GtkChild (name = "source_view_message")]
	private GtkSource.View d_source_view_message;

	[GtkChild (name = "ok-button")]
	private Gtk.Button d_button_ok;

	[GtkChild (name = "check_button_amend")]
	private Gtk.CheckButton d_check_button_amend;

	[GtkChild (name = "check_button_sign_off")]
	private Gtk.CheckButton d_check_button_sign_off;

	[GtkChild (name = "image_avatar")]
	private Gtk.Image d_image_avatar;

	[GtkChild (name = "label_user")]
	private Gtk.Label d_label_user;

	[GtkChild (name = "label_date")]
	private Gtk.Label d_label_date;

	private bool d_show_markup;
	private bool d_show_right_margin;
	private bool d_show_subject_margin;
	private int d_right_margin_position;
	private int d_subject_margin_position;
	private Ggit.Signature d_author;
	private Cancellable? d_cancel_avatar;
	private bool d_constructed;
	private Settings? d_message_settings;
	private Settings? d_font_settings;
	private Settings? d_commit_settings;

	public GtkSource.View source_view_message
	{
		get { return d_source_view_message; }
	}

	public string pretty_message
	{
		owned get
		{
			var pretty = Ggit.message_prettify(message, false);

			if (pretty == null)
			{
				return "";
			}
			else
			{
				return pretty;
			}
		}
	}

	public string message
	{
		owned get
		{
			var b = d_source_view_message.buffer;

			Gtk.TextIter start;
			Gtk.TextIter end;

			b.get_bounds(out start, out end);
			return b.get_text(start, end, false);
		}
		set
		{
			d_source_view_message.buffer.set_text(value);
		}
	}

	[Notify]
	public bool amend { get; set; }

	[Notify]
	public bool sign_off { get; set; }

	[Notify]
	public bool show_markup
	{
		get { return d_show_markup; }

		set
		{
			d_show_markup = value;
			update_highlight();
		}

		default = true;
	}

	[Notify]
	public bool show_right_margin
	{
		get { return d_show_right_margin; }

		construct set
		{
			d_show_right_margin = value;
			update_highlight();
		}

		default = true;
	}

	[Notify]
	public bool show_subject_margin
	{
		get { return d_show_subject_margin; }

		construct set
		{
			d_show_subject_margin = value;
			update_highlight();
		}

		default = true;
	}


	[Notify]
	public int right_margin_position
	{
		get { return d_right_margin_position; }

		construct set
		{
			d_right_margin_position = value;
			update_highlight();
		}

		default = 72;
	}

	[Notify]
	public int subject_margin_position
	{
		get { return d_subject_margin_position; }

		construct set
		{
			d_subject_margin_position = value;
			update_highlight();
		}

		default = 50;
	}

	[Notify]
	public Ggit.Signature author
	{
		owned get { return d_author; }

		construct set
		{
			d_author = value;
			load_author_info();
		}
	}

	private void load_author_info()
	{
		if (d_cancel_avatar != null)
		{
			d_cancel_avatar.cancel();
			d_cancel_avatar = new Cancellable();
		}

		var name = d_author.get_name();
		var email = d_author.get_email();

		d_label_user.set_label(@"$name <$email>");

		var t = d_author.get_time();
		var now = new DateTime.now_local();

		if (now.difference(t) < TimeSpan.SECOND * 5)
		{
			d_label_date.set_label("");
		}
		else
		{
			d_label_date.set_label((new Gitg.Date.for_date_time(t)).for_display());
		}

		var ac = Gitg.AvatarCache.default();
		d_cancel_avatar = new Cancellable();

		ac.load.begin(d_author.get_email(), d_cancel_avatar, (obj, res) => {
			var pixbuf = ac.load.end(res);

			if (pixbuf != null && !d_cancel_avatar.is_cancelled())
			{
				d_image_avatar.set_from_pixbuf(pixbuf);
			}
		});
	}

	protected override void destroy()
	{
		if (d_cancel_avatar != null)
		{
			d_cancel_avatar.cancel();
		}

		d_message_settings = null;
		d_font_settings = null;
		d_commit_settings = null;

		base.destroy();
	}

	construct
	{
		d_font_settings = new Settings("org.gnome.desktop.interface");

		update_font_settings();

		d_font_settings.changed["monospace-font-name"].connect((s, k) => {
			update_font_settings();
		});

		var b = d_source_view_message.buffer;

		d_source_view_message.buffer.changed.connect(() => {
			d_button_ok.sensitive = pretty_message != "";
		});

		d_check_button_amend.bind_property("active",
		                                   this, "amend",
		                                   BindingFlags.BIDIRECTIONAL |
		                                   BindingFlags.SYNC_CREATE);

		d_check_button_sign_off.bind_property("active",
		                                      this, "sign-off",
		                                      BindingFlags.BIDIRECTIONAL |
		                                      BindingFlags.SYNC_CREATE);

		d_commit_settings = new Settings("org.gnome.gitg.state.commit");

		d_commit_settings.bind("sign-off",
		                     this,
		                     "sign-off",
		                     SettingsBindFlags.GET |
		                     SettingsBindFlags.SET);

		d_message_settings = new Settings("org.gnome.gitg.preferences.commit.message");

		d_message_settings.bind("show-markup",
		                        this,
		                        "show-markup",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("show-right-margin",
		                        this,
		                        "show-right-margin",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("right-margin-position",
		                        this,
		                        "right-margin-position",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("show-subject-margin",
		                        this,
		                        "show-subject-margin",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("subject-margin-position",
		                        this,
		                        "subject-margin-position",
		                        SettingsBindFlags.GET);

		d_constructed = true;

		init_message_area();
	}

	private Gtk.TextTag d_subject_tag;
	private Gtk.TextTag d_too_long_tag;

	private void update_too_long_tag()
	{
		// Get the warning fg/bg colors
		var ctx = d_source_view_message.get_style_context();

		ctx.save();
		ctx.add_class("warning");

		var fg = ctx.get_color(Gtk.StateFlags.NORMAL);
		var bg = ctx.get_background_color(Gtk.StateFlags.NORMAL);

		ctx.restore();

		d_too_long_tag.background_rgba = bg;
		d_too_long_tag.foreground_rgba = fg;
	}

	private void init_message_area()
	{
		var b = d_source_view_message.buffer;

		d_subject_tag = b.create_tag("subject",
		                             "weight", Pango.Weight.BOLD);

		d_too_long_tag = b.create_tag("too-long");

		update_too_long_tag();

		d_source_view_message.style_updated.connect(() => {
			update_too_long_tag();
		});

		b.changed.connect(() => {
			do_highlight();
		});

		update_highlight();
	}

	private void update_highlight()
	{
		if (!d_constructed)
		{
			return;
		}

		d_source_view_message.show_right_margin = (d_show_markup && d_show_right_margin);
		d_source_view_message.right_margin_position = d_right_margin_position;

		do_highlight();
	}

	private void do_highlight()
	{
		var b = d_source_view_message.buffer;

		Gtk.TextIter start;
		Gtk.TextIter end;

		b.get_bounds(out start, out end);
		b.remove_tag(d_subject_tag, start, end);
		b.remove_tag(d_too_long_tag, start, end);

		if (!d_show_markup)
		{
			return;
		}

		Gtk.TextIter sstart;
		Gtk.TextIter send;

		if (!start.forward_search("\n\n",
		                          Gtk.TextSearchFlags.TEXT_ONLY,
		                          out sstart,
		                          out send,
		                          null))
		{
			sstart = end;
			send = end;
		}

		b.apply_tag(d_subject_tag, start, sstart);

		if (d_show_subject_margin)
		{
			var toolong = sstart;

			while (true)
			{
				var off = toolong.get_line_offset();

				if (off > d_subject_margin_position)
				{
					var border = toolong;
					border.set_line_offset(d_subject_margin_position);

					b.apply_tag(d_too_long_tag, border, toolong);
				}

				if (toolong.get_line() == 0)
				{
					break;
				}

				toolong.backward_line();
				toolong.forward_to_line_end();
			}
		}

		if (d_show_right_margin)
		{
			while (!send.equal(end))
			{
				if (!send.ends_line())
				{
					send.forward_to_line_end();
				}

				if (send.get_line_offset() > d_right_margin_position)
				{
					var lstart = send;
					lstart.set_line_offset(d_right_margin_position);

					b.apply_tag(d_too_long_tag, lstart, send);
				}

				if (!send.forward_line())
				{
					break;
				}
			}
		}
	}

	public Dialog(Ggit.Signature author)
	{
		Object(author: author);
	}

	private void update_font_settings()
	{
		var mfont = d_font_settings.get_string("monospace-font-name");
		var desc = Pango.FontDescription.from_string(mfont);

		d_source_view_message.override_font(desc);
	}
}

}

// ex: ts=4 noet
