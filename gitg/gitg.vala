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
	private static void init_error(string[] args, string msg)
	{
		Gtk.init(ref args);

		var dlg = new Gtk.MessageDialog(null,
		                                0,
		                                Gtk.MessageType.ERROR,
		                                Gtk.ButtonsType.CLOSE,
		                                "%s",
		                                msg);

		dlg.window_position = Gtk.WindowPosition.CENTER;

		dlg.response.connect(() => { Gtk.main_quit(); });
		dlg.show();

		Gtk.main();
	}

	public static int main(string[] args)
	{
		Intl.setlocale(LocaleCategory.ALL, "");
		Intl.bindtextdomain(Config.GETTEXT_PACKAGE, Config.GITG_LOCALEDIR);
		Intl.bind_textdomain_codeset(Config.GETTEXT_PACKAGE, "UTF-8");
		Intl.textdomain(Config.GETTEXT_PACKAGE);

		Environment.set_prgname("gitg");
		Environment.set_application_name(_("gitg"));

		try
		{
			Gitg.init();
		}
		catch (Error e)
		{
			if (e is Gitg.InitError.THREADS_UNSAFE)
			{
				var errmsg = _("We are terribly sorry, but gitg requires libgit2 (a library on which gitg depends) to be compiled with threading support.\n\nIf you manually compiled libgit2, then please configure libgit2 with -DTHREADSAFE:BOOL=ON.\n\nOtherwise, report a bug in your distributions' bug reporting system for providing libgit2 without threading support.");

				init_error(args, errmsg);
				error("%s", errmsg);
			}

			Process.exit(1);
		}

		// Make sure to pull in gd symbols since libgd gets linked statically
		Gd.ensure_types();

		Application app = new Application();
		return app.run(args);
	}
}

}

// ex:set ts=4 noet
