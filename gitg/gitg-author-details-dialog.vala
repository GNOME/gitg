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

		private const string USER_NAME_PROP = "user.name";
		private const string USER_EMAIL_PROP = "user.email";

		[GtkChild (name = "entry_name")]
		private unowned Gtk.Entry d_entry_name;

		[GtkChild (name = "entry_email")]
		private unowned Gtk.Entry d_entry_email;

		[GtkChild (name = "label_info")]
		private unowned Gtk.Label d_label_info;

		[GtkChild (name = "checkbutton_override_global")]
		private unowned Gtk.CheckButton d_checkbutton_override_global;

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

		public static AuthorDetailsDialog? show_global(Window window)
		{
			Ggit.Config? global_config;

			try
			{
				global_config = new Ggit.Config.default();
			}
			catch (Error e)
			{
				warning("Error while loading config file: %s", e.message);
				return null;
			}

			var author_details = new AuthorDetailsDialog(window, global_config, null);
			author_details.show();

			return author_details;
		}

		private void build_global()
		{
			title = _("Author Details");
			d_label_info.label = _("Enter default details used for all repositories:");
			d_label_info.show();
		}

		private bool config_is_local(string name)
		{
			try
			{
				var entry = d_config.get_entry(name);
				return entry.get_level() == Ggit.ConfigLevel.LOCAL;
			}
			catch
			{
				return false;
			}
		}

		private void build_repository()
		{
			title = "%s — %s".printf(d_repository_name, _("Author Details"));

			// Translators: %s is the repository name
			d_checkbutton_override_global.label = _("Override global details for repository “%s”:").printf(d_repository_name);
			d_checkbutton_override_global.active = (config_is_local(USER_NAME_PROP) || config_is_local(USER_EMAIL_PROP));

			d_checkbutton_override_global.notify["active"].connect(update_sensitivity);
			d_checkbutton_override_global.show();

			update_sensitivity();
		}

		private void update_sensitivity()
		{
			d_entry_name.sensitive = d_checkbutton_override_global.active;
			d_entry_email.sensitive = d_checkbutton_override_global.active;

			Ggit.Config? config = null;

			try
			{
				if (!d_checkbutton_override_global.active)
				{
					config = d_config.open_level(Ggit.ConfigLevel.GLOBAL);
				}
				else
				{
					config = d_config;
				}
			} catch {}

			if (config != null)
			{
				update_entries(config);
			}
		}

		public override void show()
		{
			base.show();

			if (d_repository_name == null)
			{
				build_global();
			}
			else
			{
				build_repository();
			}

			update_entries(d_config);
		}

		private string read_config_string(Ggit.Config config, string name, string defval = "")
		{
			string? ret = null;

			try
			{
				ret = config.snapshot().get_string(name);
			} catch {}

			return ret != null ? ret : defval;
		}

		private void update_entries(Ggit.Config config)
		{
			d_entry_name.set_text(read_config_string(config, USER_NAME_PROP).strip());
			d_entry_email.set_text(read_config_string(config, USER_EMAIL_PROP).strip());
		}

		private void delete_local_entry(string name) {
			try {
				if (d_config.get_entry(name).get_level() == Ggit.ConfigLevel.LOCAL) {
					d_config.delete_entry(name);
				}
			} catch {}
		}

		private void set_property(string name, string value) {
			bool empty_value = value == null || value.strip().length == 0;
			if (empty_value) {
				d_config.delete_entry(name);
			} else {
				d_config.set_string(name, value.strip());
			}
		}

		private bool exists_local_property(string name) {
			var config = d_config.open_level(Ggit.ConfigLevel.LOCAL);
			string value = read_config_string(config, name);
			return value != null && value.strip().length != 0;
		}

		public override void response(int id) {
			bool destroy_dialog = true;
			if (id == Gtk.ResponseType.OK) {
				try {
					if (d_repository_name != null) {
						if (d_checkbutton_override_global.active) {
							set_property(USER_NAME_PROP, d_entry_name.get_text());
							set_property(USER_EMAIL_PROP, d_entry_email.get_text());
						} else {
							if (exists_local_property(USER_NAME_PROP) || exists_local_property(USER_EMAIL_PROP)) {
								var alert_dialog = new Gtk.MessageDialog (this, Gtk.DialogFlags.MODAL, Gtk.MessageType.WARNING,
								                                          Gtk.ButtonsType.OK_CANCEL,
								                                          _("Disable override will clean existing local author details. Are you sure?"));
								alert_dialog.response.connect ((id) => {
									if (id == Gtk.ResponseType.OK) {
										delete_local_entry(USER_NAME_PROP);
										delete_local_entry(USER_EMAIL_PROP);
									} else {
										destroy_dialog = false;
									}
									alert_dialog.destroy();
								});

								alert_dialog.run();
							}
						}
					} else {
						set_property(USER_NAME_PROP, d_entry_name.get_text());
						set_property(USER_EMAIL_PROP, d_entry_email.get_text());
					}
				}
				catch (Error e) {
					show_config_error(_("Failed to set Git user config."), e.message);
					destroy();
					return;
				}
			}

			if(destroy_dialog) {
				destroy();
			}
		}

		private void show_config_error(string primary_message, string secondary_message)
		{
			var error_dialog = new Gtk.MessageDialog(this,
			                                         Gtk.DialogFlags.DESTROY_WITH_PARENT,
			                                         Gtk.MessageType.ERROR,
			                                         Gtk.ButtonsType.OK,
			                                         "%s",
			                                         primary_message);

			error_dialog.secondary_text = secondary_message;
			error_dialog.response.connect((d, id) => {
				error_dialog.destroy();
			});

			error_dialog.show();
		}
	}
}

// vi:ts=4
