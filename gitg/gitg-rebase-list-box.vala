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
	public class RebaseListBox : Gtk.ListBox
	{
		[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-list-box-row.ui")]
		private class Row : Gtk.ListBoxRow
		{
			[GtkChild]
			private Gtk.Label r_commit_sha;
			[GtkChild]
			private Gtk.Label r_commit_msg;
			[GtkChild]
			private Gtk.ComboBox r_commit_action;

			public string? commit_sha
			{
				get { return r_commit_sha.get_text(); }
				set { r_commit_sha.set_markup("<b>%s</b>".printf(value)); }
			}

			public string? commit_msg
			{
				get { return r_commit_msg.get_text(); }
				set { r_commit_msg.set_markup("<b>%s</b>".printf(value)); }
			}

			public string? commit_action
			{
				get {
/*
						Gtk.TreeIter selected_iter;
						r_commit_action.get_active_iter(out selected_iter);
						Value action_name = new Value();
						r_commit_action.get_model().get_value(selected_iter, 0, out action_name);
						return action_name.get_string();
*/
						int action_id = r_commit_action.active;
						switch(action_id)
						{
							case 0: return "pick";
							case 1: return "squash";
							case 2: return "fixup";
							case 3: return "reword";
						}
						return "pick";
				}
				set {
						var action_id = 0;
						switch (value)
						{
							case "pick": action_id = 0;
										 break;
							case "squash": action_id = 1;
										   break;
							case "fixup": action_id = 2;
										  break;
							case "reword": action_id = 3;
										   break;
						}

						r_commit_action.set_active(action_id);
					}
			}

			public Row(string commit_action, string commit_sha, string commit_msg)
			{
				Object(commit_action: commit_action, commit_sha: commit_sha, commit_msg: commit_msg);
			}
		}

		public void add_rebase_row(string action, string sha, string msg)
		{
			var row = new Row (action, sha, msg);
			row.show();
			add(row);
		}

		construct {
			show ();
		}

		public Gee.ArrayList<Gee.ArrayList<string>> get_rebase_array()
		{
			Gee.ArrayList<Gee.ArrayList<string>> rebase_array = new Gee.ArrayList<Gee.ArrayList<string>>();
			foreach (var child in get_children())
			{
				var row = (Row) child;
				Gee.ArrayList<string> rebase_row = new Gee.ArrayList<string>();
				rebase_row.add(row.commit_action);
				rebase_row.add(row.commit_sha);
				rebase_row.add(row.commit_msg);
				rebase_array.add(rebase_row);
			}
			return rebase_array;
		}

	}

}

// ex:ts=4 noet
