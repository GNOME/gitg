namespace Gitg
{

public void init()
{
	Ggit.init();

	var factory = Ggit.ObjectFactory.get_default();

	factory.register(typeof(Ggit.Repository),
	                 typeof(Gitg.Repository));

	factory.register(typeof(Ggit.Ref),
	                 typeof(Gitg.Ref));

	factory.register(typeof(Ggit.Commit),
	                 typeof(Gitg.Commit));
}

}

// ex:set ts=4 noet
