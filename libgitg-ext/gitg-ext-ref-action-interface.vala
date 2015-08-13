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

public delegate void RefNameEditingDone(string new_name, bool cancelled);

public interface RefActionInterface : Object
{
	public abstract Application application { owned get; construct set; }
	public abstract Gee.List<Gitg.Ref> references { owned get; }

	public abstract void add_ref(Gitg.Ref reference);
	public abstract void remove_ref(Gitg.Ref reference);
	public abstract void replace_ref(Gitg.Ref old_ref, Gitg.Ref new_ref);
	public abstract void set_busy(Gitg.Ref reference, bool busy);
	public abstract void edit_ref_name(Gitg.Ref reference, owned RefNameEditingDone callback);
	public abstract void refresh();
}

}

// ex: ts=4 noet
