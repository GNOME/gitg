/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Sindhu S
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
	[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-start-dialog.ui")]
	public class RebaseStartDialog : Gtk.Dialog
	{
		[GtkChild (name = "rebase_spinbutton")]
		private Gtk.SpinButton r_rebase_spinbutton;
		private string repository_path;

		public RebaseStartDialog(Gitg.Repository repository)
		{
			File? workdir = repository.get_workdir();
			r_rebase_spinbutton.set_range(0,30);
			repository_path = workdir.get_path();
		}

		public override void response(int id) {
			if (id == Gtk.ResponseType.OK)
			{
				var rebase_controller = new RebaseController(repository_path);
				int num_of_commits = 5;
				// FIXME: User should be able to enter N
				// int num_of_commits = r_rebase_spinbutton.get_value_as_int();
			}
			destroy();
		}


	}
}