namespace Gitg
{

public class Repository : Ggit.Repository
{
	public Repository(File location, File? workdir) throws Error
	{
		Object(location: location,
		       workdir: workdir);

		((Initable)this).init(null);
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
