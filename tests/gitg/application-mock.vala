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
	class ExpectedUserQuery : Object
	{
		public GitgExt.UserQuery query;
		public Gtk.ResponseType response;
	}

	private Gee.ArrayQueue<ExpectedUserQuery> d_expected_queries;
	private Notifications d_notifications;

	public Application()
	{
		d_notifications = new Notifications();
	}

	protected override void set_up()
	{
		base.set_up();

		d_notifications = new Notifications();
		d_expected_queries = new Gee.ArrayQueue<ExpectedUserQuery>();
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

	protected Application expect_user_query(GitgExt.UserQuery query, Gtk.ResponseType response)
	{
		d_expected_queries.add(new ExpectedUserQuery() {
			query = query,
			response = response
		});

		return this;
	}

	private Gtk.ResponseType user_query_respond(GitgExt.UserQuery query)
	{
		assert_true(d_expected_queries.size > 0);

		var expected = d_expected_queries.poll();

		assert_streq(expected.query.title, query.title);
		assert_streq(expected.query.message, query.message);
		assert_inteq(expected.query.message_type, query.message_type);
		assert_inteq(expected.query.default_response, query.default_response);
		assert_booleq(expected.query.default_is_destructive, query.default_is_destructive);
		assert_booleq(expected.query.message_use_markup, query.message_use_markup);
		var responses = expected.query.get_responses();
		assert_inteq(responses.length, responses.length);

		for (var i = 0; i < responses.length; i++)
		{
			assert_inteq(responses[i].response_type, query.get_responses()[i].response_type);
			assert_streq(responses[i].text, query.get_responses()[i].text);
		}

		return expected.response;
	}

	public void user_query(GitgExt.UserQuery query)
	{
		query.response(user_query_respond(query));
	}

	public async Gtk.ResponseType user_query_async(GitgExt.UserQuery query)
	{
		return user_query_respond(query);
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
