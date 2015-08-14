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

class CommitActionCreateBranch : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }

	public CommitActionCreateBranch(GitgExt.Application        application,
	                                GitgExt.RefActionInterface action_interface,
	                                Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/create-branch"; }
	}

	public string display_name
	{
		owned get { return _("Create branch"); }
	}

	public string description
	{
		owned get { return _("Create a new branch at the selected commit"); }
	}

	public void activate()
	{
		var dlg = new CreateBranchDialog((Gtk.Window)application);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Ggit.Branch? branch = null;

				var repo = application.repository;

				try
				{
					branch = repo.create_branch(dlg.new_branch_name,
					                            commit,
					                            Ggit.CreateFlags.NONE);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to create branch"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				if (branch != null)
				{
					action_interface.add_ref((Gitg.Ref)branch);
				}
			}

			dlg.destroy();
			finished();
		});

		dlg.show();
	}
}

}

// ex:set ts=4 noet
