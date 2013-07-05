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

public class Repository : Ggit.Repository
{
	private HashTable<Ggit.OId, SList<Gitg.Ref>> d_refs;
	private Stage ?d_stage;

	public string? name
	{
		owned get
		{
			var f = workdir != null ? workdir : location;
			return f != null ? f.get_basename() : null;
		}
	}

	public Repository(File location, File? workdir) throws Error
	{
		Object(location: location,
		       workdir: workdir);

		((Initable)this).init(null);
	}

	private void ensure_refs_add(Ggit.OId? id, Gitg.Ref r)
	{
		if (id == null)
		{
			return;
		}

		unowned SList<Gitg.Ref> refs;

		if (d_refs.lookup_extended(id, null, out refs))
		{
			refs.append(r);
		}
		else
		{
			SList<Gitg.Ref> nrefs = new SList<Gitg.Ref>();
			nrefs.append(r);

			d_refs.insert(id, (owned)nrefs);
		}
	}

	private void ensure_refs()
	{
		if (d_refs != null)
		{
			return;
		}

		d_refs = new HashTable<Ggit.OId, SList<Gitg.Ref>>(Ggit.OId.hash,
		                                                  Ggit.OId.equal);

		try
		{
			references_foreach_name((name) => {
				Gitg.Ref? r;

				try
				{
					r = lookup_reference(name);
				}
				catch { return 0; }

				if (r == null)
				{
					return 0;
				}

				Ggit.OId? id = r.get_target();

				if (id == null)
				{
					return 0;
				}

				ensure_refs_add(id, r);

				// if it's a 'real' tag, then we are also going to store
				// a ref to the underlying commit the tag points to
				try
				{
					var tag = lookup<Ggit.Tag>(id);

					// get the target id
					id = tag.get_target_id();

					if (id != null)
					{
						ensure_refs_add(id, r);
					}
				} catch {}

				return 0;
			});
		}
		catch {}
	}

	public unowned SList<Gitg.Ref> refs_for_id(Ggit.OId id)
	{
		ensure_refs();

		return d_refs.lookup(id);
	}

	public new T? lookup<T>(Ggit.OId id) throws Error
	{
		return (T?)base.lookup(id, typeof(T));
	}

	// Wrappers for Gitg.Ref
	public new Ref lookup_reference(string name) throws Error
	{
		return base.lookup_reference(name) as Ref;
	}

	public new Ref create_reference(string name, Ggit.OId oid) throws Error
	{
		return base.create_reference(name, oid) as Ref;
	}

	public new Ref create_symbolic_reference(string name, string target) throws Error
	{
		return base.create_symbolic_reference(name, target) as Ref;
	}

	public new Ref get_head() throws Error
	{
		return base.get_head() as Ref;
	}

	public Stage stage
	{
		owned get
		{
			if (d_stage == null)
			{
				d_stage = new Stage(this);
			}

			return d_stage;
		}
	}
}

}

// ex:set ts=4 noet
