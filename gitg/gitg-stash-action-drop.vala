/*
 * This file is part of gitg
 *
 * Copyright (C) 2025 - Alberto Fanjul
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

class StashActionDrop : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Ggit.OId oid { get; construct set; }
	public size_t index { get; construct set; }

	public StashActionDrop(GitgExt.Application        application,
	                       GitgExt.RefActionInterface action_interface,
	                       Ggit.OId                   oid,
	                       size_t                     index)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       oid:              oid,
		       index:            index);
	}

	public override string id
	{
		owned get { return "/org/gnome/gitg/stash-actions/drop"; }
	}

	public string display_name
	{
		owned get { return _("Drop stash"); }
	}

	public override string description
	{
		owned get { return _("Drop selected stash"); }
	}

	public void activate()
	{
		var dlg = new Gtk.MessageDialog(application as Gtk.Window,
		                                0,
		                                Gtk.MessageType.WARNING,
		                                Gtk.ButtonsType.OK_CANCEL,
		                                "%s",
		                                @"Are you sure to drop stash \"$index\"");

		dlg.window_position = Gtk.WindowPosition.CENTER;

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				application.repository.drop_stash(index);
				action_interface.refresh();
			}
			dlg.destroy();
		});
		dlg.show();
	}
}

}

// ex:set ts=4 noet
