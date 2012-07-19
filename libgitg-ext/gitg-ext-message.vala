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

public abstract class Message : Object
{
	private MessageId d_id;

	public MessageId id
	{
		construct set
		{
			d_id = value.copy();
		}
		get
		{
			return d_id;
		}
	}

	public bool has(string propname)
	{
		return get_class().find_property(propname) != null;
	}

	public static bool type_has(Type type, string propname)
	{
		return ((ObjectClass)type.class_ref()).find_property(propname) != null;
	}

	public static bool type_check(Type type, string propname, Type value_type)
	{
		ParamSpec? spec = ((ObjectClass)type.class_ref()).find_property(propname);

		return (spec != null && spec.value_type == value_type);
	}
}

}

// ex:set ts=4 noet:
