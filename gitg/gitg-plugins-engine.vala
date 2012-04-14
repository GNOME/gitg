namespace Gitg
{

public class PluginsEngine : Peas.Engine
{
	private static PluginsEngine s_instance;

	construct
	{
		enable_loader("python");

		var repo = Introspection.Repository.get_default();

		try
		{
			repo.require("Peas", "1.0", 0);
			repo.require("PeasGtk", "1.0", 0);
		}
		catch (Error e)
		{
			warning("Could not load repository: %s", e.message);
			return;
		}

		add_search_path(Dirs.user_plugins_dir,
		                Dirs.user_plugins_data_dir);

		add_search_path(Dirs.plugins_dir,
		                Dirs.plugins_data_dir);

		Peas.PluginInfo[] builtins = new Peas.PluginInfo[20];
		builtins.length = 0;

		foreach (var info in get_plugin_list())
		{
			if (info.is_builtin())
			{
				builtins += info;
			}
		}

		foreach (var info in builtins)
		{
			load_plugin(info);
		}
	}

	public new static PluginsEngine get_default()
	{
		if (s_instance == null)
		{
			s_instance = new PluginsEngine();
			s_instance.add_weak_pointer(&s_instance);
		}

		return s_instance;
	}

	public static void initialize()
	{
		get_default();
	}
}

}

// ex: ts=4 noet
