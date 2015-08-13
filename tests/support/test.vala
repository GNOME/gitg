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

class Gitg.Test.Test : Object
{
	private GLib.TestSuite d_suite;

	construct
	{
		d_suite = new GLib.TestSuite(get_type().name());
	}

	public GLib.TestSuite suite
	{
		get { return d_suite; }
	}

	public virtual void set_up()
	{
	}

	public virtual void tear_down()
	{
	}
}

namespace Gitg.Test.Assert
{
	void assert_file_contents(string filename, string expected_contents)
	{
		string contents;
		size_t len;

		try
		{
			FileUtils.get_contents(filename, out contents, out len);
		}
		catch (Error e)
		{
			assert_no_error(e);
		}

		assert_streq(contents, expected_contents);
	}
}

// ex:set ts=4 noet
