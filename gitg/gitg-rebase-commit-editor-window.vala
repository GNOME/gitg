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
	[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-commit-editor.ui")]
	public class RebaseCommitEditorWindow : Gtk.Window
	{
		[GtkChild (name = "commit_editor")]
		private GtkSource.View r_commit_editor;

		[GtkChild (name = "continue_rebase_button")]
		private Gtk.Button r_rebase_continue_button;

		[GtkChild (name = "abort_rebase_button")]
		private Gtk.Button r_rebase_abort_button;

		private string r_filepath;

		public RebaseCommitEditorWindow()
		{
			destroy.connect (Gtk.main_quit);
			r_rebase_continue_button.clicked.connect(save_and_continue);
		}

		public void load_commit_file(string filename)
		{
			r_filepath = filename;
			string contents = "";

			try
			{
				FileUtils.get_contents(filename, out contents);
			}
			catch {}

			r_commit_editor.buffer.set_text(contents);
		}

		private void save_and_continue()
		{
			var buffer = r_commit_editor.buffer;
			Gtk.TextIter start, end;
			buffer.get_bounds(out start, out end);
			string contents = buffer.get_text(start, end, false);
			try
			{
				FileUtils.set_contents(r_filepath, contents);
			}
			catch {}
			destroy();
		}
	}

}