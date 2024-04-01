/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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
 * gitg Searchable interface.
 *
 * The Searchable interface can be implemented when an activity supports a
 * searching.
 */
public interface Searchable : Object, Activity
{
	public abstract string search_text { owned get; set; }
	public abstract bool search_visible { get; set; }
	public abstract bool search_available { get; }
	public abstract Gtk.Entry? search_entry { set; }
	public virtual void search_move(string key, bool up) {}
	public virtual bool show_buttons() { return false; }
}

}

// ex: ts=4 noet
