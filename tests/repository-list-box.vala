using Gtk;
using Gitg;

class TestRepositoryListBox
{
	public static int main(string[] args)
	{
		Gtk.init();

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
		window.add(new RepositoryListBox());
		window.present();

		var loop = new GLib.MainLoop();

		window.close_request.connect(() => {
			loop.quit();
			return true;
		});

		loop.run();

		return 0;
	}
}

// vi:ts=4
