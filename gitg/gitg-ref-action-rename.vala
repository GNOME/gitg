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

class RefActionRename : GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionRename(GitgExt.RefActionInterface action_interface, Gitg.Ref reference)
	{
		Object(action_interface: action_interface, reference: reference);
	}

	public string label
	{
		get { return _("Rename"); }
	}

	public bool visible
	{
		get { return true; }
	}

	public bool enabled
	{
		get
		{
			return    reference.is_branch()
			       || reference.is_tag();
		}
	}

	public void activated()
	{
		action_interface.edit_ref_name(reference, on_ref_name_editing_done);
	}

	private void on_ref_name_editing_done(string new_text, bool cancelled)
	{
		if (cancelled)
		{
			return;
		}

		string orig;
		string? prefix;

		var pn = reference.parsed_name;

		if (pn.rtype == Gitg.RefType.REMOTE)
		{
			orig = pn.remote_branch;
			prefix = pn.prefix + "/" + pn.remote_name + "/";
		}
		else
		{
			orig = pn.shortname;
			prefix = pn.prefix;
		}

		if (orig == new_text)
		{
			return;
		}

		if (!Ggit.Ref.is_valid_name(@"$prefix$new_text"))
		{
			var msg = _("The specified name ‘%s’ contains invalid characters").printf(new_text);

			action_interface.application.show_infobar(_("Invalid name"),
			                                          msg,
			                                          Gtk.MessageType.ERROR);

			return;
		}

		var branch = reference as Ggit.Branch;
		Gitg.Ref? new_ref = null;

		try
		{
			if (branch != null)
			{
				new_ref = branch.move(new_text, Ggit.CreateFlags.NONE) as Gitg.Ref;
			}
			else
			{
				new_ref = reference.rename(new_text, false) as Gitg.Ref;
			}
		}
		catch (Error e)
		{
			action_interface.application.show_infobar(_("Failed to rename"),
			                                          e.message,
			                                          Gtk.MessageType.ERROR);

			return;
		}

		action_interface.application.repository.clear_refs_cache();
		action_interface.replace_ref(reference, new_ref);
	}
}

}

// ex:set ts=4 noet
