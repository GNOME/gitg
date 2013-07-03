class TestDiffView
{
	public static int main(string[] args)
	{
		Gtk.init(ref args);
		Gitg.init();

		if (Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != "local" && args.length > 1 && args[1] == "--local")
		{
			// Launch in local mode
			var path = File.new_for_path(args[0]);
			var gtk = path.get_parent().get_parent().get_parent().get_child("libgitg");

			var rargs = args;

			rargs[0] = "../tests/diff-view";

			for (var i = 1; i < rargs.length - 1; ++i)
			{
				rargs[i] = rargs[i + 1];
			}

			int status;

			var sliced = rargs[0:(rargs.length - 1)];

			var env = Environ.get();
			env += "GITG_GTK_DIFF_VIEW_DEBUG=local";

			try
			{
				Process.spawn_sync(gtk.get_path(),
				                   sliced,
				                   env,
				                   0,
				                   null,
				                   null,
				                   null,
				                   out status);
			}
			catch (Error err)
			{
				stderr.printf("Error while spawning local version: %s\n", err.message);
				return 1;
			}

			return status;
		}

		var inipath = ".";

		if (args.length > 1)
		{
			inipath = args[1];
		}

		File repopath;
		Ggit.Repository repo;

		try
		{
			repopath = Ggit.Repository.discover(File.new_for_commandline_arg(inipath));
			repo = Ggit.Repository.open(repopath);
		}
		catch
		{
			stderr.printf("The specified path is not a git repository: %s\n", inipath);
			return 1;
		}

		Gitg.Commit commit;

		if (args.length > 2)
		{
			try
			{
				commit = repo.revparse(args[2]) as Gitg.Commit;
			}
			catch
			{
				stderr.printf("Failed to parse `%s' as a commit.\n", args[2]);
				return 1;
			}
		}
		else
		{
			try
			{
				var head = repo.get_head();
				commit = head.lookup() as Gitg.Commit;
			}
			catch
			{
				stderr.printf("The repository does not have a current HEAD\n");
				return 1;
			}
		}

		var wnd = new Gtk.Window();
		wnd.set_default_size(800, 600);
		var sw = new Gtk.ScrolledWindow(null, null);

		var v = new Gitg.DiffView();
		sw.add(v);

		v.commit = commit;

		v.key_press_event.connect((vv, ev) => {
			var state = ev.state & Gtk.accelerator_get_default_mod_mask();

			if (ev.keyval == Gdk.Key.r && state == Gdk.ModifierType.CONTROL_MASK)
			{
				v.reload_bypass_cache();
				return true;
			}
			else
			{
				return false;
			}
		});

		wnd.delete_event.connect((w, ev) => {
			Gtk.main_quit();
			return true;
		});

		wnd.add(sw);
		wnd.show_all();

		if (Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != "local")
		{
			stdout.printf("Use `diff-view --local' to use local resources.\n");
		}

		stdout.printf("Press Ctrl+R to refresh...\n");

		Gtk.main();
		return 0;
	}
}

// vi:ts=4
