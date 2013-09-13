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
	[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-window.ui")]
	public class RebaseWindow : Gtk.Window
	{
		[GtkChild (name = "rebase_listbox")]
		private RebaseListBox r_rebase_list_box;

		[GtkChild (name = "start_rebase_button")]
		private Gtk.Button r_rebase_start_button;

		[GtkChild (name = "abort_rebase_button")]
		private Gtk.Button r_rebase_abort_button;

		private string r_filepath;
		public RebaseWindow()
		{
			destroy.connect (Gtk.main_quit);
			r_rebase_start_button.clicked.connect(start_rebase);
			r_rebase_abort_button.clicked.connect(abort_rebase);
		}

		public void load_rebase_todo(string filepath)
		{
			r_filepath = filepath;
			var parser = new RebaseParser();
			var rebase_array = parser.parse_rebase_todo(r_filepath);
			foreach (var rebase_row in rebase_array)
			{
				r_rebase_list_box.add_rebase_row(rebase_row[0], rebase_row[1], rebase_row[2]);
			}
		}

		private void start_rebase()
		{
			var parser = new RebaseParser();
			var rebase_array = r_rebase_list_box.get_rebase_array();
			string rebase_output = "";
			rebase_output = parser.generate_rebase_todo(rebase_array);
			stdout.printf("\nrebase_output: \n%s", rebase_output);
			try
			{
				FileUtils.set_contents(r_filepath, rebase_output);
			}
			catch {}
			destroy();
		}

		private void abort_rebase()
		{
			try
			{
				FileUtils.set_contents(r_filepath, "");
			}
			catch {}
			destroy();
		}
	}

}