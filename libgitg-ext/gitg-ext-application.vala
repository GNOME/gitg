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

	public signal void repository_changed_externally(ExternalChangeHint hint);
	public signal void repository_commits_changed();

	/**
	 * An application wide message bus over which plugins can communicate.
	 */
	public abstract GitgExt.MessageBus message_bus { owned get; }

	/**
	 * The current application main activity.
	 */
	public abstract GitgExt.Activity? current_activity { owned get; }

	/**
	 * The environment with which the application was opened.
	 */
	public abstract Gee.Map<string, string> environment { owned get; }

	/**
	 * Get the committer signature and verify that both its name and
	 * e-mail are set. If not, the application will show an approppriate
	 * error message and return null.
	 */
	public abstract Ggit.Signature? get_verified_committer();

	/**
	 * Get the notifications manager for the application.
	 */
	public abstract Notifications notifications { owned get; }

	/**
	 * Set the current application main activity.
	 *
	 * @param id the id of the activity {@link UIElement.id}.
	 *
	 * @return the created new main activity, or ``null`` if no activity with the
	 *         given id exists.
	 */
	public abstract GitgExt.Activity? get_activity_by_id(string id);
	public abstract GitgExt.Activity? set_activity_by_id(string id);

	public abstract void user_query(UserQuery query);
	public abstract async Gtk.ResponseType user_query_async(UserQuery query);

	public abstract void show_infobar(string          primary_msg,
	                                  string          secondary_msg,
	                                  Gtk.MessageType type);

	public abstract bool busy { get; set; }

	public abstract Application open_new(Ggit.Repository repository, string? hint = null);

	public abstract RemoteLookup remote_lookup { owned get; }

	public abstract void open_repository(File path);
}

[Flags]
public enum ExternalChangeHint
{
	NONE = 0,

	REFS  = 1 << 0,
	INDEX = 1 << 1
}

}

// ex:set ts=4 noet:
