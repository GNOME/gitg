/*
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

namespace Gitg
{

public class Utils
{
	public static string replace_home_dir_with_tilde(File file)
	{
		var name = file.get_parse_name();
		var homedir = Environment.get_home_dir();

		if (homedir != null)
		{
			try
			{
				var hd = Filename.to_utf8(homedir, -1, null, null);

				if (hd == name)
				{
					name = "~/";
				}
				else
				{
					if (name.has_prefix(hd + "/"))
					{
						name = "~" + name[hd.length:name.length];
					}
				}
			} catch {}
		}

		return name;
	}

	public static string expand_home_dir(string path)
	{
		string? homedir = null;
		int pos = -1;

		if (path.has_prefix("~/"))
		{
			homedir = PlatformSupport.get_user_home_dir();
			pos = 1;
		}
		else if (path.has_prefix("~"))
		{
			pos = path.index_of_char('/');
			var user = path[1:pos];

			homedir = PlatformSupport.get_user_home_dir(user);
		}

		if (homedir != null)
		{
			return Path.build_filename(homedir, path.substring(pos + 1));
		}

		return path;
	}
}

}

// ex:ts=4 noet
