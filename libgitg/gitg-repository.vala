namespace Gitg
{

public class Repository : Ggit.Repository
{
	private HashTable<Ggit.OId, SList<Gitg.Ref>> d_refs;

	public Repository(File location, File? workdir) throws Error
	{
		Object(location: location,
		       workdir: workdir);

		((Initable)this).init(null);
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
			references_foreach(Ggit.RefType.LISTALL, (name) => {
				Gitg.Ref? r;

				try
				{
					r = lookup_reference(name);
				}
				catch { return 0; }

				if (r != null)
				{
					Ggit.OId? id = r.get_id();

					if (id != null)
					{
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
				}

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

	public new Gitg.Ref get_head() throws Error
	{
		return base.get_head() as Ref;
	}
}

}

// ex:set ts=4 noet
