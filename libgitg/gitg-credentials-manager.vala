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
	private Ggit.Config? d_config;
	private Gtk.Window d_window;
	private Gee.HashMap<string, string>? d_usermap;
	private bool d_save_user_in_config;
	private string d_last_user;
	private Gee.HashMap<string, Ggit.Credtype> d_auth_tried;

	private static Secret.Schema s_secret_schema;
	private static Regex s_ssh_short_form;

	static construct
	{
		s_secret_schema = new Secret.Schema(Gitg.Config.APPLICATION_ID + ".Credentials",
		                                    Secret.SchemaFlags.NONE,
		                                    "scheme", Secret.SchemaAttributeType.STRING,
		                                    "host", Secret.SchemaAttributeType.STRING,
		                                    "user", Secret.SchemaAttributeType.STRING);

		try
		{
			s_ssh_short_form = new Regex("^(?:[^: /@]+)@(?P<host>[^:]+)");
		} catch (Error e) { stderr.printf("regex err: %s\n", e.message); }
	}

	public CredentialsManager(Ggit.Config? config, Gtk.Window window, bool save_user_in_config)
	{
		d_config = config;
		d_save_user_in_config = save_user_in_config;
		d_auth_tried = new Gee.HashMap<string, Ggit.Credtype>();
		d_window = window;
	}

	private string? lookup_user(string host)
	{
		if (d_usermap == null)
		{
			d_usermap = new Gee.HashMap<string, string?>();

			if (d_config != null)
			{
				try
				{
					var r = new Regex("credential\\.(.*)\\.username");

					d_config.snapshot().match_foreach(r, (info, value) => {
						d_usermap[info.fetch(1)] = value;
						return 0;
					});
				}
				catch (Error e)
				{
					stderr.printf("Could not get username from git config: %s\n", e.message);
				}
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
			// Skip SSH_KEY in terms of tried since that might just fail if
			// there is no key and that's not informative to the user
			var tried = d_auth_tried[username] & ~Ggit.Credtype.SSH_KEY;

			var d = new AuthenticationDialog(url, username, tried != 0);
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

		d_last_user = newusername;

		// Save username in config
		if (username == null || newusername != username && d_config != null && d_save_user_in_config)
		{
			if (d_usermap == null)
			{
				d_usermap = new Gee.HashMap<string, string?>();
			}

			try
			{
				var hid = @"$(scheme)://$(host)";

				d_config.set_string(@"credential.$(hid).username", newusername);
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

		d_auth_tried[newusername] |= Ggit.Credtype.USERPASS_PLAINTEXT;
		return new Ggit.CredPlaintext(newusername, password);
	}

	private Ggit.Cred? query_user_pass(string url, string? username) throws Error
	{
		string? user;

		string host = "local";
		string scheme = "file";

		if (!("://" in url))
		{
			MatchInfo minfo;

			if (s_ssh_short_form.match(url, 0, out minfo))
			{
				scheme = "ssh";
				host = minfo.fetch_named("host");
			}
		}
		else
		{
			var uri = new Soup.URI(url);

			if (uri != null)
			{
				host = uri.get_host();

				if (!uri.uses_default_port())
				{
					host = @"$(host):$(uri.get_port())";
				}
		
				scheme = uri.get_scheme();
			}
		}

		if (username == null)
		{
			// Try to obtain username from config
			user = lookup_user(@"$scheme://$host");
		}
		else
		{
			user = username;
		}

		if (user != null)
		{
			var tried = d_auth_tried[user];

			if ((tried & Ggit.Credtype.USERPASS_PLAINTEXT) == 0)
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

				d_auth_tried[user] |= Ggit.Credtype.USERPASS_PLAINTEXT;

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
		else
		{
			return user_pass_dialog(url, scheme, host, user);
		}
	}

	public Ggit.Cred? credentials(string        url,
	                              string?       username,
	                              Ggit.Credtype allowed_types) throws Error
	{
		var uslookup = username != null ? username : "";
		var tried = d_auth_tried[uslookup];

		var untried_allowed_types = allowed_types & ~tried;

		if ((untried_allowed_types & Ggit.Credtype.SSH_KEY) != 0)
		{
			d_auth_tried[uslookup] = tried | Ggit.Credtype.SSH_KEY;
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
