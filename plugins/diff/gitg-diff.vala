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

		private Gitg.DiffView d_diff;
		private Gitg.WhenMapped d_whenMapped;

		private ulong d_selection_changed_id;

		public virtual uint? shortcut
		{
			owned get { return Gdk.Key.d; }
		}

		protected override void constructed()
		{
			base.constructed();

			d_diff = new Gitg.DiffView();

			d_diff.show_parents = true;

			application.bind_property("repository", d_diff, "repository", BindingFlags.SYNC_CREATE);

			d_diff.show();

			var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.diff");

			settings.bind("ignore-whitespace",
			              d_diff,
			              "ignore-whitespace",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("changes-inline",
			              d_diff,
			              "changes-inline",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("context-lines",
			              d_diff,
			              "context-lines",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("tab-width",
			              d_diff,
			              "tab-width",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("wrap",
			              d_diff,
			              "wrap-lines",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

			settings.bind("use-gravatar",
			              d_diff,
			              "use-gravatar",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			settings.bind("enable-diff-highlighting",
			              d_diff,
			              "highlight",
			              SettingsBindFlags.GET | SettingsBindFlags.SET);

			d_whenMapped = new Gitg.WhenMapped(d_diff);

			d_selection_changed_id = history.selection_changed.connect(on_selection_changed);
			on_selection_changed(history);
		}

		protected override void dispose()
		{
			if (history != null && d_selection_changed_id != 0)
			{
				history.disconnect(d_selection_changed_id);
				d_selection_changed_id = 0;
			}

			base.dispose();
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

		public string description
		{
			owned get { return _("Show the changes introduced by the selected commit"); }
		}

		public string? icon
		{
			owned get { return "diff-symbolic"; }
		}

		private void on_selection_changed(GitgExt.History history)
		{
			var hasset = false;

			history.foreach_selected((commit) => {
				var c = commit as Gitg.Commit;

				if (c != null)
				{
					d_whenMapped.update(() => {
						d_diff.commit = c;
						hasset = true;
					}, this);

					return false;
				}

				return true;
			});

			if (!hasset)
			{
				d_diff.commit = null;
			}
		}

		public Gtk.Widget? widget
		{
			owned get { return d_diff; }
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
