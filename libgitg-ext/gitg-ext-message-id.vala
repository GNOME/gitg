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
 * Message identifier object.
 *
 * The message identifier object is used to identify messages sent over the
 * MessageBus. The message identifier contains an object path and a method.
 * Both are simple strings and combined describe the location of a message as
 * a kind of method on an object.
 *
 * Valid object paths start with a forward slash and further path elements are
 * seperated by more forward slashes. The first element needs to start with
 * an alpha character (or underscore) while further characters can be
 * alpha numeric or underscores. An example of a valid path is:
 *
 * /path/to/object
 *
 * Method names on the other hand do not have any restrictions.
 *
 */
public class MessageId : Object
{
	/**
	 * Message object path.
	 */
	public string object_path { construct set; get; }

	/**
	 * Message method.
	 */
	public string method { construct set; get; }

	/**
	 * Full id of the message.
	 *
	 * Get the full id of the message identifier. The full id is simply
	 * <path>.<method>
	 *
	 */
	public string id
	{
		owned get { return object_path + "." + method; }
	}

	/**
	 * Message hash.
	 *
	 * Get a hash for the message identifier suitable for use in a hash table.
	 * The hash is simply a string hash of the full id of the message identifier.
	 *
	 * @return the message identifier hash.
	 *
	 */
	public uint hash()
	{
		return id.hash();
	}

	/**
	 * Compare two messages for equality.
	 *
	 * Compare two messages. Two message identifiers are equal when they have
	 * the same object path and the same method name.
	 *
	 * @param other the message identifier to compare to.
	 *
	 * @return true if the message identifiers are equal, false otherwise.
	 *
	 */
	public bool equal(MessageId other)
	{
		return id == other.id;
	}

	/**
	 * Construct message identifier with object path and method.
	 *
	 * Create a new message identifier object with the given object path and
	 * method name.
	 *
	 * @param object_path the object path
	 * @param method the method name
	 *
	 * @return a new message identifier.
	 *
	 */
	public MessageId(string object_path, string method)
	{
		Object(object_path: object_path, method: method);
	}

	/**
	 * Create a copy of the message identifier.
	 *
	 * Create an exact copy of the message identifier.
	 *
	 * @return a new message identifier.
	 *
	 */
	public MessageId copy()
	{
		return new MessageId(object_path, method);
	}

	/**
	 * Check whether an object path is a valid path.
	 *
	 * Check whether the given path is a valid object path. A valid object path
	 * starts with a forward slash, followed by at least one alpha character,
	 * or underscore. Further valid characters include alphanumeric characters,
	 * underscores or path separators (forward slash).
	 *
	 * Example: /path/to/object
	 *
	 * @return true if the specified path is valid, false otherwise
	 *
	 */
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
