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
	[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-result-dialog.ui")]
	public class RebaseResultDialog: Gtk.Dialog
	{
		[GtkChild (name = "rebase_result_output")]
		private Gtk.TextView r_result_output;

		public RebaseResultDialog()
		{}

		public void set_rebase_output(string output)
		{
			r_result_output.buffer.set_text(output);
		}

		public void return_to_gitg()
		{

		}
	}
}