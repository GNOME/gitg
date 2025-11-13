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

class RefActionSetUpstreamBranch : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionSetUpstreamBranch(GitgExt.Application        application,
	                             GitgExt.RefActionInterface action_interface,
	                             Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public override bool enabled
	{
		get
		{
			try
			{
				return reference.is_branch() && !reference.is_remote();
			} catch {}

			return false;
		}
	}

	public override string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/set-upstream-branch"; }
	}

	public virtual string description
	{
		owned get { return _("Set Upstream repo for branch selected"); }
	}

	public string display_name
	{
		owned get { return _("Set Upstream branch…"); }
	}

	public virtual void activate()
	{
		var dlg = new SetUpstreamBranchDialog((Gtk.Window)application, application.repository, reference);

		dlg.response.connect((d, resp) => {
			if (resp == Gtk.ResponseType.OK)
			{
				Gitg.Branch? branch = null;
				try
				{
					branch = reference as Gitg.Branch;
					var upstream = dlg.remote_branch_name;
					if (upstream == "")
						upstream = null;
					branch.set_upstream(upstream);
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to set upstream to branch"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}

				//if (branch != null)
				//{
				//	action_interface.add_ref((Gitg.Ref)branch);
				//}
			}

			dlg.destroy();
			finished();
		});

		dlg.show();
	}
}

}

// ex: set ts=4 expandtab:
