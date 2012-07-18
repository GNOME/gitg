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

public class Application : Gtk.Application
{
	public Application()
	{
		Object(application_id: "org.gnome.gitg",
		       flags: ApplicationFlags.HANDLES_OPEN |
		              ApplicationFlags.HANDLES_COMMAND_LINE |
		              ApplicationFlags.SEND_ENVIRONMENT);
	}

	private struct Options
	{
		public static bool quit = false;
		public static string view;
		public static bool startup = false;
		public static bool no_wd = false;
		public static ApplicationCommandLine command_line;

		public static const OptionEntry[] entries = {
			{"version", 'v', OptionFlags.NO_ARG, OptionArg.CALLBACK,
			 (void *)show_version_and_quit, N_("Show the application's version"), null},
			{"view", '\0', 0, OptionArg.STRING,
			 ref view, N_("Start gitg with a particular view"), null},
			 {"no-wd", 0, 0, OptionArg.NONE,
			 ref no_wd, N_("Do not try to load a repository from the current working directory"), null},
			{null}
		};
	}

	private static Options options;

	static construct
	{
		options.view = "";
	}

	private static void show_version_and_quit()
	{
		stdout.printf("%s %s\n",
		              Environment.get_application_name(),
		              Config.VERSION);

		options.quit = true;
	}

	private void parse_command_line(ref unowned string[] argv) throws OptionError
	{
		var ctx = new OptionContext(_("- git repository viewer"));

		ctx.add_main_entries(options.entries, Config.GETTEXT_PACKAGE);
		ctx.add_group(Gtk.get_option_group(true));

		// Add any option groups from plugins
		var engine = PluginsEngine.get_default();

		foreach (var info in engine.get_plugin_list())
		{
			if (info.get_external_data("CommandLine") != null)
			{
				var ext = engine.create_extension(info, typeof(GitgExt.CommandLine)) as GitgExt.CommandLine;

				if (ext != null)
				{
					ctx.add_group(ext.get_option_group());
				}
			}
		}

		ctx.parse(ref argv);
	}

	protected override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)] ref unowned string[] arguments, out int exit_status)
	{
		// Parse command line just for -v and -h
		string[] cp = arguments;
		unowned string[] argv = cp;

		PluginsEngine.initialize();

		try
		{
			// This is just for local things, like showing help
			parse_command_line(ref argv);
		}
		catch (Error e)
		{
			exit_status = 1;
			return true;
		}

		if (options.quit)
		{
			exit_status = 0;
			return true;
		}

		return base.local_command_line(ref arguments, out exit_status);
	}

	protected override int command_line(ApplicationCommandLine cmd)
	{
		string[] arguments = cmd.get_arguments();
		unowned string[] argv = arguments;

		try
		{
			parse_command_line(ref argv);
		}
		catch (Error e)
		{
			cmd.printerr("option parsing failed: %s\n", e.message);
			return 1;
		}

		if (options.quit)
		{
			return 0;
		}

		options.command_line = cmd;

		if (options.startup)
		{
			app_init();
			options.startup = false;
		}

		if (argv.length > 1)
		{
			File[] files = new File[argv.length - 1];
			files.length = 0;

			foreach (string arg in argv[1:argv.length])
			{
				files += File.new_for_commandline_arg(arg);
			}

			open(files, options.view);
		}
		else
		{
			activate();
		}

		return 1;
	}

	private void on_app_new_window_activated()
	{
	}

	private void on_app_help_activated()
	{
	
	}

	private void on_app_about_activated()
	{
		string[] authors = {"Jesse van den Kieboom <jessevdk@gnome.org>",
		                    "Ignacio Casal Quinteiro <icq@gnome.org>"};

		string copyright = "Copyright \xc2\xa9 2012 Jesse van den Kieboom";
		string comments = _("gitg is a git repository viewer for gtk+/GNOME");

		Gdk.Pixbuf? logo = null;

		try
		{
			logo = new Gdk.Pixbuf.from_file(Dirs.build_data_file("icons", "gitg.svg"));
		}
		catch
		{
			try
			{
				logo = new Gdk.Pixbuf.from_file(Dirs.build_data_file("icons", "gitg128x128.png"));
			}
			catch {}
		}

		unowned List<Gtk.Window> wnds = get_windows();

		Gtk.show_about_dialog(wnds != null ? wnds.data : null,
		                      "authors", authors,
		                      "copyright", copyright,
		                      "comments", comments,
		                      "version", Config.VERSION,
		                      "website", Config.PACKAGE_URL,
		                      "website-label", _("gitg homepage"),
		                      "logo", logo,
		                      "license-type", Gtk.License.GPL_2_0);
	}

	private void on_app_quit_activated()
	{
		foreach (var window in get_windows())
		{
			window.destroy();
		}
	}

	private static const ActionEntry[] app_entries = {
		{"new", on_app_new_window_activated},
		{"help", on_app_help_activated},
		{"about", on_app_about_activated},
		{"quit", on_app_quit_activated}
	};

	private void setup_menus()
	{
		add_action_entries(app_entries, this);

		MenuModel[] menus = Resource.load_objects<MenuModel>("ui/gitg-menus.ui", {"app-menu", "win-menu"});

		set_app_menu(menus[0]);
		set_menubar(menus[1]);
	}

	protected override void startup()
	{
		options.startup = true;
		base.startup();

		setup_menus();
	}

	protected override void activate()
	{
		/* Application gets activated when no command line arguments have
		 * been provided. However, gitg does something special in the case
		 * that it has been launched from the terminal. It will try to open
		 * the cwd as a repository. However, when not launched from the terminal
		 * this is undesired, and a --no-wd allows gitg to be launched without
		 * the implicit working directory opening of the repository. In the
		 * end, the following happens:
		 *
		 * 1) --no-wd: present the window
		 * 2) Get cwd from the commandline: open
		 */
		if (options.no_wd)
		{
			present_window();
		}
		else
		{
			// Otherwise open repository from current dir
			string? wd = options.command_line.get_cwd();

			open(new File[] { File.new_for_path(wd) }, options.view);
		}

		base.activate();
	}

	private Window? find_window_for_file(File file)
	{
		foreach (Gtk.Window window in get_windows())
		{
			Window wnd = window as Window;

			if (wnd.repository == null)
			{
				continue;
			}

			if (wnd.repository.get_location().equal(file))
			{
				return wnd;
			}
		}

		return null;
	}

	protected override void open(File[] files, string hint)
	{
		if (files.length == 0)
		{
			return;
		}

		bool opened = false;

		// Set of files are potential git repositories
		foreach (File f in files)
		{
			// See if the repository is already open somewhere
			Window? window = find_window_for_file(f);

			if (window != null)
			{
				// Present the window with this repository open
				window.present_with_time(Gdk.CURRENT_TIME);
				continue;
			}

			File? resolved;

			// Try to open a repository at this location
			try
			{
				resolved = Ggit.Repository.discover(f);
			}
			catch { continue; }

			// Open the repository
			Repository? repo;

			try
			{
				repo = new Repository(resolved, null);
			}
			catch { continue; }

			// Finally, create a window for the repository
			new_window(repo, hint);
			opened = true;
		}

		if (!opened)
		{
			// still open a window
			present_window();
		}
	}

	private void app_init()
	{
		Gtk.CssProvider? provider = Resource.load_css("style.css");

		if (provider != null)
		{
			Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),
			                                         provider,
			                                         600);
		}

		var theme = Gtk.IconTheme.get_default();
		theme.prepend_search_path(Path.build_filename(Config.GITG_DATADIR, "icons"));
	}

	private void new_window(Repository? repo = null, string? hint = null)
	{
		add_window(Window.create_new(this, repo, hint));
		present_window();
	}

	private void present_window()
	{
		/* Present the first window in the windows registered on the
		 * application. If there are no windows, then create a new empty
		 * window.
		 */
		unowned List<Gtk.Window> windows = get_windows();

		if (windows == null)
		{
			new_window();
			return;
		}

		windows.data.present_with_time(Gdk.CURRENT_TIME);
	}
}

}

// ex:set ts=4 noet
