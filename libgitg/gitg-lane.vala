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

namespace Gitg
{

[Flags]
public enum LaneTag
{
	NONE = 0,
	START = 1 << 0,
	END = 1 << 1,
	SIGN_STASH = 1 << 2,
	SIGN_STAGED = 1 << 3,
	SIGN_UNSTAGED = 1 << 4,
	HIDDEN = 1 << 5
}

public class Lane : Object
{
	public Color color;
	public SList<int> from;
	public LaneTag tag;
	public Ggit.OId? boundary_id;

	public Lane()
	{
		this.with_color(null);
	}

	public Lane.with_color(Color? color)
	{
		if (color != null)
		{
			this.color = color;
		}
		else
		{
			this.color = Color.next();
		}
	}

	public Lane copy()
	{
		Lane ret = new Lane.with_color(color);
		ret.from = from.copy();
		ret.tag = tag;
		ret.boundary_id = boundary_id;

		return ret;
	}

	public Lane dup()
	{
		Lane ret = new Lane.with_color(color.copy());
		ret.from = from.copy();
		ret.tag = tag;
		ret.boundary_id = boundary_id;

		return ret;
	}
}

}

// ex:set ts=4 noet
