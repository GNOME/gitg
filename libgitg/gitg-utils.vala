/*
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

public class Utils
{
	public static string replace_home_dir_with_tilde(File file)
	{
		var name = file.get_parse_name();
		var homedir = Environment.get_home_dir();

		if (homedir != null)
		{
			try
			{
				var hd = Filename.to_utf8(homedir, -1, null, null);

				if (hd == name)
				{
					name = "~/";
				}
				else
				{
					if (name.has_prefix(hd + "/"))
					{
						name = "~" + name[hd.length:name.length];
					}
				}
			} catch {}
		}

		return name;
	}

	public static string expand_home_dir(string path)
	{
		string? homedir = null;
		int pos = -1;

		if (path.has_prefix("~/"))
		{
			homedir = PlatformSupport.get_user_home_dir();
			pos = 1;
		}
		else if (path.has_prefix("~"))
		{
			pos = path.index_of_char('/');
			var user = path[1:pos];

			homedir = PlatformSupport.get_user_home_dir(user);
		}

		if (homedir != null)
		{
			return Path.build_filename(homedir, path.substring(pos + 1));
		}

		return path;
	}

	public static bool gitg_styles_path_added = false;

	public static Gtk.SourceStyleSchemeManager get_source_style_manager()
	{
		var style_manager = Gtk.SourceStyleSchemeManager.get_default();
		if (gitg_styles_path_added)
		{
			style_manager.append_search_path(Path.build_filename (PlatformSupport.get_data_dir(), "styles"));
			style_manager.force_rescan();
			gitg_styles_path_added = true;
		}
		return style_manager;
	}

	public static void update_style_value(Settings? settings, string to, string from)
	{
		var style = settings.get_string("style-scheme");
		if (style.has_suffix(to))
			return;
		var manager = Gitg.Utils.get_source_style_manager();
		var style_prefix = style;
		if (style.has_suffix(from)) {
			style_prefix = style.substring(0, style_prefix.length-6);
			if (manager.get_scheme(style_prefix) != null) {
				settings.set_string("style-scheme", style_prefix);
				return;
			}
		}
		var new_style = style_prefix+to;
		if (manager.get_scheme(new_style) != null) {
			settings.set_string("style-scheme", new_style);
		}
	}

	public static Gee.HashMap<string, string>? theme_light_dark;

	public static void update_style_by_theme(Settings? settings)
	{
		if (theme_light_dark == null)
		{
			theme_light_dark = new Gee.HashMap<string, string>();
			var m = theme_light_dark;
			m.set("adwaita", "adwaita-dark");
			m.set("classic", "classic-dark");
			m.set("solarized-light", "solarized-dark");
			m.set("tango", "oblivion");
			m.set("kate", "kate-dark");
			m.set("cobalt-light", "cobalt");
		}

		var dark = Hdy.StyleManager.get_default ().dark;
		var scheme = settings.get_string("style-scheme");
		if (dark) {
			if (theme_light_dark.has_key(scheme)) {
				settings.set_string("style-scheme", theme_light_dark.get(scheme));
			} else {
				update_style_value(settings, "-dark", "light");
			}
		} else {
			bool set_style = false;
			foreach (string k in theme_light_dark.keys) {
				if (theme_light_dark.get (k) == scheme) {
					settings.set_string("style-scheme", k);
					set_style = true;
					break;
				}
			}
			if (!set_style)
				update_style_value(settings, "-light", "-dark");
		}
	}

	public static void update_buffer_style(Settings settings, Gtk.SourceBuffer source_buffer)
	{
		var scheme = settings.get_string("style-scheme");
		var manager = Gitg.Utils.get_source_style_manager();
		var s = manager.get_scheme(scheme);

		if (s != null)
		{
			source_buffer.style_scheme = s;
		}
	}

	public delegate Gtk.Dialog BuildDialog(Gee.HashMap<string, string> dialog_vars, string? stdout_data, string? stderr_data);
	public delegate Gtk.MenuItem BuildMenuItem(string action_prefix, Gee.HashMap<string, Gtk.MenuItem> item_groups);

	public static void add_custom_actions(Gtk.Menu menu,
	                                      string type,
	                                      Ggit.Config config,
	                                      Regex regex_custom_actions,
	                                      Regex regex_custom_actions_group,
	                                      BuildMenuItem build_menu_item)
	{
		menu.set_data("items", 0);
		try
		{
			var item_groups = new Gee.HashMap<string, Gtk.MenuItem> ();
			config.match_foreach(regex_custom_actions_group, (match_info, val) => {
				if (!item_groups.contains(val)) {
					var item_group = new Gtk.MenuItem.with_label(val);
					item_groups.set(val, item_group);
				}
				return 0;
			});
			config.match_foreach(regex_custom_actions, (match_info, val) => {
				string group = match_info.fetch(1);
				debug ("found custom action group: %s", group);
				string custom_link_regexp = val;
				debug ("found custom action value: %s", val);
				string action_key_prefix = "gitg.actions.%s.%s.".printf(type, group);
				try
				{
					var item = build_menu_item(action_key_prefix, item_groups);
					if (item != null) {
						item.show();
						menu.append(item);
						int items = menu.get_data<int>("items");
						menu.set_data("items", ++items);
					}
				} catch (Error e)
				{
					warning ("Cannot read git config: %s", e.message);
				}
				return 0;
			});

			foreach (var item in item_groups.values) {
				if (item.get_data<int>("items") > 0) {
					menu.append(item);
					int items = menu.get_data<int>("items");
					menu.set_data("items", ++items);
					item.show();
				}
			}
		} catch (Error e)
		{
			warning ("Cannot read git config: %s", e.message);
		}
	}

	public static string? render_template(string tmpl,
	                                     Gee.HashMap<string,string> object_vars,
	                                     Gee.HashMap<string,string> dialog_vars) {
		string result = tmpl;
		foreach (var k in object_vars.keys) {
			var placeholder = "${" + k + "}";
			var val = object_vars.get(k);
			if (val == null)
				continue;
			var tmp = result.replace (placeholder, val);
			if (tmp != null)
				result = tmp;
			placeholder = "$" + k;
			tmp = result.replace (placeholder, val);
			if (tmp != null)
				result = tmp;
		}
		var placeholder = "$input";
		if (result.contains(placeholder)) {
			var replacement = run_entry_dialog(null, dialog_vars);
			if (replacement != null) {
				var tmp = result.replace (placeholder, replacement);
				if (tmp != null)
					result = tmp;
			} else
				result = null;
		}
		placeholder = "$question";
		if (result.contains(placeholder)) {
			var replacement = run_question_dialog(null, dialog_vars);
			if (replacement != null) {
				var tmp = result.replace (placeholder, replacement);
				if (tmp != null)
					result = tmp;
			} else
				result = null;
		}
		return result;
	}

	private static string? get_config_string(Ggit.Config conf, string key, string? def) {
		string val;
		try {
			val = conf.get_string(key);
		} catch {
			val = def;
		}
		return val;
	}

	private static bool get_config_bool(Ggit.Config conf, string key, bool def) {
		bool val;
		try {
			val = conf.get_bool(key);
		} catch {
			val = def;
		}
		return val;
	}

	private static void add_from_config(Gee.HashMap<string,string> input_vars,
	                                    Ggit.Config config, string prefix, string key, string? def) {
		input_vars.set(key, get_config_string(config, prefix+key, def));
	}

	public delegate Gee.HashMap<string, string> BuildObjectVars();

	public static Gtk.MenuItem build_custom_action(Ggit.Config conf,
	                                               string action_key_prefix,
	                                               Gee.HashMap<string, Gtk.MenuItem> groups,
												   BuildDialog build_dialog,
												   BuildObjectVars build_object_vars = null)
	{
		string name = get_config_string(conf, action_key_prefix+"name", "");
		string description = get_config_string(conf, action_key_prefix+"description", "");
		string command = get_config_string(conf, action_key_prefix+"command", "");
		string available = get_config_string(conf, action_key_prefix+"available", "");
		string enabled = get_config_string(conf, action_key_prefix+"enabled", "");
		bool show_output = get_config_bool(conf, action_key_prefix+"show-output", false);
		bool show_error = get_config_bool(conf, action_key_prefix+"show-error", true);

		var dialog_vars = new Gee.HashMap<string,string> ();
		add_from_config(dialog_vars, conf, action_key_prefix, "dialog-title", _("Output"));
		add_from_config(dialog_vars, conf, action_key_prefix, "dialog-label", _("Results:"));
		add_from_config(dialog_vars, conf, action_key_prefix, "input-title", _("Input"));
		add_from_config(dialog_vars, conf, action_key_prefix, "input-label", _("Value:"));
		add_from_config(dialog_vars, conf, action_key_prefix, "input-placeholder", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "input-text", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "input-yes", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "input-no", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "question-title", _("Question"));
		add_from_config(dialog_vars, conf, action_key_prefix, "question-message", _("Are you sure?"));
		add_from_config(dialog_vars, conf, action_key_prefix, "question-yes", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "question-no", null);
		add_from_config(dialog_vars, conf, action_key_prefix, "question-level", null);

		var object_vars = new Gee.HashMap<string, string>();
		if (build_object_vars != null) {
			object_vars = build_object_vars();
		}

		try {
			var available_flag = conf.get_bool(action_key_prefix+"available");
			if (!available_flag)
				return null;
		} catch {}
		if (available != "") {
			var available_command = render_template (available, object_vars, dialog_vars);
			if (available_command == null)
				return null;

			int exit_status;
			string stdout_data, stderr_data;
			bool spawned = GLib.Process.spawn_command_line_sync (available_command,
			                                                     out stdout_data,
			                                                     out stderr_data,
			                                                     out exit_status);
			if (!spawned) {
				stderr.printf ("Failed to check available action %s\n: %s\n", name, stderr_data);
				return null;
			}

			if (exit_status != 0)
				return null;
		} else {
			bool available_flag = false;
			try {
				available_flag = conf.get_bool(action_key_prefix+"available");
			} catch {}
			if (!available_flag)
				return null;
		}

		var item = new Gtk.MenuItem.with_label(name);

		bool enabled_is_flag = false;
		try {
			var enabled_flag = conf.get_bool(action_key_prefix+"enabled");
			if (!enabled_flag)
				item.sensitive = false;
			enabled_is_flag = true;
		} catch {}
		if (!enabled_is_flag && enabled != "") {
			var enabled_command = render_template (enabled, object_vars, dialog_vars);
			if (enabled_command == null)
				item.sensitive = false;
			else {
				int exit_status;
				string stdout_data, stderr_data;
				bool spawned = GLib.Process.spawn_command_line_sync (enabled_command,
				                                                out stdout_data,
				                                                out stderr_data,
				                                                out exit_status);
				if (!spawned) {
					stderr.printf ("Failed to check enabled action %s\n: %s\n", name, stderr_data);
					item.sensitive = false;
				} else if (exit_status != 0)
					item.sensitive = false;
			}
		}

		var item_result = item;

		try {
			var group = conf.get_string(action_key_prefix+"group");
			var item_group = groups.get(group);
			Gtk.Menu submenu;
			if (item_group.submenu != null)
				submenu = item_group.submenu;
			else {
				submenu = new Gtk.Menu();
				item_group.submenu = submenu;
				item_group.set_data("items", 0);
			}
			submenu.add(item);
			int items = item_group.get_data<int>("items");
			item_group.set_data("items", ++items);
			item.show();
			item_result = null;
		} catch {}

		item.set_tooltip_text(description);

		item.activate.connect(() => {
			var cmd = render_template (command, object_vars, dialog_vars);
			if (cmd == null)
				return;

			int exit_status;
			string stdout_data, stderr_data;

			bool spawned = GLib.Process.spawn_command_line_sync (cmd,
			                                                out stdout_data,
			                                                out stderr_data,
			                                                out exit_status);
			if (!spawned) {
				stderr.printf ("Failed to start command: %s\n", stderr_data);
				return;
			}

			if (show_output && stdout_data != null) {
				stdout.printf (stdout_data);
				var dlg = build_dialog(dialog_vars, stdout_data, null);
				dlg.show();
			}

			if (exit_status != 0 && show_error) {
				stdout.printf (stdout_data);
				stdout.printf (stderr_data);

				var dlg = build_dialog(dialog_vars, stdout_data, stderr_data);
				dlg.show();
			}
		});

		return item_result;
	}

	public static string? get (Gee.HashMap<string, string> map, string key, string? def) {
		bool has_key_not_null = map.has_key (key) && map.get(key) != null;
		return has_key_not_null ? map.get(key) : def;
	}

	public static string? run_question_dialog (Gtk.Window? parent,
	                                        Gee.HashMap<string,string> vars) {
		var title = get(vars, "question-title", _("Input"));
		var message = get(vars, "question-message", "");
		var level = get(vars, "question-level", "info");
		var cancel = get(vars, "question-no", _("Cancel"));
		var yes = get(vars, "question-yes", _("Ok"));
		Gtk.MessageType type;
		string icon_name;
		switch(level) {
			case "info":
				type = Gtk.MessageType.INFO;
				icon_name = "dialog-information-symbolic";
				break;
			case "warning":
				type = Gtk.MessageType.WARNING;
				icon_name = "dialog-warning-symbolic";
				break;
			case "error":
				type = Gtk.MessageType.ERROR;
				icon_name = "dialog-error-symbolic";
				break;
			case "other":
				type = Gtk.MessageType.OTHER;
				icon_name = "dialog-question-symbolic";
				break;
			default:
				type = Gtk.MessageType.INFO;
				icon_name = "dialog-information-symbolic";
				break;
		}
		var dialog = new Gtk.MessageDialog (parent,
		                                    Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
		                                    type, Gtk.ButtonsType.OK_CANCEL, message);

		var img = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.DIALOG);
		dialog.set_image (img);

		dialog.set_default_size (360, 120);
		dialog.set_resizable (false);

		dialog.show_all ();

		int response = dialog.run ();
		string? result = null;
		if (response == (int) Gtk.ResponseType.OK) {
			result = "";
		}

		dialog.destroy ();
		return result;
	}

	public static string? run_entry_dialog (Gtk.Window? parent,
	                                        Gee.HashMap<string,string> vars) {
		var title = get(vars, "input-title", _("Input"));
		var cancel = get(vars, "input-no", _("Cancel"));
		var yes = get(vars, "input-yes", _("Ok"));
		var label_text = get(vars, "input-label", _("Value"));
		var placeholder_text = get(vars, "input-placeholder", null);
		var force_show_placeholder = bool.parse(get(vars, "input-force-show-placeholder", "false"));
		var initial_text = get(vars, "input-text", null);

		var dialog = new Gtk.Dialog.with_buttons (
			title,
			parent,
			Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT |
			Gtk.DialogFlags.USE_HEADER_BAR,
			cancel, Gtk.ResponseType.CANCEL,
			yes, Gtk.ResponseType.OK
		);
		dialog.set_default_size (360, 120);
		dialog.set_resizable (false);

		var content = dialog.get_content_area ();
		var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		box.set_margin_top (12);
		box.set_margin_bottom (12);
		box.set_margin_start (12);
		box.set_margin_end (12);
		content.pack_start (box, true, true, 0);

		var lbl = new Gtk.Label (label_text);
		lbl.set_halign (Gtk.Align.START);
		box.pack_start (lbl, false, false, 0);

		var entry = new Gtk.Entry ();
		if (placeholder_text != null) {
			entry.set_placeholder_text (placeholder_text);
			if (force_show_placeholder)
				entry.set_can_focus(false);
		}
		if (initial_text != null)
			entry.set_text (initial_text);
		entry.set_activates_default (true);
		box.pack_start (entry, false, false, 0);

		var ok_button = dialog.get_widget_for_response (Gtk.ResponseType.OK) as Gtk.Button;
		if (ok_button != null) {
			dialog.set_default_response (Gtk.ResponseType.OK);
			ok_button.set_sensitive (entry.text.strip().length > 0);
		}

		entry.changed.connect (() => {
			if (ok_button != null)
				ok_button.set_sensitive (entry.text.strip().length > 0);
		});

		dialog.show_all ();

		if (force_show_placeholder &&  placeholder_text != null) {
			GLib.Idle.add (() => {
				entry.set_can_focus (true);
				return false;
			});
		}

		int response = dialog.run ();
		string? result = null;
		if (response == (int) Gtk.ResponseType.OK) {
			result = entry.get_text ();
		}

		dialog.destroy ();
		return result;
	}
}
}

// ex:ts=4 noet
