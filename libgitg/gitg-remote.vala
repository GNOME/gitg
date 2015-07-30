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

public class Remote : Ggit.Remote
{
	private RemoteState d_state;
	private Error? d_authentication_error;
	private Ggit.RemoteCallbacks? d_callbacks;
	private string[]? d_fetch_specs;
	private string[]? d_push_specs;

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

	public new async void connect(Ggit.Direction direction) throws Error
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
					base.connect(direction, d_callbacks);
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

	public void set_callbacks(Ggit.RemoteCallbacks callbacks)
	{
		d_callbacks = callbacks;
	}

	private async void download_intern(string? message) throws Error
	{
		bool dis = false;

		if (!get_connected())
		{
			dis = true;
			yield connect(Ggit.Direction.FETCH);
		}

		state = RemoteState.TRANSFERRING;

		try
		{
			yield Async.thread(() => {
				var options = new Ggit.FetchOptions();
				options.set_remote_callbacks(d_callbacks);

				base.download(null, options);

				if (message != null)
				{
					base.update_tips(d_callbacks, true, options.get_download_tags(), message);
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

	public new async void download() throws Error
	{
		yield download_intern(null);
	}

	public new async void fetch(string? message) throws Error
	{
		yield download_intern(message);
	}

	public string[]? fetch_specs {
		owned get {
			if (d_fetch_specs != null) {
				return d_fetch_specs;
			}

			try {
				return get_fetch_specs();
			} catch (Error e) {
				return null;
			}
		}

		set {
			d_fetch_specs = value;
		}
	}

	public string[]? push_specs {
		owned get {
			if (d_push_specs != null) {
				return d_push_specs;
			}

			try {
				return get_push_specs();
			} catch (Error e) {
				return null;
			}
		}

		set {
			d_push_specs = value;
		}
	}
}

}
