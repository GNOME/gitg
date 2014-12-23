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

class RefActionFetch : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	private Gitg.Ref? d_remote_ref;
	private Gitg.Remote? d_remote;

	public RefActionFetch(GitgExt.Application        application,
	                      GitgExt.RefActionInterface action_interface,
	                      Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);

		var branch = reference as Ggit.Branch;

		if (branch != null)
		{
			try
			{
				d_remote_ref = branch.get_upstream() as Gitg.Ref;
			} catch {}
		}
		else if (reference.parsed_name.remote_name != null)
		{
			d_remote_ref = reference;
		}

		if (d_remote_ref != null)
		{
			d_remote = application.remote_lookup.lookup(d_remote_ref.parsed_name.remote_name);
		}
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/fetch"; }
	}

	public string display_name
	{
		owned get
		{
			if (d_remote != null)
			{
				return _("Fetch from %s").printf(d_remote_ref.parsed_name.remote_name);
			}
			else
			{
				return "";
			}
		}
	}

	public string description
	{
		owned get { return _("Fetch remote objects from %s").printf(d_remote_ref.parsed_name.remote_name); }
	}

	public bool available
	{
		get { return d_remote != null; }
	}

	public void activate()
	{
		Ggit.Signature sig;

		try
		{
			sig = application.repository.get_signature_with_environment(application.environment);
		}
		catch (Error e)
		{
			stderr.printf("Failed to get signature: %s\n", e.message);
			return;
		}

		d_remote.fetch.begin(sig, null, (obj, res) =>{
			try
			{
				d_remote.fetch.end(res);
			}
			catch (Error e)
			{
				stderr.printf("Failed to fetch: %s\n", e.message);
			}
		});
	}
}

}

// ex:set ts=4 noet
