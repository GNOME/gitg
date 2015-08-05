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

namespace GitgCommit
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-submodule-info.ui")]
class SubmoduleInfo : Gtk.Grid
{
	[GtkChild (name = "label_path")]
	private Gtk.Label d_label_path;

	[GtkChild (name = "label_url")]
	private Gtk.Label d_label_url;

	[GtkChild (name = "label_sha1")]
	private Gtk.Label d_label_sha1;

	[GtkChild (name = "label_subject")]
	private Gtk.Label d_label_subject;

	private Ggit.Submodule d_submodule;

	public signal void request_open_repository(Ggit.Submodule submodule);

	private void update_info_from_repository(Ggit.OId oid, Ggit.Submodule submodule)
	{
			Gitg.Repository repo;

			d_label_subject.set_text("");

			try
			{
				repo = submodule.open() as Gitg.Repository;
			}
			catch (Error e)
			{
				return;
			}

			try
			{
				var commit = repo.lookup<Gitg.Commit>(oid);

				if (commit != null)
				{
					d_label_subject.set_text(commit.get_subject());
				}
			}
			catch (Error e)
			{
			}
	}

	public Ggit.Submodule? submodule
	{
		set
		{
			d_submodule = value;

			if (value != null)
			{
				d_label_path.set_text(value.get_path());
				var submodule_url = value.get_url();
				d_label_url.set_text(submodule_url != null ? submodule_url : "");

				var oid = value.get_workdir_id();
				d_label_sha1.set_text(oid.to_string());

				update_info_from_repository(oid, value);
			}
		}
	}

	[GtkCallback]
	private void on_open_button_clicked()
	{
		request_open_repository(d_submodule);
	}
}

}
