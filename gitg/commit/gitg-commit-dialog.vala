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
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

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

	[GtkChild (name = "infobar")]
	private Gtk.InfoBar d_infobar;

	[GtkChild (name = "infobar_revealer")]
	private Gtk.Revealer d_infobar_revealer;

	[GtkChild (name = "infobar_primary_label")]
	private Gtk.Label d_infobar_primary_label;

	[GtkChild (name = "infobar_secondary_label")]
	private Gtk.Label d_infobar_secondary_label;

	[GtkChild (name = "infobar_close_button")]
	private Gtk.Button d_infobar_close_button;

	[GtkChild (name = "list_box_stats")]
	private Gtk.ListBox d_list_box_stats;

	[GtkChild (name = "scrolled_window_stats")]
	private Gtk.ScrolledWindow d_scrolled_window_stats;

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
	private bool d_enable_spell_checking;
	private string? d_spell_checking_language;
	private GtkSpell.Checker? d_spell_checker;
	private Ggit.Diff d_diff;

	public Ggit.Diff? diff
	{
		owned get { return d_diff; }
		construct set { d_diff = value; }
	}

	public int max_visible_stat_items
	{
		get;
		construct set;
		default = 3;
	}

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

	[Notify]
	public string? spell_checking_language
	{
		get { return d_spell_checking_language; }

		set
		{
			d_spell_checking_language = value;
			set_spell_language();
		}
	}

	[Notify]
	public bool enable_spell_checking
	{
		get { return d_enable_spell_checking; }
		set
		{
			d_enable_spell_checking = value;

			if (d_enable_spell_checking)
			{
				if (d_spell_checker == null)
				{
					d_spell_checker = new GtkSpell.Checker();
					d_spell_checker.attach(d_source_view_message);

					set_spell_language();

					d_spell_checker.language_changed.connect(() => {
						spell_checking_language = d_spell_checker.get_language();
					});
				}
			}
			else
			{
				if (d_spell_checker != null)
				{
					d_spell_checker.detach();
					d_spell_checker = null;
				}
			}
		}
	}

	private void set_spell_language()
	{
		if (d_spell_checker != null && d_spell_checking_language != "")
		{
			try
			{
				d_spell_checker.set_language(d_spell_checking_language);
			}
			catch
			{
				warning(_("Cannot set spell checking language: %s"), d_spell_checking_language);
				d_spell_checking_language = "";
			}
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

		d_message_settings.bind("enable-spell-checking",
		                        this,
		                        "enable-spell-checking",
		                        SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_message_settings.bind("spell-checking-language",
		                        this,
		                        "spell-checking-language",
		                        SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_constructed = true;

		init_message_area();

		if (diff != null)
		{
			iterate_diff();
		}
		else
		{
		}
	}

	private Gtk.TextTag d_subject_tag;
	private Gtk.TextTag d_too_long_tag;

	private void iterate_diff()
	{
		var n = diff.get_num_deltas();
		int num = 0;

		for (var i = 0; i < n; ++i)
		{
			Ggit.Patch patch;

			try
			{
				patch = new Ggit.Patch.from_diff(diff, i);
			} catch { continue; }

			size_t add;
			size_t remove;

			try
			{
				patch.get_line_stats(null, out add, out remove);
			} catch { continue; }

			var delta = patch.get_delta();

			var nf = delta.get_new_file();
			var path = nf.get_path();

			var row = new Gtk.ListBoxRow();
			var grid = new Gtk.Grid();
			row.add(grid);
			grid.column_spacing = 6;

			var ds = new Gitg.DiffStat();

			ds.added = (uint)add;
			ds.removed = (uint)remove;

			grid.attach(ds, 0, 0, 1, 1);

			var lbl = new Gtk.Label(path);

			grid.attach(lbl, 1, 0, 1, 1);
			row.show_all();

			d_list_box_stats.add(row);
			++num;
		}

		d_list_box_stats.size_allocate.connect(() => {
			update_min_stat_size(num);
		});
	}

	private void update_min_stat_size(int num)
	{
		if (num == 0)
		{
			d_scrolled_window_stats.hide();
			return;
		}

		int n = int.min(num, max_visible_stat_items);

		var lastrow = d_list_box_stats.get_row_at_index(n - 1);

		Gtk.Allocation allocation;
		lastrow.get_allocation(out allocation);

		if (n == num)
		{
			d_scrolled_window_stats.set_policy(Gtk.PolicyType.NEVER,
			                                   Gtk.PolicyType.NEVER);
		}

		d_scrolled_window_stats.set_min_content_height(allocation.y + allocation.height);
	}

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

	private bool on_commit_message_key_press_event(Gtk.Widget widget, Gdk.EventKey event)
	{
		var mmask = Gtk.accelerator_get_default_mod_mask();

		if ((mmask & event.state) == Gdk.ModifierType.CONTROL_MASK &&
		    (event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter))
		{
			d_button_ok.activate();
			return true;
		}

		return false;
	}

	private void init_message_area()
	{
		d_source_view_message.key_press_event.connect(on_commit_message_key_press_event);

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

	public Dialog(Ggit.Signature author,
	              Ggit.Diff?     diff)
	{
		Object(author: author, diff: diff);
	}

	private void update_font_settings()
	{
		var mfont = d_font_settings.get_string("monospace-font-name");
		var desc = Pango.FontDescription.from_string(mfont);

		d_source_view_message.override_font(desc);
	}

	public void show_infobar(string          primary_msg,
	                         string          secondary_msg,
	                         Gtk.MessageType type)
	{
		d_infobar.message_type = type;

		var primary = "<b>%s</b>".printf(Markup.escape_text(primary_msg));
		var secondary = "<small>%s</small>".printf(Markup.escape_text(secondary_msg));

		d_infobar_primary_label.set_label(primary);
		d_infobar_secondary_label.set_label(secondary);
		d_infobar_revealer.set_reveal_child(true);

		d_infobar_close_button.clicked.connect(() => {
			d_infobar_revealer.set_reveal_child(false);
		});
	}
}

}

// ex: ts=4 noet
