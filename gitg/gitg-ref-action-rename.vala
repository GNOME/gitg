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

class RefActionRename : GitgExt.RefAction, GitgExt.Action, Object
{
	public Ggit.Ref reference { get; construct set; }
	public GitgExt.ActionInterface action_interface { get; construct set; }

	public string label
	{
		get { return "Rename"; }
	}

	public bool enabled
	{
		get { return true; }
	}

	public void activate()
	{
	}
}

}

// ex:set ts=4 noet
