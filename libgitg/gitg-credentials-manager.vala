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

public errordomain CredentialsError
{
	CANCELLED
}

public class CredentialsManager
{
	private weak Remote d_remote;
	private Gtk.Window d_window;
	private Gee.HashMap<string, string>? d_usermap;
	private static Secret.Schema s_secret_schema;

	static construct
	{
		s_secret_schema = new Secret.Schema("org.gnome.Gitg.Credentials",
		                                    Secret.SchemaFlags.NONE,
		                                    "scheme", Secret.SchemaAttributeType.STRING,
		                                    "host", Secret.SchemaAttributeType.STRING,
		                                    "user", Secret.SchemaAttributeType.STRING);
	}

	public CredentialsManager(Remote remote, Gtk.Window window)
	{
		d_remote = remote;
		d_window = window;
	}

	private string? lookup_user(string host)
	{
		if (d_usermap == null)
		{
			d_usermap = new Gee.HashMap<string, string?>();

			try
			{
				var config = d_remote.get_owner().get_config().snapshot();
				var r = new Regex("credential\\.(.*)\\.username");

				config.match_foreach(r, (info, value) => {
					d_usermap[info.fetch(1)] = value;
					return 0;
				});
			}
			catch (Error e)
			{
				stderr.printf("Could not get username from git config: %s\n", e.message);
			}
		}

		return d_usermap[host];
	}

	private Ggit.Cred? user_pass_dialog(string url, string scheme, string host, string? username) throws Error
	{
		var mutex = Mutex();
		mutex.lock();

		var cond = Cond();

		Gtk.ResponseType response = Gtk.ResponseType.CANCEL;

		string password = "";
		string newusername = "";
		AuthenticationLifeTime lifetime = AuthenticationLifeTime.FORGET;

		Idle.add(() => {
			var d = new AuthenticationDialog(url, username, d_remote.authentication_error != null);
			d.set_transient_for(d_window);

			response = (Gtk.ResponseType)d.run();

			if (response == Gtk.ResponseType.OK)
			{
				newusername = d.username;
				password = d.password;
				lifetime = d.life_time;
			}

			d.destroy();

			mutex.lock();
			cond.signal();
			mutex.unlock();

			return false;
		});

		cond.wait(mutex);
		mutex.unlock();

		if (response != Gtk.ResponseType.OK)
		{
			throw new CredentialsError.CANCELLED("cancelled by user");
		}

		// Save username in config
		if (username == null || newusername != username)
		{
			if (d_usermap == null)
			{
				d_usermap = new Gee.HashMap<string, string?>();
			}

			try
			{
				var repo = d_remote.get_owner();
				var config = repo.get_config();
				var hid = @"$(scheme)://$(host)";

				config.set_string(@"credential.$(hid).username", newusername);

				d_usermap[hid] = newusername;
			}
			catch (Error e)
			{
				stderr.printf("Failed to store username in config: %s\n", e.message);
			}
		}

		var attributes = new HashTable<string, string>(str_hash, str_equal);
		attributes["scheme"] = scheme;
		attributes["host"] = host;
		attributes["user"] = newusername;

		// Save secret
		if (lifetime != AuthenticationLifeTime.FORGET)
		{
			string? collection = null;

			if (lifetime == AuthenticationLifeTime.SESSION)
			{
				collection = Secret.COLLECTION_SESSION;
			}

			Secret.password_storev.begin(s_secret_schema,
			                             attributes,
			                             collection,
			                             @"$(scheme)://$(host)",
			                             password,
			                             null,
			                             (obj, res) => {
				try
				{
					Secret.password_storev.end(res);
				}
				catch (Error e)
				{
					stderr.printf("Failed to store secret in keyring: %s\n", e.message);
				}
			});
		}
		else
		{
			Secret.password_clearv.begin(s_secret_schema, attributes, null, (obj, res) => {
				try
				{
					Secret.password_clearv.end(res);
				}
				catch (Error e)
				{
					stderr.printf("Failed to clear secret from keyring: %s\n", e.message);
				}
			});
		}

		return new Ggit.CredPlaintext(newusername, password);
	}

	private Ggit.Cred? query_user_pass(string url, string? username) throws Error
	{
		string? user;

		var uri = new Soup.URI(url);
		var host = uri.get_host();

		if (!uri.uses_default_port())
		{
			host = @"$(host):$(uri.get_port())";
		}

		var scheme = uri.get_scheme();

		if (username == null)
		{
			// Try to obtain username from config
			user = lookup_user(@"$scheme://$host");
		}
		else
		{
			user = username;
		}

		if (user != null && d_remote.authentication_error == null)
		{
			string? secret = null;

			try
			{
				secret = Secret.password_lookup_sync(s_secret_schema, null,
				                                     "scheme", scheme,
				                                     "host", host,
				                                     "user", user);
			}
			catch {}

			if (secret == null)
			{
				return user_pass_dialog(url, scheme, host, user);
			}

			try
			{
				return new Ggit.CredPlaintext(user, secret);
			}
			catch (Error e)
			{
				return user_pass_dialog(url, scheme, host, user);
			}
		}
		else
		{
			return user_pass_dialog(url, scheme, host, user);
		}
	}

	public Ggit.Cred? credentials(string        url,
	                              string?       username,
	                              Ggit.Credtype allowed_types) throws Error
	{
		if (d_remote.authentication_error == null && (allowed_types & Ggit.Credtype.SSH_KEY) != 0)
		{
			return new Ggit.CredSshKeyFromAgent(username);
		}
		else if ((allowed_types & Ggit.Credtype.USERPASS_PLAINTEXT) != 0)
		{
			return query_user_pass(url, username);
		}

		return null;
	}
}

}
