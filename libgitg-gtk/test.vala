class Test
{
	public static void main(string[] args)
	{
		Gtk.init(ref args);

		var wnd = new Gtk.Window();
		wnd.set_default_size(800, 600);
		var sw = new Gtk.ScrolledWindow(null, null);

		var v = new GitgGtk.DiffView(null);
		sw.add(v);

		var repo = Ggit.Repository.open(File.new_for_path("../"));

		if (repo == null)
		{
			stderr.printf("Failed\n");
			return;
		}

		v.options = new Ggit.DiffOptions(Ggit.DiffFlags.NORMAL,
		                                3,
		                                3,
		                                null,
		                                null,
		                                null);

		var commit = repo.get_head().lookup() as Ggit.Commit;
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

		wnd.add(sw);
		wnd.show_all();

		Gtk.main();
	}
}
