using Gtk;
using Gitg;

class TestRepositoryListBox
{
	public static int main(string[] args)
	{
		Gtk.init(ref args);
		Gitg.init();

		var window = new Window();
		window.set_default_size(300, 300);
		window.add(new RepositoryListBox());
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
