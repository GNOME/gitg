/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Sindhu S
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
	class DiffViewRequestPatch : DiffViewRequest
	{
		private Ggit.Commit? d_commit;

		public DiffViewRequestPatch (DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
		{
			base(view, request, uri);

			if (has_view)
			{
				d_commit = view.commit;
				// set the view to null else it won't run the request
				d_view = null;
				d_hasView = false;
			}
		}

		private void create_patch (Gitg.Commit selected_commit, File file)
		{
			string commit_message = selected_commit.get_message();
			string sha1 = selected_commit.get_id().to_string();
			string legacydate = "Mon Sep 17 00:00:00 2001";
			string author = selected_commit.get_author().get_name();
			string author_email = selected_commit.get_author().get_email();
			string datetime = selected_commit.get_author().get_time().format("%a, %e %b %Y %T %z");
			string patch_content = "";
			try
			{
				Ggit.Diff diff = selected_commit.get_diff(null);

				var number_of_deltas = diff.get_num_deltas();

				patch_content += "From %s %s".printf(sha1, legacydate);
				patch_content += "\nFrom: %s <%s>".printf(author, author_email);
				patch_content += "\nDate: %s".printf(datetime);
				patch_content += "\nSubject: [PATCH] %s\n\n".printf(commit_message);

				for (var i = 0; i < number_of_deltas; i++)
				{
					var patch = new Ggit.Patch.from_diff(diff, i);
					patch_content += patch.to_string();
				}

				patch_content += "--\n";
				patch_content += "Gitg\n\n";

				FileUtils.set_contents(file.get_path(), patch_content);
			}
			catch (Error e)
			{
				// TODO: Route error message to Infobar?
				stdout.printf("Failed: %s".printf(e.message));
			}
		}

		protected override InputStream? run_async(Cancellable? cancellable)
		{
			var selected_commit = (Gitg.Commit) d_commit;
			string commit_subject = selected_commit.get_subject();

			try
			{
				var subject_regex = new Regex("[^\\d\\w \\_\\-]");

				// remove anything that's not:
				// a) alpha numeric
				// b) underscore or hyphens
				// c) single space
				commit_subject = subject_regex.replace(commit_subject, commit_subject.length, 0, "");
				// replace single space with hyphen
				commit_subject = commit_subject.replace(" ", "-");
			}
			catch (Error e)
			{
				// use an empty default filename
				commit_subject = "";
			}

			// Show file chooser and finish create patch in idle.
			Idle.add(() => {
				if (cancellable.is_cancelled())
				{
					return false;
				}

				var chooser = new Gtk.FileChooserDialog(_("Save Patch File"), null,
				                                        Gtk.FileChooserAction.SAVE,
				                                        _("_Cancel"),
				                                        Gtk.ResponseType.CANCEL,
				                                        _("_Save"),
				                                        Gtk.ResponseType.OK);

				chooser.do_overwrite_confirmation = true;
				chooser.set_current_name(commit_subject + ".patch");

				chooser.show();
				chooser.response.connect((dialog, id) => {
					if (!cancellable.is_cancelled() && id != -6)
					{
						create_patch (selected_commit, chooser.get_file());
					}

					chooser.destroy();
				});

				return false;
			});

			return null;
		}
	}
}

// ex:ts=4 noet
