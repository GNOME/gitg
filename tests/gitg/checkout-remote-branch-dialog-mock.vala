/*
 * This file is part of gitg
 *
 * Copyright (C) 2020 - Armandas Jarušauskas
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

class CheckoutRemoteBranchDialog : Gtk.Dialog
{
	public CheckoutRemoteBranchDialog(Gtk.Window? parent, Gitg.Repository? repository, Gitg.Ref reference)
	{
	}

	public string new_branch_name {get; set; default = "test_branch"; }

	public string remote_branch_name {get; set; default = "origin/test_branch"; }

	public bool track_remote {get; set; default = true; }

	public override void show()
	{
	}

	private bool entries_valid()
	{
		return (new_branch_name.length != 0) && (remote_branch_name.length != 0);
	}

	private void update_entries()
	{
	}
}

}

// ex: ts=4 noet
