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

namespace GitgExt
{

public interface Action : UIElement
{
	public virtual void populate_menu(Gtk.Menu menu)
	{
		if (!available)
		{
			return;
		}

		var item = new Gtk.MenuItem.with_label(display_name);
		item.tooltip_text = description;

		if (enabled)
		{
			item.activate.connect(() => {
				activate();
			});
		}
		else
		{
			item.sensitive = false;
		}

		item.show();
		menu.append(item);
	}

	public virtual async bool fetch(){
		return true;
	}
}

}

// ex: ts=4 noet
