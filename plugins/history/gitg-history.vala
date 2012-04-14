namespace GitgHistory
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public class View : Object, GitgExt.View
	{
		public GitgExt.Application? application { owned get; construct; }

		private Gtk.Widget d_main;

		public string id
		{
			owned get { return "/org/gnome/gitg/Views/History"; }
		}

		public bool is_available()
		{
			// The history view is available only when there is a repository
			return application.repository != null;
		}

		public string display_name
		{
			owned get { return "History"; }
		}

		public Icon? icon
		{
			owned get { return new ThemedIcon("view-list-symbolic"); }
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				if (d_main == null)
				{
					build_ui();
				}

				return d_main;
			}
		}

		public GitgExt.Navigation? navigation
		{
			owned get
			{
				var ret = new Navigation(application);

				return ret;
			}
		}

		public bool is_default_for(GitgExt.ViewAction action)
		{
			return application.repository != null && action == GitgExt.ViewAction.HISTORY;
		}

		private void build_ui()
		{
			var ret = from_builder("view-history.ui", {"view"});

			d_main = ret["view"] as Gtk.Widget;
		}

		private Gee.HashMap<string, Object>? from_builder(string path, string[] ids)
		{
			var builder = new Gtk.Builder();

			try
			{
				builder.add_from_resource("/org/gnome/gitg/history/" + path);
			}
			catch (Error e)
			{
				warning("Failed to load ui: %s", e.message);
				return null;
			}

			Gee.HashMap<string, Object> ret = new Gee.HashMap<string, Object>();

			foreach (string id in ids)
			{
				ret[id] = builder.get_object(id);
			}

			return ret;
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.View),
	                            typeof(GitgHistory.View));
}

// ex: ts=4 noet
