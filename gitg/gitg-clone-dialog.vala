/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Ignacio Casal Quinteiro
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-clone-dialog.ui")]
public class CloneDialog : Gtk.Dialog
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild (name = "entry_url")]
	private unowned Gtk.Entry d_entry_url;

	[GtkChild (name = "button_location")]
	private unowned Gtk.Button d_button_location;
	
	[GtkChild (name = "bare_repository")]
	private unowned Gtk.CheckButton d_bare_repository;

	private File? d_location = null;

	public bool is_bare
	{
		get { return d_bare_repository.active; }
	}

	public File? location
	{
		owned get { return d_location; }
	}

	public string url
	{
		get { return d_entry_url.get_text(); }
	}

	public CloneDialog(Gtk.Window? parent)
	{
		Object(use_header_bar: 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
	}

	construct
	{
		var main_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.main");

		set_default_response(Gtk.ResponseType.OK);

		var default_dir = main_settings.get_string("clone-directory");
		if (default_dir == "")
		{
			default_dir = Environment.get_home_dir();
		}

		d_location = File.new_for_path (default_dir);
		d_button_location.label = Path.get_basename (default_dir);
		d_button_location.tooltip_text = default_dir;
		d_button_location.clicked.connect(() => {
		var dialog = new Gtk.FileDialog();
		dialog.title = _("Select Clone Location");
		dialog.initial_folder = d_location;

		dialog.select_folder.begin(this as Gtk.Window, null, (obj, res) => {
			try
			{
				var folder = dialog.select_folder.end(res);
				d_location = folder;
				d_button_location.label = Path.get_basename(folder.get_path());
				d_button_location.tooltip_text = folder.get_path();
				main_settings.set_string("clone-directory", folder.get_path());
			}
			catch (Error e)
			{
			}
		});
	});

		d_entry_url.changed.connect((e) => {
			string ?tooltip_text = null;
			string ?icon_name = null;

			var is_valid = (d_entry_url.text != "");

			if (!is_valid)
			{
				icon_name = "dialog-warning-symbolic";
				tooltip_text = _("The URL introduced is not supported");
			}

			d_entry_url.set_icon_from_icon_name(Gtk.EntryIconPosition.SECONDARY, icon_name);
			d_entry_url.set_icon_tooltip_text(Gtk.EntryIconPosition.SECONDARY, tooltip_text);

			set_response_sensitive(Gtk.ResponseType.OK, is_valid);
		});
	}
}

}

// ex:ts=4 noet
