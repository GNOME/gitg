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

namespace Gitg
{

class PreferencesDialog : Gtk.Dialog, Gtk.Buildable
{
	private Gtk.Notebook d_notebook;

	private void parser_finished(Gtk.Builder builder)
	{
		// Extract widgets from the builder
		d_notebook = builder.get_object("notebook_elements") as Gtk.Notebook;

		// Populate tabs from plugins
		populate();

		base.parser_finished(builder);
	}

	private void add_page(GitgExt.Preferences pref, HashTable<string, Gtk.Box> pages)
	{
		Gtk.Box page;

		if (!pages.lookup_extended(pref.id, null, out page))
		{
			page = new Gtk.Box(Gtk.Orientation.VERTICAL, 6);

			page.show();
			pages.insert(pref.id, page);

			var lbl = new Gtk.Label(pref.display_name);
			lbl.show();

			d_notebook.append_page(page, lbl);
		}

		page.add(pref.widget);

		d_notebook.child_set_property (page, "tab-expand", true);
	}

	public void populate()
	{
		var engine = PluginsEngine.get_default();
		var ext = new Peas.ExtensionSet(engine, typeof(GitgExt.Preferences));

		var pages = new HashTable<string, Gtk.Box>(str_hash, str_equal);

		add_page(new PreferencesInterface(), pages);
		add_page(new PreferencesHistory(), pages);
		add_page(new PreferencesCommit(), pages);

		ext.foreach((s, info, e) => {
			add_page(e as GitgExt.Preferences, pages);
		});
	}
}

}

// vi:ts=4
