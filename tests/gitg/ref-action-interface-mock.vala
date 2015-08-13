/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

using Gitg.Test.Assert;

class Gitg.Test.RefActionInterface : Object, GitgExt.RefActionInterface
{
	public GitgExt.Application application { owned get; construct set; }

	public RefActionInterface(GitgExt.Application application)
	{
		Object(application: application);
	}

	public Gee.List<Gitg.Ref> references
	{
		owned get { return new Gee.LinkedList<Gitg.Ref>(); }
	}

	public void add_ref(Gitg.Ref reference)
	{

	}

	public void remove_ref(Gitg.Ref reference)
	{

	}

	public void replace_ref(Gitg.Ref old_ref, Gitg.Ref new_ref)
	{

	}

	public void set_busy(Gitg.Ref reference, bool busy)
	{

	}

	public void edit_ref_name(Gitg.Ref reference, owned GitgExt.RefNameEditingDone callback)
	{

	}

	public void refresh()
	{

	}
}

// ex:set ts=4 noet
