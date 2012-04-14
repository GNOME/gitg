namespace Gitg
{
	class Resource
	{
		public static T[]? load_objects<T>(string id, string[] objects)
		{
			var builder = new Gtk.Builder();

			try
			{
				builder.add_from_resource("/org/gnome/gitg/" + id);
			}
			catch (Error e)
			{
				warning("Error while loading resource: %s", e.message);
				return null;
			}

			T[] ret = new T[objects.length];
			ret.length = 0;

			foreach (string obj in objects)
			{
				ret += (T)builder.get_object(obj);
			}

			return ret;
		}

		public static T? load_object<T>(string id, string object)
		{
			T[]? ret = load_objects<T>(id, new string[] {object});

			if (ret == null)
			{
				return null;
			}

			return ret[0];
		}

		public static Gtk.CssProvider? load_css(string id)
		{
			var provider = new Gtk.CssProvider();
			var f = File.new_for_uri("resource:///org/gnome/gitg/ui/" + id);

			try
			{
				provider.load_from_file(f);
			}
			catch (Error e)
			{
				warning("Error while loading resource: %s", e.message);
				return null;
			}

			return provider;
		}
	}
}

// ex: ts=4 noet
