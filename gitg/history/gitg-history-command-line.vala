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

namespace GitgHistory
{

class CommandLine : Object, GitgExt.CommandLine
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private static string? s_select_reference;
	private string? d_select_reference;

	public string select_reference
	{
		get { return d_select_reference; }
	}

	private static bool select_all_commits()
	{
		s_select_reference = "*";
		return true;
	}

	private static const OptionEntry[] s_entries = {
		{ "all", 'a', OptionFlags.IN_MAIN | OptionFlags.NO_ARG, OptionArg.CALLBACK, (void *)select_all_commits,
		  N_("Select all commits by default in the history activity (shorthand for --select-reference '*')"), null },
		{ "select-reference", 's', OptionFlags.IN_MAIN, OptionArg.STRING, ref s_select_reference,
		  N_("Select the specified reference by default in the history activity"), N_("REFERENCE") },

		{null}
	};

	public OptionGroup get_option_group()
	{
		var group = new OptionGroup("", "", "");
		group.add_entries(s_entries);

		return group;
	}

	public void parse_finished()
	{
		d_select_reference = s_select_reference;
	}

	public void apply(GitgExt.Application application)
	{
		var history = application.get_activity_by_id("/org/gnome/gitg/Activities/History") as Activity;

		if (history == null)
		{
			return;
		}

		if (d_select_reference == "*")
		{
			history.refs_list.select_all_commits();
		}
		else if (d_select_reference != null)
		{
			try
			{
				history.refs_list.select_ref(application.repository.lookup_reference_dwim(d_select_reference));
			}
			catch (Error e)
			{
				stderr.printf("Failed to lookup reference %s: %s\n", d_select_reference, e.message);
			}
		}
	}
}

}

// ex: ts=4 noet
