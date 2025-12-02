/*
 * This file is part of gitg
 *
 * Copyright (C) 2017 - Ignazio Sgalmuzzo
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

class RefActionPush : CommitActionPush, GitgExt.RefAction
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public Gitg.Ref reference { get; construct set; }

	public RefActionPush(GitgExt.Application        application,
	                      GitgExt.RefActionInterface action_interface,
	                      Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public override string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/push"; }
	}

	public override string description
	{
		owned get { return _("Push ref to a remote"); }
	}

	public override string get_ref_name()
	{
		return reference.get_name();
	}

	public override string get_ref_shortname()
	{
		return reference.parsed_name.shortname;
	}

	public override Object get_ref()
	{
		return reference;
	}

	public bool available
	{
		get { return !reference.is_remote(); }
	}


	protected override void after_successful_push(bool set_upstream, string remote_name, string
												 remote_ref_name)
	{
		if (set_upstream && reference.is_branch())
		{
			var branch = reference as Gitg.Branch;
			try
			{
				var upstream_ref = @"$remote_name/$remote_ref_name";
				branch.set_upstream(upstream_ref);
			} catch {}
		}
	}
}
}

// ex:set ts=4 noet
