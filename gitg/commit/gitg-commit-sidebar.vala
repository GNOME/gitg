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

namespace GitgCommit
{

class Sidebar : Gitg.Sidebar
{
	[Signal(action = true)]
	public signal void stage_selection();

	[Signal(action = true)]
	public signal void unstage_selection();

	[Signal(action = true)]
	public signal void discard_selection();

	construct
	{
		unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class(get_class());

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.s,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "stage-selection",
		                            0);

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.u,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "unstage-selection",
		                            0);

		Gtk.BindingEntry.add_signal(binding_set,
		                            Gdk.Key.d,
		                            Gdk.ModifierType.CONTROL_MASK,
		                            "discard-selection",
		                            0);
	}
}

}

// ex: ts=4 noet
