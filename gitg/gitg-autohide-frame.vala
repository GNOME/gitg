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

class AutohideFrame : Gtk.Frame
{
	public override void add(Gtk.Widget widget)
	{
		base.add(widget);

		update_visibility();
	}

	public override void remove(Gtk.Widget widget)
	{
		base.remove(widget);

		update_visibility();
	}

	private void update_visibility()
	{
		visible = get_child() != null;
	}
}

}

// vi:ts=4
