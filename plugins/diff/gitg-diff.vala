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
	public class Panel : Object, GitgExt.UIElement, GitgExt.HistoryPanel
	{
		// Do this to pull in config.h before glib.h (for gettext...)
		private const string version = Gitg.Config.VERSION;

		public GitgExt.Application? application { owned get; construct set; }
		public GitgExt.History? history { owned get; construct set; }

		private Gtk.ScrolledWindow d_sw;
		private Gitg.DiffView d_diff;
		private Gitg.WhenMapped d_whenMapped;

		construct
		{
			d_sw = new Gtk.ScrolledWindow(null, null);
			d_sw.show();

			d_diff = new Gitg.DiffView();
			d_diff.show();

			d_sw.add(d_diff);

			d_whenMapped = new Gitg.WhenMapped(d_sw);

			history.selection_changed.connect(on_selection_changed);
			on_selection_changed(history);
		}

		public string id
		{
			owned get { return "/org/gnome/gitg/Panels/Diff"; }
		}

		public bool available
		{
			get { return true; }
		}

		public string display_name
		{
			owned get { return _("Diff"); }
		}

		public string? icon
		{
			owned get { return "diff-symbolic"; }
		}

		private void on_selection_changed(GitgExt.History history)
		{
			history.foreach_selected((commit) => {
				var c = commit as Gitg.Commit;

				if (c != null)
				{
					d_whenMapped.update(() => {
						d_diff.commit = c;
					}, this);

					return false;
				}

				return true;
			});
		}

		public Gtk.Widget? widget
		{
			owned get { return d_sw; }
		}

		public bool enabled
		{
			get { return true; }
		}

		public int negotiate_order(GitgExt.UIElement other)
		{
			// Should appear before the files
			if (other.id == "/org/gnome/gitg/Panels/Files")
			{
				return -1;
			}
			else
			{
				return 0;
			}
		}
	}
}

[ModuleInit]
public void peas_register_types(TypeModule module)
{
	Peas.ObjectModule mod = module as Peas.ObjectModule;

	mod.register_extension_type(typeof(GitgExt.HistoryPanel),
	                            typeof(GitgDiff.Panel));
}

// ex: ts=4 noet
