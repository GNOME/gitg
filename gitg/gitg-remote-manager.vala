/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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

class RemoteManager : Object, GitgExt.RemoteLookup
{
	class UICredentialsProvider : Object, CredentialsProvider
	{
		private CredentialsManager d_credentials;

		public UICredentialsProvider(Gitg.Remote remote, Gtk.Window window)
		{
			Ggit.Config? config = null;

			try
			{
				config = remote.get_owner().get_config();
			} catch {}

			d_credentials = new CredentialsManager(config, window, true);
		}

		public Ggit.Cred? credentials(string        url,
		                              string?       username_from_url,
		                              Ggit.Credtype allowed_types) throws Error
		{
			return d_credentials.credentials(url, username_from_url, allowed_types);
		}
	}

	struct InsteadOf
	{
		string prefix;
		string replacement;
	}

	private Gee.HashMap<string, Gitg.Remote> d_remotes;
	private InsteadOf[] d_insteadof;
	private Window d_window;

	public RemoteManager(Window window)
	{
		d_window = window;
		d_remotes = new Gee.HashMap<string, Gitg.Remote>();

		extract_insteadof();
	}

	private void extract_insteadof()
	{
		d_insteadof = new InsteadOf[10];
		d_insteadof.length = 0;

		if (d_window.repository == null)
		{
			return;
		}

		Ggit.Config config;

		try
		{
			config = d_window.repository.get_config().snapshot();
		} catch { return; }

		Regex r;

		try
		{
			r = new Regex("url\\.(.*)\\.insteadof");
		}
		catch (Error e)
		{
			stderr.printf("Failed to compile regex: %s\n", e.message);
			return;
		}

		try
		{
			config.match_foreach(r, (info, value) => {
				d_insteadof += InsteadOf() {
					prefix = value,
					replacement = info.fetch(1)
				};

				return 0;
			});
		} catch {}
	}

	public Gitg.Remote? lookup(string name)
	{
		if (d_window.repository == null)
		{
			return null;
		}

		if (d_remotes == null)
		{
			d_remotes = new Gee.HashMap<string, Gitg.Remote>();
		}

		if (d_remotes.has_key(name))
		{
			return d_remotes[name];
		}

		Gitg.Remote remote;

		try
		{
			remote = d_window.repository.lookup_remote(name) as Gitg.Remote;
		} catch { return null; }

		var url = remote.get_url();

		foreach (var io in d_insteadof)
		{
			if (url.has_prefix(io.prefix))
			{
				url = io.replacement + url.substring(io.prefix.length);

				string[] fetch_specs;
				string[] push_specs;

				fetch_specs = remote.fetch_specs;
				push_specs = remote.push_specs;

				Gitg.Remote? tmp = null;

				try
				{
					tmp = (new Ggit.Remote.anonymous(d_window.repository, url)) as Gitg.Remote;
				}
				catch (Error e)
				{
					stderr.printf("Failed to create remote: %s\n", e.message);
				}

				if (tmp == null)
				{
					break;
				}

				tmp.fetch_specs = fetch_specs;
				tmp.push_specs = push_specs;

				remote = tmp;
				break;
			}
		}

		remote.credentials_provider = new UICredentialsProvider(remote, d_window);

		d_remotes[name] = remote;
		return remote;
	}
}

}
