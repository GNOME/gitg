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

	private Settings d_fontsettings;

	public GtkSource.View source_view_message
	{
		get { return d_source_view_message; }
	}

	public string message
	{
		owned get
		{
			var b = d_source_view_message.buffer;

			Gtk.TextIter start;
			Gtk.TextIter end;

			b.get_bounds(out start, out end);
			return Ggit.message_prettify(b.get_text(start, end, false), false);
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
			d_button_ok.sensitive = message != "";
		});
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
