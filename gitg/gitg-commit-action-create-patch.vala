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

namespace Gitg
{

class CommitActionCreatePatch : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }
	public Ggit.Diff? diff { get; set; }

	private static Regex s_subject_regex;

	static construct
	{
		try
		{
			s_subject_regex = new Regex("[^\\d\\w \\_\\-]");
		}
		catch (Error e)
		{
			stderr.printf(@"Failed to compile subject regex: $(e.message)\n");
		}
	}

	public CommitActionCreatePatch(GitgExt.Application        application,
	                            GitgExt.RefActionInterface action_interface,
	                            Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);
	}

	public virtual string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/create-patch"; }
	}

	public string display_name
	{
		owned get { return _("Create patch…"); }
	}

	public virtual string description
	{
		owned get { return _("Create a patch from the selected commit"); }
	}

	private string patch_filename(int i)
	{
		string subject = commit.get_subject();

		// Remove anything that is not:
		//   a) alpha numeric
		//   b) underscore or hyphens
		//   c) single space
		try
		{
			subject = s_subject_regex.replace(subject, subject.length, 0, "");
			subject = subject.replace(" ", "-");

			subject = "%04d-%s".printf(i, subject);
		}
		catch
		{
			return "";
		}

		return subject + ".patch";
	}

	private Ggit.Diff create_diff_from_commit() throws Error
	{
		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.diff");

		var opts = new Ggit.DiffOptions();

		if (settings.get_boolean("ignore-whitespace"))
		{
			opts.flags |= Ggit.DiffOption.IGNORE_WHITESPACE;
		}

		if (settings.get_boolean("patience"))
		{
			opts.flags |= Ggit.DiffOption.PATIENCE;
		}

		var nc = settings.get_int("context-lines");

		opts.n_context_lines = nc;
		opts.n_interhunk_lines = nc;

		opts.flags |= Ggit.DiffOption.SHOW_BINARY;

		return commit.get_diff(opts, 0);
	}

	private void create_patch(File file) throws Error
	{
		// Create diff if needed
		if (diff == null)
		{
			diff = create_diff_from_commit();
		}

		var opts = new Ggit.DiffFormatEmailOptions();

		var message = commit.get_message();
		opts.summary = message;
		var pos = message.index_of_char('\n');
		if (pos != -1 && pos + 1 != message.length)
			opts.body = message.substring(pos + 2, message.length - (pos + 2));
		opts.patch_number = 1;
		opts.total_patches = 1;
		opts.id = commit.get_id();
		opts.author = commit.get_author();

		var content = diff.format_email(opts);

		file.replace_contents(content.data[0:content.length],
		                      null,
		                      false,
		                      FileCreateFlags.NONE,
		                      null,
		                      null);
	}

	public virtual void activate()
	{
		var chooser = new Gtk.FileChooserDialog(_("Save Patch File"), null,
		                                        Gtk.FileChooserAction.SAVE,
		                                        _("_Cancel"),
		                                        Gtk.ResponseType.CANCEL,
		                                        _("_Save Patch"),
		                                        Gtk.ResponseType.OK);

		chooser.set_default_response(Gtk.ResponseType.OK);

		chooser.do_overwrite_confirmation = true;
		chooser.set_current_name(patch_filename(1));

		try
		{
			chooser.set_current_folder_file(application.repository.get_workdir());
		} catch {}

		chooser.set_transient_for((Gtk.Window)application);

		chooser.show();
		chooser.response.connect((dialog, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				try
				{
					create_patch(chooser.get_file());
				}
				catch (Error e)
				{
					application.show_infobar(_("Failed to create patch"),
					                         e.message,
					                         Gtk.MessageType.ERROR);
				}
			}

			chooser.destroy();
			finished();
		});
	}
}

}

// ex:set ts=4 noet
