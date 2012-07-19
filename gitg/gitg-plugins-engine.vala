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
