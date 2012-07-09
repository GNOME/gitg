class Test
{
	private static int f(Ggit.DiffDelta? delta, Ggit.DiffRange? range, Ggit.DiffLineType t, uint8[] content)
	{
		var s = ((string)content).substring(0, content.length);
		stdout.printf("hello: %s", s);
		return 0;
	}
	public static void main(string[] args)
	{
		Gtk.init(ref args);

		var wnd = new Gtk.Window();
		var v = new GitgGtk.DiffView(File.new_for_path("base.js"));

		var repo = Ggit.Repository.open(File.new_for_path("../"));

		if (repo == null)
		{
			stderr.printf("Failed\n");
			return;
		}

		var opts = new Ggit.DiffOptions(Ggit.DiffFlags.NORMAL,
		                                3,
		                                3,
		                                null,
		                                null,
		                                null);

		var diff = new Ggit.Diff.workdir_to_index(repo, opts);

		v.diff = diff;

		wnd.add(v);
		wnd.show_all();

		Gtk.main();
	}
}
