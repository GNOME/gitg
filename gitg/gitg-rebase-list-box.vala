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
	public class RepositoryListBox : Gtk.ListBox
	{
		[GtkTemplate (ui = "/org/gnome/gitg/gtk/gitg-rebase-list-box-row.ui")]
		private class Row : Gtk.ListBoxRow
		{
			[GtkChild]
			private Gtk.Label r_commit_sha;
			[GtkChild]
			private Gtk.Label r_commit_msg;

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

			public Row(string commit_sha, string commit_msg)
			{
				Object(commit_sha: commit_sha, commit_msg: commit_msg);
			}
		}
	}

}

// ex:ts=4 noet
