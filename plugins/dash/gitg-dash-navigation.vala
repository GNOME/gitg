namespace GitgDash
{
	private class Navigation : Object, GitgExt.Navigation
	{
		public GitgExt.Application? application { owned get; construct; }

		public signal void show_open();
		public signal void show_create();
		public signal void show_recent(string uri);
		public signal void activate_recent(string uri);

		public Navigation(GitgExt.Application app)
		{
			Object(application: app);
		}

		public void populate(GitgExt.NavigationTreeModel model)
		{
			model.begin_header("Repository", null)
			     .append_default("Open", "document-open-symbolic", (c) => { show_open(); })
			     .append("Create", "list-add-symbolic", (c) => { show_create(); })
			     .end_header();

			model.begin_header("Recent", null);

			var manager = Gtk.RecentManager.get_default();
			var list = new List<Gtk.RecentInfo>();

			Gee.HashSet<string> uris = new Gee.HashSet<string>();

			foreach (var item in manager.get_items())
			{
				if (!item.has_application("gitg") ||
				    !item.exists())
				{
					continue;
				}

				if (uris.add(item.get_uri()))
				{
					list.prepend(item);
				}
			}

			list.sort((a, b) => {
				if (a.get_visited() < b.get_visited())
				{
					return 1;
				}
				else if (a.get_visited() > b.get_visited())
				{
					return -1;
				}
				else
				{
					return 0;
				}
			});

			foreach (var item in list)
			{
				string uri = item.get_uri();

				model.append(item.get_display_name(),
				             null,
				             (c) => {
					if (c == 1)
					{
						show_recent(uri);
					}
					else
					{
						activate_recent(uri);
					}
				});
			}

			model.end_header();
		}

		public GitgExt.NavigationSide navigation_side
		{
			get { return GitgExt.NavigationSide.LEFT; }
		}

		public bool available
		{
			get { return true; }
		}
	}
}

// ex: ts=4 noet
