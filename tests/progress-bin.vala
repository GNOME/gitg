using Gtk;
using Gitg;

class TestProgressGrid
{
	public static int main(string[] args)
	{
		Gtk.init(ref args);

		try
		{
			Gitg.init();
		}
		catch (Error e)
		{
			stderr.printf("Failed to initialize ggit: %s\n", e.message);
			return 1;
		}

		var window = new Window();
		window.set_default_size(300, 300);
		var grid = new ProgressBin();
		grid.fraction = 0.3;
		window.add(grid);
		window.show_all();

		window.delete_event.connect((w, ev) => {
			Gtk.main_quit();
			return true;
		});

		Gtk.main();

		return 0;
	}
}

// vi:ts=4
