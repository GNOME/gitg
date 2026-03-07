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

	public static bool gitg_styles_path_added = false;

	public static GtkSource.StyleSchemeManager get_source_style_manager()
	{
		var style_manager = GtkSource.StyleSchemeManager.get_default();
		if (gitg_styles_path_added)
		{
			style_manager.append_search_path(Path.build_filename (PlatformSupport.get_data_dir(), "styles"));
			style_manager.force_rescan();
			gitg_styles_path_added = true;
		}
		return style_manager;
	}

	public static void update_style_value(Settings? settings, string to, string from)
	{
		var style = settings.get_string("style-scheme");
		if (style.has_suffix(to))
			return;
		var manager = Gitg.Utils.get_source_style_manager();
		var style_prefix = style;
		if (style.has_suffix(from)) {
			style_prefix = style.substring(0, style_prefix.length-6);
			if (manager.get_scheme(style_prefix) != null) {
				settings.set_string("style-scheme", style_prefix);
				return;
			}
		}
		var new_style = style_prefix+to;
		if (manager.get_scheme(new_style) != null) {
			settings.set_string("style-scheme", new_style);
		}
	}

	public static Gee.HashMap<string, string>? theme_light_dark;

	public static void update_style_by_theme(Settings? settings)
	{
		if (theme_light_dark == null)
		{
			theme_light_dark = new Gee.HashMap<string, string>();
			var m = theme_light_dark;
			m.set("adwaita", "adwaita-dark");
			m.set("classic", "classic-dark");
			m.set("solarized-light", "solarized-dark");
			m.set("tango", "oblivion");
			m.set("kate", "kate-dark");
			m.set("cobalt-light", "cobalt");
		}

		var dark = Hdy.StyleManager.get_default ().dark;
		var scheme = settings.get_string("style-scheme");
		if (dark) {
			if (theme_light_dark.has_key(scheme)) {
				settings.set_string("style-scheme", theme_light_dark.get(scheme));
			} else {
				update_style_value(settings, "-dark", "light");
			}
		} else {
			bool set_style = false;
			foreach (string k in theme_light_dark.keys) {
				if (theme_light_dark.get (k) == scheme) {
					settings.set_string("style-scheme", k);
					set_style = true;
					break;
				}
			}
			if (!set_style)
				update_style_value(settings, "-light", "-dark");
		}
	}

	public static void update_buffer_style(Settings settings, GtkSource.Buffer source_buffer)
	{
		var scheme = settings.get_string("style-scheme");
		var manager = Gitg.Utils.get_source_style_manager();
		var s = manager.get_scheme(scheme);

		if (s != null)
		{
			source_buffer.style_scheme = s;
		}
	}

	public static bool is_main_remote(Gitg.Repository? repository, string name) {
		var main_remote = get_config_value(repository, "gitg.main-remote", null);
		return main_remote == null
			? name == "origin"
			: main_remote == name;
	}

	public static string?  get_config_value(Gitg.Repository? repository,
	                                  string key,
	                                  string? default_value)
	{
		string? result = default_value;

		if (repository == null)
		{
			return result;
		}

		Ggit.Config config;

		try
		{
			config = repository.get_config();
		} catch {
			return result;
		}

		if (config != null) {
			try
			{
				result = config.snapshot().get_string(key);
			}
			catch {}
		}
		return result;
	}
}
}

// ex:ts=4 noet
