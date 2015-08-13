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

namespace GitgHistory
{

class ActionInterface : Object, GitgExt.RefActionInterface
{
	public GitgExt.Application application { owned get; construct set; }

	private RefsList d_refs_list;

	public signal void updated();

	public ActionInterface(GitgExt.Application application, RefsList refs_list)
	{
		Object(application: application);

		d_refs_list = refs_list;
	}

	public Gee.List<Gitg.Ref> references
	{
		owned get { return d_refs_list.references; }
	}

	public void add_ref(Gitg.Ref reference)
	{
		application.repository.clear_refs_cache();
		d_refs_list.add_ref(reference);
		updated();
	}

	public void remove_ref(Gitg.Ref reference)
	{
		application.repository.clear_refs_cache();
		d_refs_list.remove_ref(reference);
		updated();
	}

	public void replace_ref(Gitg.Ref old_ref, Gitg.Ref new_ref)
	{
		application.repository.clear_refs_cache();
		d_refs_list.replace_ref(old_ref, new_ref);
		updated();
	}

	public void set_busy(Gitg.Ref reference, bool busy)
	{
		// TODO
	}

	public void edit_ref_name(Gitg.Ref reference, owned GitgExt.RefNameEditingDone done)
	{
		d_refs_list.edit(reference, (owned)done);
	}

	public void refresh()
	{
		d_refs_list.repository = application.repository;
		updated();
	}
}

}

// ex: ts=4 noet
