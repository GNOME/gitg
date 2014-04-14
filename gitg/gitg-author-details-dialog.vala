/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Sindhu S
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
	[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-author-details-dialog.ui")]
	public class AuthorDetailsDialog : Gtk.Dialog
	{
		//Do this to pull in config.h before glib.h (for gettext)
		private const string version = Gitg.Config.VERSION;

		[GtkChild (name = "input_name")]
		private Gtk.Entry d_input_name;

		[GtkChild (name = "input_email")]
		private Gtk.Entry d_input_email;

		[GtkChild (name = "label_view")]
		private Gtk.Label d_label_view;

		[GtkChild (name = "label_dash")]
		private Gtk.Label d_label_dash;

		private string? d_repository_name;

		private Ggit.Config d_config;

		public AuthorDetailsDialog (Gtk.Window? parent, Ggit.Config config, string? repository_name)
		{
			Object (use_header_bar: 1);

			if (parent != null)
			{
				set_transient_for (parent);
			}

			d_repository_name = repository_name;
			d_config = config;
		}

		public override void show()
		{
			base.show();
			if (d_repository_name == null)
			{
				d_label_view.hide();
				d_label_dash.show();

				if (Ggit.Config.find_global().get_path() == null)
				{
					show_config_error(_("Unable to open the .gitconfig file."), "");
					return;
				}
			}
			else
			{
				d_label_view.label = d_label_view.label.printf(d_repository_name);

				d_label_view.show();
				d_label_dash.hide();
			}

			string author_name = "";
			string author_email = "";

			try
			{
				d_config.refresh();
				author_name = d_config.get_string("user.name");
			}
			catch {}

			try
			{
				author_email = d_config.get_string("user.email");
			}
			catch {}

			if (author_name != "")
			{
				d_input_name.set_text(author_name);
			}

			if (author_email != "")
			{
				d_input_email.set_text(author_email);
			}

			set_response_sensitive(Gtk.ResponseType.OK, false);

			d_input_name.activate.connect((e) => {
				response(Gtk.ResponseType.OK);
			});
			
			d_input_email.activate.connect((e) => {
				response(Gtk.ResponseType.OK);
			});

			d_input_name.changed.connect((e) => {
				set_response_sensitive(Gtk.ResponseType.OK, true);
			});

			d_input_email.changed.connect((e) => {
				set_response_sensitive(Gtk.ResponseType.OK, true);
			});
		}

		public override void response(int id) {
			if (id == Gtk.ResponseType.OK)
			{
				try
				{
					if (d_input_name.get_text() == "")
					{
						d_config.delete_entry("user.name");
					}
					else
					{
						d_config.set_string("user.name", d_input_name.get_text());
					}

					if (d_input_email.get_text() == "")
					{
						d_config.delete_entry("user.email");
					}
					else
					{
						d_config.set_string("user.email", d_input_email.get_text());
					}
				}
				catch (Error e)
				{
					show_config_error(_("Failed to set Git user config."), e.message);
					destroy();
					return;
				}
			}

			destroy();
		}

		private void show_config_error(string primary_message, string secondary_message)
		{
			var error_dialog = new Gtk.MessageDialog(this,
			                                         Gtk.DialogFlags.DESTROY_WITH_PARENT,
			                                         Gtk.MessageType.ERROR,
			                                         Gtk.ButtonsType.OK,
			                                         primary_message);

			error_dialog.secondary_text = secondary_message;
			error_dialog.response.connect((d, id) => {
				error_dialog.destroy();
			});

			error_dialog.show();
		}
	}
}