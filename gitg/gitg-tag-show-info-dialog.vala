/*
 * This file is part of gitg
 *
 * Copyright (C) 2023 - Alberto Fanjul
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-tag-show-info-dialog.ui")]
class TagShowInfoDialog : Gtk.Dialog
{
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private unowned Gtk.Label d_name;

	[GtkChild]
	private unowned Gtk.Label d_message;

	construct
	{
		set_default_response(Gtk.ResponseType.OK);
	}

	public TagShowInfoDialog(Gtk.Window? parent, Gitg.Ref reference)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
		var tag = (Ggit.Tag)reference.resolve().lookup();

		var name = tag.get_name();
	    d_name.set_markup(@"<b>$name</b>");
	    d_message.set_text(tag.get_message());
	}
}

}

// ex: ts=4 noet
