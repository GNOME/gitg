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
	private Settings d_state_settings;

	public Settings state_settings
	{
		owned get { return d_state_settings; }
	}

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
		public static string activity;
		public static bool no_wd = false;

		public static ApplicationCommandLine command_line;

		private static void commit_activity()
		{
			activity = "commit";
		}

		public static const OptionEntry[] entries = {
			{"version", 'v', OptionFlags.NO_ARG, OptionArg.CALLBACK,
			 (void *)show_version_and_quit, N_("Show the application's version"), null},

			{"activity", '\0', 0, OptionArg.STRING,
			 ref activity, N_("Start gitg with a particular activity"), null},

			{"commit", 'c', OptionFlags.NO_ARG, OptionArg.CALLBACK,
			 (void *)commit_activity, N_("Start gitg with the commit activity (shorthand for --activity commit)"), null},

			 {"no-wd", 0, 0, OptionArg.NONE,
			 ref no_wd, N_("Do not try to load a repository from the current working directory"), null},

			{null}
		};
	}

	private PreferencesDialog d_preferences;

	static construct
	{
		Options.activity = "";
	}

	private static void show_version_and_quit()
	{
		stdout.printf("%s %s\n",
		              Environment.get_application_name(),
		              Config.VERSION);

		Options.quit = true;
	}

	private void parse_command_line(ref unowned string[] argv) throws OptionError
	{
		var ctx = new OptionContext(_("- Git repository viewer"));

		ctx.add_main_entries(Options.entries, Config.GETTEXT_PACKAGE);
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

		if (Options.quit)
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

		if (Options.quit)
		{
			return 0;
		}

		if (!cmd.get_is_remote())
		{
			Options.command_line = cmd;
		}

		var tmpcmd = Options.command_line;
		Options.command_line = cmd;

		if (argv.length > 1)
		{
			File[] files = new File[argv.length - 1];
			files.length = 0;

			foreach (string arg in argv[1:argv.length])
			{
				files += File.new_for_commandline_arg(arg);
			}

			open(files, Options.activity);
		}
		else
		{
			activate();
		}

		Options.command_line = tmpcmd;

		return 1;
	}

	private void on_app_new_window_activated()
	{
		new_window();
	}

	private void on_app_help_activated()
	{
	}

	private void on_app_about_activated()
	{
		string[] artists = {"Jakub Steiner <jimmac@gmail.com>"};
		string[] authors = {"Jesse van den Kieboom <jessevdk@gnome.org>",
		                    "Ignacio Casal Quinteiro <icq@gnome.org>"};

		string copyright = "Copyright \xc2\xa9 2012 Jesse van den Kieboom";
		string comments = _("gitg is a Git repository viewer for gtk+/GNOME");

		unowned List<Gtk.Window> wnds = get_windows();

		Gtk.show_about_dialog(wnds != null ? wnds.data : null,
		                      "artists", artists,
		                      "authors", authors,
		                      "copyright", copyright,
		                      "comments", comments,
		                      "translator-credits", _("translator-credits"),
		                      "version", Config.VERSION,
		                      "website", Config.PACKAGE_URL,
		                      "website-label", _("gitg homepage"),
		                      "logo-icon-name", Config.PACKAGE_NAME,
		                      "license-type", Gtk.License.GPL_2_0);
	}

	private void on_app_quit_activated()
	{
		foreach (var window in get_windows())
		{
			window.destroy();
		}
	}

	private void on_preferences_activated()
	{
		unowned List<Gtk.Window> wnds = get_windows();

		// Create preferences dialog if needed
		if (d_preferences == null)
		{
			d_preferences = Resource.load_object<PreferencesDialog>("ui/gitg-preferences.ui", "preferences");

			d_preferences.destroy.connect((w) => {
				d_preferences = null;
			});

			d_preferences.response.connect((w, r) => {
				d_preferences.destroy();
			});
		}

		if (wnds != null)
		{
			d_preferences.set_transient_for(wnds.data);
		}

		d_preferences.present();
	}

	private static const ActionEntry[] app_entries = {
		{"new", on_app_new_window_activated},
		{"help", on_app_help_activated},
		{"about", on_app_about_activated},
		{"quit", on_app_quit_activated},
		{"preferences", on_preferences_activated}
	};

	struct Accel
	{
		string name;
		string accel;
	}

	protected override void startup()
	{
		base.startup();

		// Handle the state setting in the application
		d_state_settings = new Settings("org.gnome.gitg.state.window");
		d_state_settings.delay();

		// Application menu entries
		add_action_entries(app_entries, this);

		const Accel[] accels = {
			{"app.new", "<Primary>N"},
			{"app.quit", "<Primary>Q"},
			{"app.help", "F1"},

			{"win.search", "<Primary>F"},
			{"win.close", "<Primary>Q"},
			{"win.reload", "<Primary>R"},
			{"win.gear-menu", "F10"},
			{"win.open-repository", "<Primary>O"}
		};

		foreach (var accel in accels)
		{
			add_accelerator(accel.accel, accel.name, null);
		}

		if (Gtk.Settings.get_default().gtk_shell_shows_app_menu)
		{
			MenuModel? menu = Resource.load_object<MenuModel>("ui/gitg-menus.ui", "app-menu");

			if (menu != null)
			{
				set_app_menu(menu);
			}
		}

		// Use our own css provider
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

	protected override void shutdown()
	{
		d_state_settings.apply();
		base.shutdown();
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
		if (Options.no_wd)
		{
			present_window();
		}
		else
		{
			// Otherwise open repository from current dir
			string? wd = Options.command_line.get_cwd();

			open(new File[] { File.new_for_path(wd) }, Options.activity);

			// Forcing present here covers the case where no window was opened
			// because wd is not an actual git repository
			present_window();
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

		// Set of files are potential git repositories
		foreach (File f in files)
		{
			File? resolved;

			// Try to open a repository at this location
			try
			{
				resolved = Ggit.Repository.discover(f);
			}
			catch { continue; }

			// See if the repository is already open somewhere
			Window? window = find_window_for_file(resolved);

			if (window != null)
			{
				// Present the window with this repository open
				window.set_environment(Options.command_line.get_environ());
				window.present();
				continue;
			}

			// Open the repository
			Repository? repo;

			try
			{
				repo = new Repository(resolved, null);
			}
			catch { continue; }

			// Finally, create a window for the repository
			new_window(repo, hint);
		}
	}

	private void new_window(Repository? repo = null, string? hint = null)
	{
		var window = Window.create_new(this, repo, hint);

		if (window != null)
		{
			window.set_environment(Options.command_line.get_environ());
		}

		present_window();
	}

	private void present_window()
	{
		/* Present the last window in the windows registered on the
		 * application. If there are no windows, then create a new empty
		 * window.
		 */
		unowned List<Gtk.Window> windows = get_windows();

		if (windows == null)
		{
			new_window();
			return;
		}

		var w = (Gitg.Window)windows.first().data;

		w.set_environment(Options.command_line.get_environ());
		w.present();
	}
}

}

// ex:set ts=4 noet
