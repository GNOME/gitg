/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

class LibGitg.Test.Date : Gitg.Test.Test
{
	protected virtual signal void test_iso8601()
	{
		assert_datetime(Gitg.Date.parse("2005"),
		                new DateTime.local(2005, 1, 1, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("2005-04"),
		                new DateTime.local(2005, 4, 1, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("2005.04"),
		                new DateTime.local(2005, 4, 1, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("200504"),
		                new DateTime.local(2005, 4, 1, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("2005-04-07"),
		                new DateTime.local(2005, 4, 7, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("20050407"),
		                new DateTime.local(2005, 4, 7, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("2005.04.07"),
		                new DateTime.local(2005, 4, 7, 0, 0, 0));

		assert_datetime(Gitg.Date.parse("2005-04-07T22"),
		                new DateTime.local(2005, 4, 7, 22, 0, 0));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 0));

		assert_datetime(Gitg.Date.parse("2005-04-07T2213"),
		                new DateTime.local(2005, 4, 7, 22, 13, 0));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("200504-07T22:13:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("20050407T22:13:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("20050407T2213:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("20050407T221313"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("20050407 221313"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005.04.07T22:13:13"),
		                new DateTime.local(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13Z"),
		                new DateTime.utc(2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13+0200"),
		                new DateTime(new TimeZone.identifier("+0200"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13-0400"),
		                new DateTime(new TimeZone.identifier("-0400"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13+0202"),
		                new DateTime(new TimeZone.identifier("+0202"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13+03"),
		                new DateTime(new TimeZone.identifier("+0300"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("2005-04-07T22:13:13+03:20"),
		                new DateTime(new TimeZone.identifier("+0320"), 2005, 4, 7, 22, 13, 13));

	}

	protected virtual signal void test_rfc2822()
	{
		assert_datetime(Gitg.Date.parse("Thu, 07 Apr 2005 22:13:13 +0200"),
		                new DateTime(new TimeZone.identifier("+0200"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("Thu, 07 Apr 2005 22:13:13 -0200"),
		                new DateTime(new TimeZone.identifier("-0200"), 2005, 4, 7, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("Fri, 08 Apr 2005 22:13:13 -0200"),
		                new DateTime(new TimeZone.identifier("-0200"), 2005, 4, 8, 22, 13, 13));

		assert_datetime(Gitg.Date.parse("Tue, 08 Mar 2005 22:13:13 +0300"),
		                new DateTime(new TimeZone.identifier("+0300"), 2005, 3, 8, 22, 13, 13));

	}

	protected virtual signal void test_internal()
	{
		assert_datetime(Gitg.Date.parse("457849203 +0200"),
		                (new DateTime.from_unix_utc(457849203))
		                    .to_timezone(new TimeZone.identifier("+0200")));

		assert_datetime(Gitg.Date.parse("457849203 -0200"),
		                (new DateTime.from_unix_utc(457849203))
		                    .to_timezone(new TimeZone.identifier("-0200")));
	}
}

// ex: ts=4 noet
