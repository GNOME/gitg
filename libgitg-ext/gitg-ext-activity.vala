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
 * gitg Activity interface.
 *
 * The Activity interface can be implemented to provide a main activity in
 * gitg. An example of such activities are the builtin History and
 * Commit activities.
 */
public interface Activity : Object, UIElement
{
	/**
	 * Whether the activity is the default for the specified action.
	 *
	 * @param action the action.
	 *
	 * @return true if the activity is the default activity for @action,
	 *         false otherwise.
	 */
	public virtual bool is_default_for(string action)
	{
		return false;
	}
}

}

// ex: ts=4 noet
