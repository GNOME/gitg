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

		[GtkChild (name = "entry_name")]
		private Gtk.Entry d_entry_name;

		[GtkChild (name = "entry_email")]
		private Gtk.Entry d_entry_email;

		[GtkChild (name = "label_info")]
		private Gtk.Label d_label_info;

		[GtkChild (name = "checkbutton_override_global")]
		private Gtk.CheckButton d_checkbutton_override_global;

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
			var xdg_config_path = Path.build_filename(Environment.get_user_config_dir(), "git", "config");
			var config_path = Path.build_filename(Environment.get_home_dir(), ".gitconfig");

			// If neither exists yet, create default empty one
			if (!FileUtils.test(xdg_config_path, FileTest.EXISTS) && !FileUtils.test(config_path, FileTest.EXISTS))
			{
				try
				{
					FileUtils.set_contents(config_path, "");
				} catch {}
			}

			var global_config_file = Ggit.Config.find_global();

			if (global_config_file == null)
			{
				return null;
			}

			Ggit.Config? global_config;

			try
			{
				global_config = new Ggit.Config.from_file(global_config_file);
			}
			catch
			{
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
			d_checkbutton_override_global.active = (config_is_local("user.name") || config_is_local("user.email"));

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
			d_entry_name.set_text(read_config_string(config, "user.name").chomp());
			d_entry_email.set_text(read_config_string(config, "user.email").chomp());
		}

		private void delete_local_entries()
		{
			try
			{
				if (d_config.get_entry("user.name").get_level() == Ggit.ConfigLevel.LOCAL)
				{
					d_config.delete_entry("user.name");
				}
			} catch {}

			try
			{
				if (d_config.get_entry("user.email").get_level() == Ggit.ConfigLevel.LOCAL)
				{
					d_config.delete_entry("user.email");
				}
			} catch {}
		}

		public override void response(int id) {
			if (id == Gtk.ResponseType.OK)
			{
				try
				{
					if (d_repository_name != null)
					{
						if (d_checkbutton_override_global.active)
						{
							d_config.set_string("user.name", d_entry_name.get_text());
							d_config.set_string("user.email", d_entry_email.get_text());
						}
						else
						{
							delete_local_entries();
						}
					}
					else
					{
						d_config.set_string("user.name", d_entry_name.get_text());
						d_config.set_string("user.email", d_entry_email.get_text());
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

/* vi:ts=4 */
