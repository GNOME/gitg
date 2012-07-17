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

namespace GitgDiff
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public class Panel : Object, GitgExt.UIElement, GitgExt.Panel
	{
		public GitgExt.Application? application { owned get; construct set; }
		private Gtk.ScrolledWindow d_sw;
		private GitgGtk.DiffView d_diff;
		private GitgExt.ObjectSelection? d_view;

		construct
		{
			d_diff = new GitgGtk.DiffView(null);
			d_sw = new Gtk.ScrolledWindow(null, null);

			d_sw.show();
			d_diff.show();

			d_sw.add(d_diff);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Panels/Diff"; }
		}

		public bool is_available()
		{
			var view = application.current_view;

			if (view == null)
			{
				return false;
			}

			return (view is GitgExt.ObjectSelection);
		}

		public string display_name
		{
			owned get { return "Diff"; }
		}

		public Icon? icon
		{
			owned get { return new ThemedIcon("diff-symbolic"); }
		}

		private void on_selection_changed(GitgExt.ObjectSelection selection)
		{
			selection.foreach_selected((commit) => {
				var c = commit as Ggit.Commit;

				if (c != null)
				{
					d_diff.commit = c;
					return false;
				}

				return true;
			});
		}

		public Gtk.Widget? widget
		{
			owned get
			{
				var objsel = (GitgExt.ObjectSelection)application.current_view;

				if (objsel != d_view)
				{
					if (d_view != null)
					{
						d_view.selection_changed.disconnect(on_selection_changed);
					}

					d_view = objsel;
					d_view.selection_changed.connect(on_selection_changed);
				}

				return d_sw;
			}
		}

		public bool is_enabled()
		{
			// TODO
			return true;
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.Panel),
	                            typeof(GitgDiff.Panel));
}

// ex: ts=4 noet
