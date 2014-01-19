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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-info-bar.ui")]
class InfoBar : Gtk.InfoBar
{
	[GtkChild]
	private Gtk.Label d_title_label;

	[GtkChild]
	private Gtk.Label d_message_label;

	private string d_title;
	private string d_message;

	public string title
	{
		get { return d_title; }
		set
		{
			d_title = value;

			var escaped = Markup.escape_text(d_title);
			d_title_label.set_markup(@"<b>$escaped</b>");
		}
	}

	public string message
	{
		get { return d_message; }
		set
		{
			d_message = value;

			var escaped = Markup.escape_text(d_message);

			d_message_label.set_markup(@"<small>$escaped</small>");
		}
	}

}

}

// ex:ts=4 noet
