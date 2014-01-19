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

class RefActionDelete : GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionDelete(GitgExt.RefActionInterface action_interface, Gitg.Ref reference)
	{
		Object(action_interface: action_interface, reference: reference);
	}

	public string label
	{
		get { return _("Delete"); }
	}

	public bool enabled
	{
		get
		{
			return    reference.is_branch()
			       || reference.is_tag()
			       || reference.is_remote();
		}
	}

	public bool visible
	{
		get { return true; }
	}

	public void activated()
	{
	}
}

}

// ex:set ts=4 noet
