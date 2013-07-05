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

namespace GitgExt
{

/**
 * Application is an interface to access the main gitg application.
 *
 * The application interface is provided to plugins to access the main gitg
 * application instance. It contains properties to access the currently open
 * repository as well as methods to open or create repositories.
 *
 */
public interface Application : Object
{
	/**
	 * The currently open repository.
	 */
	public abstract Gitg.Repository? repository { owned get; set; }

	/**
	 * An application wide message bus over which plugins can communicate.
	 */
	public abstract GitgExt.MessageBus message_bus { owned get; }

	/**
	 * The current application main activity.
	 */
	public abstract GitgExt.Activity? current_activity { owned get; }

	/**
	 * Set the current application main activity.
	 *
	 * @param id the id of the activity {@link UIElement.id}.
	 *
	 * @return the created new main activity, or ``null`` if no activity with the
	 *         given id exists.
	 */
	public abstract GitgExt.Activity? activity(string id);

	public abstract void show_infobar(string          primary_msg,
	                                  string          secondary_msg,
	                                  Gtk.MessageType type);

	public abstract Gee.Map<string, string> environment { owned get; }
}

}

// ex:set ts=4 noet:
