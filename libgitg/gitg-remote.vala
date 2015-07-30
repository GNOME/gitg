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

public enum RemoteState
{
	DISCONNECTED,
	CONNECTING,
	CONNECTED,
	TRANSFERRING
}

public errordomain RemoteError
{
	ALREADY_CONNECTED,
	ALREADY_CONNECTING,
	ALREADY_DISCONNECTED,
	STILL_CONNECTING
}

public interface CredentialsProvider : Object
{
	public abstract Ggit.Cred? credentials(string url, string? username_from_url, Ggit.Credtype allowed_types) throws Error;
}

public class Remote : Ggit.Remote
{
	private class Callbacks : Ggit.RemoteCallbacks
	{
		private Remote d_remote;
		private Ggit.RemoteCallbacks? d_proxy;

		public Callbacks(Remote remote, Ggit.RemoteCallbacks? proxy)
		{
			d_remote = remote;
			d_proxy = proxy;
		}

		protected override void progress(string message)
		{
			d_remote.progress(message);

			if (d_proxy != null)
			{
				d_proxy.progress(message);
			}
		}

		protected override void transfer_progress(Ggit.TransferProgress stats)
		{
			d_remote.transfer_progress(stats);

			if (d_proxy != null)
			{
				d_proxy.transfer_progress(stats);
			}
		}

		protected override void update_tips(string refname, Ggit.OId a, Ggit.OId b)
		{
			d_remote.tip_updated(refname, a, b);

			if (d_proxy != null)
			{
				d_proxy.update_tips(refname, a, b);
			}
		}

		protected override void completion(Ggit.RemoteCompletionType type)
		{
			d_remote.completion(type);

			if (d_proxy != null)
			{
				d_proxy.completion(type);
			}
		}

		protected override Ggit.Cred? credentials(string url, string? username_from_url, Ggit.Credtype allowed_types) throws Error
		{
			Ggit.Cred? ret = null;

			var provider = d_remote.credentials_provider;

			if (provider != null)
			{
				ret = provider.credentials(url, username_from_url, allowed_types);
			}

			if (ret == null && d_proxy != null)
			{
				ret = d_proxy.credentials(url, username_from_url, allowed_types);
			}

			return ret;
		}
	}

	private RemoteState d_state;
	private Error? d_authentication_error;
	private string[]? d_fetch_specs;
	private string[]? d_push_specs;

	public signal void progress(string message);
	public signal void transfer_progress(Ggit.TransferProgress stats);
	public signal void tip_updated(string refname, Ggit.OId a, Ggit.OId b);
	public signal void completion(Ggit.RemoteCompletionType type);

	public Error authentication_error
	{
		get { return d_authentication_error; }
	}

	public RemoteState state
	{
		get { return d_state; }
		private set
		{
			if (d_state != value)
			{
				d_state = value;
				notify_property("state");
			}
		}
	}

	private void update_state(bool force_disconnect = false)
	{
		if (get_connected())
		{
			if (force_disconnect)
			{
				disconnect.begin((obj, res) => {
					try
					{
						disconnect.end(res);
					} catch {}
				});
			}
			else
			{
				state = RemoteState.CONNECTED;
				d_authentication_error = null;
			}
		}
		else
		{
			state = RemoteState.DISCONNECTED;
		}
	}

	public new async void connect(Ggit.Direction direction, Ggit.RemoteCallbacks? callbacks = null) throws Error
	{
		if (get_connected())
		{
			if (state != RemoteState.CONNECTED)
			{
				state = RemoteState.CONNECTED;
			}

			throw new RemoteError.ALREADY_CONNECTED("already connected");
		}
		else if (state == RemoteState.CONNECTING)
		{
			throw new RemoteError.ALREADY_CONNECTING("already connecting");
		}

		state = RemoteState.CONNECTING;

		while (true)
		{
			try
			{
				yield Async.thread(() => {
					base.connect(direction, new Callbacks(this, callbacks));
				});
			}
			catch (Error e)
			{
				// NOTE: need to check the message for now in case of failed
				// http or ssh auth. This is fragile and will likely break
				// in future libgit2 releases. Please fix!
				if (e.message == "Unexpected HTTP status code: 401" ||
				    e.message == "error authenticating: Username/PublicKey combination invalid")
				{
					d_authentication_error = e;
					continue;
				}
				else
				{
					update_state();
					throw e;
				}
			}

			d_authentication_error = null;
			break;
		}

		update_state();
	}

	public new async void disconnect() throws Error
	{
		if (!get_connected())
		{
			if (state != RemoteState.DISCONNECTED)
			{
				state = RemoteState.DISCONNECTED;
			}

			throw new RemoteError.ALREADY_DISCONNECTED("already disconnected");
		}

		try
		{
			yield Async.thread(() => {
				base.disconnect();
			});
		}
		catch (Error e)
		{
			update_state();
			throw e;
		}

		update_state();
	}

	private async void download_intern(string? message, Ggit.RemoteCallbacks? callbacks) throws Error
	{
		bool dis = false;

		if (!get_connected())
		{
			dis = true;
			yield connect(Ggit.Direction.FETCH, callbacks);
		}

		state = RemoteState.TRANSFERRING;

		try
		{
			yield Async.thread(() => {
				var options = new Ggit.FetchOptions();
				var cbs = new Callbacks(this, callbacks);

				options.set_remote_callbacks(cbs);

				base.download(null, options);

				if (message != null)
				{
					base.update_tips(cbs, true, options.get_download_tags(), message);
				}
			});
		}
		catch (Error e)
		{
			update_state(dis);
			throw e;
		}

		update_state(dis);
	}

	public new async void download(Ggit.RemoteCallbacks? callbacks = null) throws Error
	{
		yield download_intern(null, callbacks);
	}

	public new async void fetch(string? message, Ggit.RemoteCallbacks? callbacks = null) throws Error
	{
		var msg = message;

		if (msg == null)
		{
			var name = get_name();

			if (name == null)
			{
				name = get_url();
			}

			if (name != null)
			{
				msg = "fetch: " + name;
			}
			else
			{
				msg = "";
			}
		}

		yield download_intern(msg, callbacks);
	}

	public string[]? fetch_specs
	{
		owned get
		{
			if (d_fetch_specs != null)
			{
				return d_fetch_specs;
			}

			try
			{
				return get_fetch_specs();
			}
			catch (Error e)
			{
				return null;
			}
		}

		set
		{
			d_fetch_specs = value;
		}
	}

	public string[]? push_specs
	{
		owned get
		{
			if (d_push_specs != null)
			{
				return d_push_specs;
			}

			try
			{
				return get_push_specs();
			}
			catch (Error e)
			{
				return null;
			}
		}

		set
		{
			d_push_specs = value;
		}
	}

	public CredentialsProvider? credentials_provider
	{
		get; set;
	}
}

}
