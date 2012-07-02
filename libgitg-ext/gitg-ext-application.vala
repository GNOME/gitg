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

public interface Application : Object
{
	public abstract Gitg.Repository? repository { owned get; }
	public abstract GitgExt.MessageBus message_bus { owned get; }
	public abstract GitgExt.View? current_view { owned get; }

	public abstract GitgExt.View? view(string id);

	public abstract void open(File repository);
	public abstract void create(File repository);
	public abstract void close();
}

}

// ex:set ts=4 noet:
