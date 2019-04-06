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

namespace GitgExt
{

public class UserQueryResponse : Object
{
	public string text;
	public Gtk.ResponseType response_type;

	public UserQueryResponse(string text, Gtk.ResponseType response_type)
	{
		this.text = text;
		this.response_type = response_type;
	}
}

public class UserQuery : Object
{
	public string title { get; set; }
	public string message { get; set; }
	public Gtk.MessageType message_type { get; set; }
	public Gtk.ResponseType default_response { get; set; default = Gtk.ResponseType.CLOSE; }
	public UserQueryResponse[] _responses;

	public UserQueryResponse[] get_responses() {
		return _responses;
	}

	public void set_responses(UserQueryResponse[] value) {
		_responses = value;
	}

	public bool default_is_destructive { get; set; }
	public bool message_use_markup { get; set; }

	public signal void quit();
	public signal bool response(Gtk.ResponseType response_type);

	public UserQuery.full(string title, string message, Gtk.MessageType message_type, ...)
	{
		Object(title: title, message: message, message_type: message_type);

		var l = va_list();
		var resps = new UserQueryResponse[0];

		while (true) {
			string? text = l.arg();

			if (text == null) {
				break;
			}

			resps += new UserQueryResponse(text, l.arg());
		}

		set_responses(resps);

		if (resps.length > 0) {
			default_response = resps[resps.length - 1].response_type;
		}
	}
}

}

// ex:set ts=4 noet:
