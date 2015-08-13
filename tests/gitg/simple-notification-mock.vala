/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Ignacio Casal Quinteiro
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

public class SimpleNotification : Object, GitgExt.Notification
{
	public enum Status
	{
		NONE,
		SUCCESS,
		ERROR
	}

	public signal void cancel();
	public Status status { get; set; }

	public string title { get; set; }
	public string message { get; set; }

	public SimpleNotification(string? title = null, string? message = null)
	{
		Object(title: title, message: message);
	}

	public Gtk.Widget? widget
	{
		owned get { return null; }
	}

	public void success(string message)
	{
		this.message = message;
		this.status = Status.SUCCESS;
	}

	public void error(string message)
	{
		this.message = message;
		this.status = Status.ERROR;
	}
}

}

// ex:ts=4 noet
