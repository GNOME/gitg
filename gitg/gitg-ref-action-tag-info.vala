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

class RefActionTagShowInfo : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public bool available
	{
		get
		{
			return reference.is_tag();
		}
	}

	public override string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/tag-show-info"; }
	}

	public string display_name
	{
		owned get { return _("Show tag info"); }
	}

	public virtual string description
	{
		owned get { return _("Show info at selected tag"); }
	}

	public virtual void activate()
	{
		var dlg = new TagShowInfoDialog((Gtk.Window)application, reference);

		dlg.response.connect((d, resp) => {

			dlg.destroy();
			finished();
		});
		dlg.show();
	}

	public RefActionTagShowInfo(GitgExt.Application        application,
	                            GitgExt.RefActionInterface action_interface,
	                            Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}
}

}

// ex:set ts=4 noet
