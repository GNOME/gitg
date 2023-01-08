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
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private Settings d_state_settings;

	private static bool app_quit = false;
	private static string activity;
	private static bool no_wd = false;
	private static bool standalone = false;
	private static ApplicationCommandLine app_command_line;
	private static bool init = false;

	private const OptionEntry[] entries = {
		{"version", 'v', OptionFlags.NO_ARG, OptionArg.CALLBACK,
		 (void *)show_version_and_quit, N_("Show the application’s version"), null},
		{"activity", '\0', 0, OptionArg.STRING,
		 ref activity, N_("Start gitg with a particular activity"), null},
		{"commit", 'c', OptionFlags.NO_ARG, OptionArg.CALLBACK,
		 (void *)commit_activity, N_("Start gitg with the commit activity (shorthand for --activity commit)"), null},
		{"no-wd", 0, 0, OptionArg.NONE,
		 ref no_wd, N_("Do not try to load a repository from the current working directory"), null},
		{"standalone", 0, 0, OptionArg.NONE,
		 ref standalone, N_("Run gitg in standalone mode"), null},
		{"init", 0, 0, OptionArg.NONE,
		 ref init, N_("Put paths under git if needed"), null},
		{null}
	};

	private static bool commit_activity()
	{
		activity = "commit";
		return true;
	}

	public Settings state_settings
	{
		owned get { return d_state_settings; }
	}

	public Application()
	{
		Object(application_id:  Gitg.Config.APPLICATION_ID,
		       flags: ApplicationFlags.HANDLES_OPEN |
		              ApplicationFlags.HANDLES_COMMAND_LINE |
		              ApplicationFlags.SEND_ENVIRONMENT);
	}

	private PreferencesDialog d_preferences;

#if GTK_SHORTCUTS_WINDOW
	private Gtk.ShortcutsWindow d_shortcuts;
#endif

	static construct
	{
		activity = "";
	}

	private static bool show_version_and_quit()
	{
		stdout.printf("%s %s\n",
		              Environment.get_application_name(),
		              Config.VERSION);

		app_quit = true;
		return true;
	}

	private GitgExt.CommandLines parse_command_line(ref unowned string[] argv) throws OptionError
	{
		var ctx = new OptionContext(_("— Git repository viewer"));

		ctx.add_main_entries(entries, Config.GETTEXT_PACKAGE);
		ctx.add_group(Gtk.get_option_group(true));

		var cmdexts = new GitgExt.CommandLine[0];

		var historycmd = new GitgHistory.CommandLine();
		cmdexts += historycmd;

		ctx.add_group(historycmd.get_option_group());

		// Add any option groups from plugins
		var engine = PluginsEngine.get_default();

		foreach (var info in engine.get_plugin_list())
		{
			if (info.get_external_data("CommandLine") != null)
			{
				var ext = engine.create_extension(info, typeof(GitgExt.CommandLine)) as GitgExt.CommandLine;

				if (ext != null)
				{
					cmdexts += ext;
					ctx.add_group(ext.get_option_group());
				}
			}
		}

		ctx.parse(ref argv);

		var ret = new GitgExt.CommandLines(cmdexts);
		ret.parse_finished();

		return ret;
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
			stderr.printf("Failed to parse options: %s\n", e.message);
			exit_status = 1;
			return true;
		}

		if (!standalone)
		{
			set_flags(get_flags() | ApplicationFlags.NON_UNIQUE);
		}

		if (app_quit)
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
		GitgExt.CommandLines command_lines;

		try
		{
			command_lines = parse_command_line(ref argv);
		}
		catch (Error e)
		{
			cmd.printerr("option parsing failed: %s\n", e.message);
			return 1;
		}

		if (app_quit)
		{
			return 0;
		}

		if (!cmd.get_is_remote())
		{
			app_command_line = cmd;
		}

		var tmpcmd = app_command_line;
		app_command_line = cmd;

		if (argv.length > 1)
		{
			File[] files = new File[argv.length - 1];
			files.length = 0;

			foreach (string arg in argv[1:argv.length])
			{
				files += File.new_for_commandline_arg(arg);
			}

			open_command_line(files, activity, command_lines);
		}
		else
		{
			activate_command_line(command_lines);
		}

		app_command_line = tmpcmd;
		return 1;
	}

	private void on_app_new_window_activated()
	{
		new_window();
	}

	private void on_app_about_activated()
	{
		string[] artists = {"Jakub Steiner <jimmac@gmail.com>"};
		string[] authors = {"Jesse van den Kieboom <jessevdk@gnome.org>",
		                    "Ignacio Casal Quinteiro <icq@gnome.org>",
		                    "Alberto Fanjul <albfan@gnome.org>"};

		string copyright = "Copyright \xc2\xa9 2012 Jesse van den Kieboom";
		string comments = _("gitg is a Git repository viewer for GTK+/GNOME");

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
		                      "logo-icon-name", Gitg.Config.APPLICATION_ID,
		                      "license-type", Gtk.License.GPL_2_0);
	}

	private void on_app_quit_activated()
	{
		var wnds = get_windows().copy();

		foreach (var window in wnds)
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
			d_preferences = Builder.load_object<PreferencesDialog>("ui/gitg-preferences.ui", "preferences");

			d_preferences.destroy.connect((w) => {
				d_preferences = null;
			});
		}

		if (wnds != null)
		{
			d_preferences.set_transient_for(wnds.data);
		}

		d_preferences.present();
	}

	private void on_shortcuts_activated()
	{
#if GTK_SHORTCUTS_WINDOW

		unowned List<Gtk.Window> wnds = get_windows();

		// Create shortcuts window if needed
		if (d_shortcuts == null)
		{
			var shortcuts_ui_objects = GitgExt.UI.from_builder("ui/gitg-shortcuts.ui", "shortcuts-gitg", "history-shortcuts-group");
			d_shortcuts = (Gtk.ShortcutsWindow) shortcuts_ui_objects["shortcuts-gitg"];

			if(plugins_accel != null)
			{
				var history_shortcuts_group = (Gtk.ShortcutsGroup) shortcuts_ui_objects["history-shortcuts-group"];
				history_shortcuts_group.set_visible(true);

				foreach(var element in plugins_accel)
				{
					var shortcut = (Gtk.ShortcutsShortcut) Object.new(typeof(Gtk.ShortcutsShortcut),
					                "title", element.name,
					                "accelerator", "<Alt>" + element.shortcut,
					                null);
					shortcut.set_visible(true);
					history_shortcuts_group.add(shortcut);
				}
			}

			d_shortcuts.destroy.connect((w) => {
				d_shortcuts = null;
			});
		}

		if (wnds != null)
		{
			d_shortcuts.set_transient_for(wnds.data);
		}

		d_shortcuts.present();
#endif
	}

	private void on_app_author_details_global_activated()
	{
		unowned List<Gtk.Window> wnds = get_windows();
		Window? window = null;

		if (wnds != null)
		{
			window = wnds.data as Window;
		}

		AuthorDetailsDialog.show_global(window);
	}

	private const ActionEntry[] app_entries = {
		{"new", on_app_new_window_activated},
		{"about", on_app_about_activated},
		{"quit", on_app_quit_activated},
		{"author-details-global", on_app_author_details_global_activated},
		{"preferences", on_preferences_activated}
	};

#if GTK_SHORTCUTS_WINDOW
	private const ActionEntry[] shortcut_window_entries = {
		{"shortcuts", on_shortcuts_activated}
	};
#endif

	struct Accel
	{
		string name;
		string accel;
	}

	struct MultiAccel
	{
		string name;
		string[] accels;
	}

	struct PluginAccel
	{
		string name;
		string shortcut;
	}

	private List<PluginAccel?> plugins_accel;

	private void init_error(string msg)
	{
		var dlg = new Gtk.MessageDialog(null,
		                                0,
		                                Gtk.MessageType.ERROR,
		                                Gtk.ButtonsType.CLOSE,
		                                "%s",
		                                msg);

		dlg.window_position = Gtk.WindowPosition.CENTER;

		dlg.response.connect(() => { Gtk.main_quit(); });
		dlg.show();
	}

	protected override void startup()
	{
		base.startup();
		Hdy.init ();
		var style_manager = Hdy.StyleManager.get_default();
		style_manager.color_scheme = PREFER_LIGHT;

		PlatformSupport.application_support_prepare_startup();

		try
		{
			Gitg.init();
		}
		catch (Error e)
		{
			if (e is Gitg.InitError.THREADS_UNSAFE)
			{
				var errmsg = _("We are terribly sorry, but gitg requires libgit2 (a library on which gitg depends) to be compiled with threading support.\n\nIf you manually compiled libgit2, then please configure libgit2 with -DTHREADSAFE:BOOL=ON.\n\nOtherwise, report a bug in your distributions’ bug reporting system for providing libgit2 without threading support.");

				init_error(errmsg);
				error("%s", errmsg);
			}

			return;
		}

		// Handle the state setting in the application
		d_state_settings = new Settings(Gitg.Config.APPLICATION_ID + ".state.window");
		d_state_settings.delay();

		// Application menu entries
		add_action_entries(app_entries, this);

#if GTK_SHORTCUTS_WINDOW
		add_action_entries(shortcut_window_entries, this);
#endif

		const Accel[] single_accels = {
			{"app.new", "<Primary>N",},
			{"app.quit", "<Primary>Q"},
			{"app.shortcuts", "<Primary>question"},

			{"win.search", "<Primary>F"},
			{"win.gear-menu", "F10"},
			{"win.open-repository", "<Primary>O"},
			{"win.close", "<Primary>W"},
			{"win.preferences", "<Primary>comma"},
		};

		var multi_accels = new MultiAccel[] {
			MultiAccel() {
				name = "win.reload",
				accels = new string[] {"<Primary>R", "F5"}
			}
		};

		foreach (var accel in single_accels)
		{
			set_accels_for_action(accel.name, new string[] {accel.accel});
		}

		foreach (var accel in multi_accels)
		{
			set_accels_for_action(accel.name, accel.accels);
		}

		add_css("style.css");
		add_css(@"style-$(Config.PLATFORM_NAME).css");;

		var theme = Gtk.IconTheme.get_default();
		theme.prepend_search_path(Path.build_filename(PlatformSupport.get_data_dir(), "icons"));
	}

	private void add_css(string path)
	{
		Gtk.CssProvider? provider = Resource.load_css(path);

		if (provider != null)
		{
			Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),
			                                         provider,
			                                         600);
		}
	}

	protected override void shutdown()
	{
		d_state_settings.apply();
		base.shutdown();
	}

	private void activate_command_line(GitgExt.CommandLines command_lines)
	{
		if (no_wd)
		{
			present_window(activity, command_lines);
		}
		else
		{
			unowned string git_dir_env = app_command_line.getenv("GIT_DIR");
			if (git_dir_env != null)
			{
				File[] files = new File[] {File.new_for_path(git_dir_env)};
				open_command_line(files, activity, command_lines);
			} else {
				// Otherwise open repository from current dir
				string? wd = app_command_line.get_cwd();

				open(new File[] { File.new_for_path(wd) }, activity);
				present_window(activity, command_lines);
			}
		}
	}

	protected override void activate()
	{
		present_window();
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
		open_command_line(files, hint);
	}


	private void open_command_line(File[] files, string? hint = null, GitgExt.CommandLines? command_lines = null)
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
			catch (Error err) {
				if (!init)
				{
					stderr.printf("Error: %s.\n", err.message);
					continue;
				}

				try
				{
					bool exists = f.query_exists ();

					bool valid = exists
                                                ? FileType.DIRECTORY == f.query_file_type (FileQueryInfoFlags.NOFOLLOW_SYMLINKS)
                                                : f.make_directory_with_parents ();

					string path = f.get_path();
					if (!valid)
					{
						stderr.printf("Invalid location %s.\n", path);
						continue;
					}

					Repository.init_repository(f, false);
					resolved = Ggit.Repository.discover(f);
					stdout.printf("Successfully initialized git repository at “%s”.\n", path);
				}
				catch (Error err2)
				{
					stderr.printf("Error: %s.\n", err2.message);
					continue;
				}
			}


			// See if the repository is already open somewhere
			Window? window = find_window_for_file(resolved);

			if (window != null)
			{
				// Present the window with this repository open
				window.set_environment(app_command_line.get_environ());
				window.present(hint, command_lines);
				continue;
			}

			// Open the repository
			Repository? repo;

			try
			{
				repo = new Repository(resolved, null);
			}
			catch (Error err)
			{
				stderr.printf("Error: not able to open repository “%s”.\n", err.message);
				continue;
			}

			// Finally, create a window for the repository
			new_window(repo, hint, command_lines);
		}
	}

	private void new_window(Repository? repo = null, string? hint = null, GitgExt.CommandLines? command_lines = null)
	{
		var window = Window.create_new(this, repo, hint);

		if (window != null)
		{
			window.set_environment(app_command_line.get_environ());
		}

		present_window(hint, command_lines);
	}

	private void present_window(string? activity = null, GitgExt.CommandLines? command_lines = null)
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

		w.set_environment(app_command_line.get_environ());
		w.present(activity, command_lines);
	}

	public void register_shortcut(string name, uint shortcut)
	{
		if(plugins_accel == null)
		{
			plugins_accel = new List<PluginAccel?>();
		}

		PluginAccel plugin_accel = { name, Gdk.keyval_name(shortcut) };
		plugins_accel.append(plugin_accel);
	}
}

}

// ex:set ts=4 noet
