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

public class MessageId : Object
{
	public string object_path { construct set; get; }
	public string method { construct set; get; }

	public string id
	{
		owned get { return object_path + "." + method; }
	}

	public uint hash()
	{
		return id.hash();
	}

	public bool equal(MessageId other)
	{
		return id == other.id;
	}

	public MessageId(string object_path, string method)
	{
		Object(object_path: object_path, method: method);
	}

	public MessageId copy()
	{
		return new MessageId(object_path, method);
	}

	public static bool valid_object_path(string path)
	{
		if (path == null)
		{
			return false;
		}

		if (path[0] != '/')
		{
			return false;
		}

		int i = 0;

		while (i < path.length)
		{
			var c = path[i];

			if (c == '/')
			{
				++i;

				if (i == path.length || !(c.isalpha() || c == '_'))
				{
					return false;
				}
			}
			else if (!(c.isalnum() || c == '_'))
			{
				return false;
			}

			++i;
		}

		return true;
	}
}

}

// ex:set ts=4 noet:
