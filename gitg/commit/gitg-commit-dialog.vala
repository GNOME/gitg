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

	private Settings d_fontsettings;

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
		d_label_date.set_label((new Gitg.Date.for_date_time(d_author.get_time())).for_display());

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

	private Ggit.Signature d_author;
	private Cancellable? d_cancel_avatar;

	~Dialog()
	{
		if (d_cancel_avatar != null)
		{
			d_cancel_avatar.cancel();
		}
	}

	construct
	{
		d_fontsettings = new Settings("org.gnome.desktop.interface");

		update_font_settings();

		d_fontsettings.changed["monospace-font-name"].connect((s, k) => {
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

		var commit_settings = new Settings("org.gnome.gitg.state.commit");

		commit_settings.bind("sign-off",
		                     this,
		                     "sign-off",
		                     SettingsBindFlags.GET |
		                     SettingsBindFlags.SET);

		var message_settings = new Settings("org.gnome.gitg.preferences.commit.message");

		message_settings.bind("show-right-margin",
		                      d_source_view_message,
		                      "show-right-margin",
		                      SettingsBindFlags.GET |
		                      SettingsBindFlags.SET);

		message_settings.bind("right-margin-at",
		                      d_source_view_message,
		                      "right-margin-position",
		                      SettingsBindFlags.GET |
		                      SettingsBindFlags.SET);
	}

	public Dialog(Ggit.Signature author)
	{
		Object(author: author);
	}

	private void update_font_settings()
	{
		var mfont = d_fontsettings.get_string("monospace-font-name");
		var desc = Pango.FontDescription.from_string(mfont);

		d_source_view_message.override_font(desc);
	}
}

}

// ex: ts=4 noet
