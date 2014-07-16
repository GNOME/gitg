/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

namespace Gitg
{

class DashView : RepositoryListBox, GitgExt.UIElement, GitgExt.Activity, GitgExt.Selectable, GitgExt.Searchable
{
	private const string version = Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }

	private bool d_search_enabled;
	private bool d_setting_mode;

	[Notify]
	public GitgExt.SelectionMode selectable_mode
	{
		get
		{
			switch (mode)
			{
			case Gitg.SelectionMode.NORMAL:
				return GitgExt.SelectionMode.NORMAL;
			case Gitg.SelectionMode.SELECTION:
				return GitgExt.SelectionMode.SELECTION;
			}

			return GitgExt.SelectionMode.NORMAL;
		}

		set
		{
			if (selectable_mode == value)
			{
				return;
			}

			d_setting_mode = true;

			switch (value)
			{
			case GitgExt.SelectionMode.NORMAL:
				mode = Gitg.SelectionMode.NORMAL;
				break;
			case GitgExt.SelectionMode.SELECTION:
				mode = Gitg.SelectionMode.SELECTION;
				break;
			}

			d_setting_mode = false;
		}
	}

	public string display_name
	{
		owned get { return "Dash"; }
	}

	public string description
	{
		owned get { return "Dash view"; }
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/dash"; }
	}

	public Gtk.Widget? widget
	{
		owned get { return this; }
	}

	public string? icon
	{
		owned get { return null; }
	}

	private string d_search_text;

	public string search_text
	{
		owned get { return d_search_text; }

		set
		{
			if (d_search_text != value)
			{
				d_search_text = value;
				filter_text(d_search_text);
			}
		}
	}

	public bool search_visible { get; set; }

	public bool search_enabled
	{
		get { return d_search_enabled; }
		set
		{
			if (d_search_enabled != value)
			{
				d_search_enabled = value;

				if (d_search_enabled)
				{
					filter_text(d_search_text);
				}
				else
				{
					filter_text(null);
				}
			}
		}
	}

	public Gtk.Widget? action_widget
	{
		owned get
		{
			var ab = new Gtk.ActionBar();

			var del = new Gtk.Button.with_mnemonic(_("_Delete"));

			del.sensitive = false;
			del.show();

			del.clicked.connect(() => {
				foreach (var sel in selection)
				{
					sel.request_remove();
				}

				selectable_mode = GitgExt.SelectionMode.NORMAL;
			});

			bind_property("has-selection", del, "sensitive");

			ab.pack_end(del);

			return ab;

		}
	}

	construct
	{
		d_search_text = "";

		notify["mode"].connect(() => {
			if (!d_setting_mode)
			{
				notify_property("selectable-mode");
			}
		});
	}
}

}

// ex:ts=4 noet
