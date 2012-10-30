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
	 * The current application main view.
	 */
	public abstract GitgExt.View? current_view { owned get; }

	/**
	 * Set the current application main view.
	 *
	 * @param id the id of the view {@link UIElement.id}.
	 *
	 * @return the created new main view, or ``null`` if no view with the
	 *         given id exists.
	 */
	public abstract GitgExt.View? view(string id);

	/**
	 * Open an existing repository.
	 *
	 * @param repository the path to the repository to open.
	 *
	 */
	public abstract void open(File repository);

	/**
	 * Create and open a new repository.
	 *
	 * @param repository the path at which the new repository is to be created.
	 *
	 */
	public abstract void create(File repository);

	/**
	 * Close the currently open repository.
	 *
	 **/
	public abstract void close();
}

}

// ex:set ts=4 noet:
