/*
 * This file is part of gitg
 *
 * Copyright (C) 2022 - Adwait Rawat
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

class RefActionCreatePatch : CommitActionCreatePatch, GitgExt.RefAction
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public Gitg.Ref reference { get; construct set; }

	public RefActionCreatePatch(GitgExt.Application        application,
	                            GitgExt.RefActionInterface action_interface,
	                            Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public override string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/create-patch"; }
	}

	public override string description
	{
		owned get { return _("Create a patch from the selected reference"); }
	}

	public override void activate()
	{
		try
		{
			commit = reference.resolve().lookup() as Gitg.Commit;
			base.activate();
		}
		catch (Error e)
		{
			application.show_infobar (_("Failed to lookup reference"),
			                          e.message,
			                          Gtk.MessageType.ERROR);
			return;
		}
	}
}

}

// ex:set ts=4 noet
