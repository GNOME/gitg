/*
 * This file is part of gitg
 *
 * Copyright (C) 2022 - Adwait Rawat
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

class FetchAllRemotesAction : GitgExt.UIElement, GitgExt.Action, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgHistory.RefsList refs_list;

	public FetchAllRemotesAction(GitgExt.Application application, GitgHistory.RefsList refs_list)
	{
		Object(application: application);
		this.refs_list = refs_list;
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/fetch-all-remotes"; }
	}

	public string display_name
	{
		owned get { return _("Fetch all remotes"); }
	}

	public string description
	{
		owned get { return _("Fetch objects from all remotes"); }
	}

	public void activate()
	{
		refs_list.references.foreach((r) => {
			var remote_name = r.parsed_name.remote_name;
			var remote = application.remote_lookup.lookup(remote_name);
			remote.fetch.begin(null, null, (obj, res) => {
				remote.fetch.end(res);
			});
			return true;
		});
	}
}

}

// ex:set ts=4 noet
