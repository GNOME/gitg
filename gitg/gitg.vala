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

private const string version = Config.VERSION;

public class Main
{
	public static int main(string[] args)
	{
		Gtk.disable_setlocale();

		Intl.setlocale(LocaleCategory.ALL, "");
		Intl.setlocale(LocaleCategory.COLLATE, "C");

		Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Dirs.locale_dir);
		Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
		Intl.textdomain(Config.GETTEXT_PACKAGE);

		Environment.set_prgname("gitg");
		Environment.set_application_name(_("gitg"));

		Application app = new Application();
		return app.run(args);
	}
}

}

// ex:set ts=4 noet
