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
	public class RebaseResultDialog: Gtk.Dialog
	{
		private Gtk.TextView output_view;

		public RebaseResultDialog()
		{
			this.title = "Rebase Result";
			output_view = new Gtk.TextView();
			var hbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 1);
			hbox.homogeneous = true;
			hbox.add (output_view);
			var ok_button = new Gtk.Button();
			ok_button.label = "Return to gitg";
			ok_button.clicked.connect(return_to_gitg);
			hbox.add(ok_button);
			add (hbox)
		}

		public void set_rebase_output(string output)
		{
			output_view.buffer.set_text(output);
		}

		public void return_to_gitg()
		{

		}
	}
}