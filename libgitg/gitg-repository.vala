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

	public void clear_refs_cache()
	{
		d_refs = null;
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

	public new Ref lookup_reference_dwim(string short_name) throws Error
	{
		return base.lookup_reference_dwim(short_name) as Ref;
	}

	public new Branch create_branch(string name, Ggit.Object obj, Ggit.CreateFlags flags) throws Error
	{
		return base.create_branch(name, obj, flags) as Branch;
	}

	public new Ref create_reference(string name, Ggit.OId oid, string message) throws Error
	{
		return base.create_reference(name, oid, message) as Ref;
	}

	public new Ref create_symbolic_reference(string name, string target, string message) throws Error
	{
		return base.create_symbolic_reference(name, target, message) as Ref;
	}

	public new Ref get_head() throws Error
	{
		return base.get_head() as Ref;
	}

	public static new Repository init_repository(File location, bool is_bare) throws Error
	{
		return Ggit.Repository.init_repository(location, is_bare) as Repository;
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

	public Ggit.Signature get_signature_with_environment(Gee.Map<string, string> env, string envname = "COMMITER") throws Error
	{
		string? user = null;
		string? email = null;
		DateTime? date = null;

		var nameenv = @"GIT_$(envname)_NAME";
		var emailenv = @"GIT_$(envname)_EMAIL";
		var dateenv = @"GIT_$(envname)_DATE";

		if (env.has_key(nameenv))
		{
			user = env[nameenv];
		}

		if (env.has_key(emailenv))
		{
			email = env[emailenv];
		}

		if (env.has_key(dateenv))
		{
			try
			{
				date = Gitg.Date.parse(env[dateenv]);
			}
			catch {}
		}

		if (date == null)
		{
			date = new DateTime.now_local();
		}

		var conf = get_config().snapshot();

		if (user == null)
		{
			try
			{
				user = conf.get_string("user.name");
			} catch {}
		}

		if (email == null)
		{
			try
			{
				email = conf.get_string("user.email");
			} catch {}
		}

		return new Ggit.Signature(user != null ? user : "",
		                          email != null ? email : "",
		                          date);
	}
}

}

// ex:set ts=4 noet
