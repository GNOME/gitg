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

class Gitg.Test.Application : Gitg.Test.Repository, GitgExt.Application
{
	private Notifications d_notifications;

	public Application()
	{
		d_notifications = new Notifications();
	}

	protected override void set_up()
	{
		base.set_up();

		d_notifications = new Notifications();
	}

	public Gitg.Repository? repository
	{
		owned get { return d_repository; }
		set {}
	}

	public GitgExt.MessageBus message_bus { owned get { return null; } }
	public GitgExt.Activity? current_activity { owned get { return null; } }
	public Gee.Map<string, string> environment { owned get { return new Gee.HashMap<string, string>(); } }

	public Gee.ArrayList<SimpleNotification> simple_notifications
	{
		owned get
		{
			var ret = new Gee.ArrayList<SimpleNotification>();

			foreach (var notification in d_notifications.notifications)
			{
				ret.add(notification as SimpleNotification);
			}

			return ret;
		}
	}

	public GitgExt.Notifications notifications { owned get { return d_notifications; } }
	public GitgExt.Activity? get_activity_by_id(string id) { return null; }
	public GitgExt.Activity? set_activity_by_id(string id) { return null; }

	public void user_query(GitgExt.UserQuery query)
	{
	}

	public async Gtk.ResponseType user_query_async(GitgExt.UserQuery query)
	{
		return Gtk.ResponseType.CLOSE;
	}

	public void show_infobar(string          primary_msg,
	                         string          secondary_msg,
	                         Gtk.MessageType type)
	{
	}

	public bool busy { get { return false; } set {} }

	public GitgExt.Application open_new(Ggit.Repository repository, string? hint = null)
	{
		return this;
	}

	public GitgExt.RemoteLookup remote_lookup { owned get { return null; } }

	public void open_repository(File path) {}
}

// ex:set ts=4 noet
