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
	public class RebaseCommitEditorWindow : Gtk.Window
	{
		private GtkSource.View r_commit_editor;
		private string r_filepath;

		public RebaseCommitEditorWindow()
		{
			this.title = "Rebase Commit Editor";
			destroy.connect (Gtk.main_quit);
			r_commit_editor = new GtkSource.View();
			var hbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
			hbox.homogeneous = true;
			hbox.add (r_commit_editor);
			var save_button = new Gtk.Button();
			save_button.label = "Save and load next...";
			save_button.clicked.connect(save_and_continue);
			hbox.add(save_button);
			add (hbox);
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