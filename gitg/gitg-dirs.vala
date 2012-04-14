namespace Gitg
{

public class Dirs
{
	public static string data_dir
	{
		get { return Config.GITG_DATADIR; }
	}

	public static string locale_dir
	{
		get { return Config.GITG_LOCALEDIR; }
	}

	public static string lib_dir
	{
		get { return Config.GITG_LIBDIR; }
	}

	public static string plugins_dir
	{
		owned get { return Path.build_filename(lib_dir, "plugins"); }
	}

	public static string plugins_data_dir
	{
		owned get { return Path.build_filename(data_dir, "plugins"); }
	}

	public static string user_plugins_dir
	{
		owned get { return Path.build_filename(Environment.get_user_data_dir(), "gitg", "plugins"); }
	}

	public static string user_plugins_data_dir
	{
		owned get { return user_plugins_dir; }
	}

	public static string build_data_file(string part, ...)
	{
		var l = va_list();
		var ret = Path.build_filename(data_dir, part, null);

		while (true)
		{
			string? s = l.arg();

			if (s == null)
			{
				break;
			}

			ret = Path.build_filename(ret, s);
		}

		return ret;
	}
}

}

// ex: ts=4 noet
