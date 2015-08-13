/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

using Gitg.Test.Assert;

class Gitg.Test.Notifications : Object, GitgExt.Notifications
{
	public signal void added(GitgExt.Notification notification);
	public signal void removed(GitgExt.Notification notification);

	public Gee.ArrayList<GitgExt.Notification> notifications;

	public Notifications()
	{
		notifications = new Gee.ArrayList<GitgExt.Notification>();
	}

	public void add(GitgExt.Notification notification)
	{
		added(notification);
		notifications.add(notification);
	}

	public void remove(GitgExt.Notification notification, uint delay = 0)
	{
		removed(notification);
		notifications.remove(notification);
	}
}

// ex:set ts=4 noet
