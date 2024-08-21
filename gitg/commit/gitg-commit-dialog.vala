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

namespace GitgCommit
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-dialog.ui")]
class Dialog : Gtk.Dialog
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private const string VERSION_PROP = "version";
	private const string DESCRIPTION_PROP = "version";
	private const string MESSAGES_PROP = "messages";
	private const string DATETIME_PROP = "datetime";
	private const string TEXT_PROP = "text";
	private const string COMMIT_MESSAGE_FILENAME = "commit-messages.json";

	private const string PREPARE_COMMIT_MSG_FILENAME = "prepare-commit-msg";
	private const string PREPARE_COMMIT_MSG_SOURCE_COMMIT = "commit";
	private const string PREPARE_COMMIT_MSG_SOURCE_MERGE = "merge";
	private const string PREPARE_COMMIT_MSG_SOURCE_TEMPLATE = "template";
	private const string PREPARE_COMMIT_MSG_SOURCE_SQUASH = "squash";

	private const string COMMIT_MSG_FILENAME = "COMMIT_EDITMSG";
	private const string SQUASH_MSG_FILENAME = "SQUASH_MSG";
	private const string MERGE_MSG_FILENAME = "MERGE_MSG";

	private const string CONFIG_COMMIT_TEMPLATE = "commit.template";
	private const string CONFIG_HOOKS_PATH = "core.hooksPath";

	[GtkChild (name = "source_view_message")]
	private unowned Gtk.SourceView d_source_view_message;

	[GtkChild (name = "ok-button")]
	private unowned Gtk.Button d_button_ok;

	[GtkChild (name = "check_button_amend")]
	private unowned Gtk.CheckButton d_check_button_amend;

	[GtkChild (name = "check_button_sign_off")]
	private unowned Gtk.CheckButton d_check_button_sign_off;

	[GtkChild (name = "check_button_sign_commit")]
	private Gtk.CheckButton d_check_button_sign_commit;

	[GtkChild (name = "image_avatar")]
	private unowned Gtk.Image d_image_avatar;

	[GtkChild (name = "label_user")]
	private unowned Gtk.Label d_label_user;

	[GtkChild (name = "label_date")]
	private unowned Gtk.Label d_label_date;

	[GtkChild (name = "infobar")]
	private unowned Gtk.InfoBar d_infobar;

	[GtkChild (name = "infobar_revealer")]
	private unowned Gtk.Revealer d_infobar_revealer;

	[GtkChild (name = "infobar_primary_label")]
	private unowned Gtk.Label d_infobar_primary_label;

	[GtkChild (name = "infobar_secondary_label")]
	private unowned Gtk.Label d_infobar_secondary_label;

	[GtkChild (name = "list_box_stats")]
	private unowned Gtk.ListBox d_list_box_stats;

	[GtkChild (name = "scrolled_window_stats")]
	private unowned Gtk.ScrolledWindow d_scrolled_window_stats;

	[GtkChild (name = "prev_commit_message_button")]
	private unowned Gtk.Button d_prev_commit_message_button;

	[GtkChild (name = "next_commit_message_button")]
	private unowned Gtk.Button d_next_commit_message_button;

	private bool d_show_markup;
	private bool d_show_right_margin;
	private bool d_show_subject_margin;
	private int d_right_margin_position;
	private int d_subject_margin_position;
	private Ggit.Signature d_author;
	private Cancellable? d_cancel_avatar;
	private bool d_constructed;
	private Settings? d_message_settings;
	private Gitg.FontManager d_font_manager;
	private Settings? d_commit_settings;
	private bool d_enable_spell_checking;
	private string? d_spell_checking_language;
	private Gspell.Checker? d_spell_checker;
	private Ggit.Diff d_diff;
	private bool d_infobar_shown;
	private Json.Array d_message_array;
	private int reverse_pos_messages;
	private string saved_commit_message;
	private Gtk.TextTag d_subject_tag;
	private Gtk.TextTag d_too_long_tag;

	public Ggit.Diff? diff
	{
		owned get { return d_diff; }
		construct set { d_diff = value; }
	}

	public Gitg.Repository repository
	{
		owned get; construct set;
	}

	public int max_visible_stat_items
	{
		get;
		construct set;
		default = 3;
	}

	public Gtk.SourceView source_view_message
	{
		get { return d_source_view_message; }
	}

	public string pretty_message
	{
		owned get
		{
			var pretty = Ggit.message_prettify(message, false, '#');

			if (pretty == null)
			{
				return "";
			}
			else
			{
				return pretty;
			}
		}
	}

	private Ggit.Signature default_author;

	public string default_message
	{
		get; private set;
	}

	public string message
	{
		owned get
		{
			var b = d_source_view_message.buffer;

			Gtk.TextIter start;
			Gtk.TextIter end;

			b.get_bounds(out start, out end);
			return b.get_text(start, end, false);
		}
		set
		{
			d_source_view_message.buffer.set_text(value);
		}
	}

	public void reset_message()
	{
	   message = default_message;
	}

	public void update_default_message()
	{
	   default_message = message;
	}

	private bool d_amend;

	public bool amend
	{
		get { return d_amend; }

		set
		{
			d_amend = value;

			if (value)
			{
				d_infobar_revealer.set_reveal_child(false);

			}
			else if (d_infobar_shown)
			{
				d_infobar_revealer.set_reveal_child(true);
			}

			update_sensitivity();
		}
	}

	private void update_sensitivity()
	{
		set_response_sensitive(Gtk.ResponseType.OK, !d_infobar_revealer.get_reveal_child() && pretty_message != "");
	}

	public bool sign_off { get; set; }

	public bool sign_commit { get; set; }

	public int max_number_commit_messages { get; set; }

	public int max_number_days_commit_messages { get; set; }

	public bool show_markup
	{
		get { return d_show_markup; }

		set
		{
			d_show_markup = value;
			update_highlight();
		}
	}

	public bool show_right_margin
	{
		get { return d_show_right_margin; }

		construct set
		{
			d_show_right_margin = value;
			update_highlight();
		}
	}

	public bool show_subject_margin
	{
		get { return d_show_subject_margin; }

		construct set
		{
			d_show_subject_margin = value;
			update_highlight();
		}
	}

	public int right_margin_position
	{
		get { return d_right_margin_position; }

		construct set
		{
			d_right_margin_position = value;
			update_highlight();
		}
	}

	public int subject_margin_position
	{
		get { return d_subject_margin_position; }

		construct set
		{
			d_subject_margin_position = value;
			update_highlight();
		}
	}

	public Ggit.Signature author
	{
		owned get { return d_author; }

		construct set
		{
			d_author = value;
			load_author_info();
		}
	}

	public string? spell_checking_language
	{
		get { return d_spell_checking_language; }

		set
		{
			d_spell_checking_language = value;
		}
	}

	public bool enable_spell_checking
	{
		get { return d_enable_spell_checking; }
		set
		{
			d_enable_spell_checking = value;

			if (d_enable_spell_checking)
			{
				if (d_spell_checker == null)
				{
					d_spell_checker = new Gspell.Checker (get_spell_language ());
					unowned Gspell.TextBuffer gspell_buffer = Gspell.TextBuffer.get_from_gtk_text_buffer (d_source_view_message.buffer);
					gspell_buffer.set_spell_checker (d_spell_checker);

					Gspell.TextView gspell_view = Gspell.TextView.get_from_gtk_text_view (d_source_view_message as Gtk.TextView);
					gspell_view.inline_spell_checking = true;
					gspell_view.enable_language_menu = true;
				}
			}
			else
			{
				if (d_spell_checker != null)
				{
					d_spell_checker = null;
				}
			}
		}
	}

	private unowned Gspell.Language? get_spell_language ()
	{
		string? lang_code = d_spell_checking_language;

		if (lang_code[0] == '\0')
			return null;

		return Gspell.Language.lookup (lang_code);
	}

	private bool d_use_gravatar;

	public bool use_gravatar
	{
		get { return d_use_gravatar; }
		set
		{
			if (d_use_gravatar != value)
			{
				d_use_gravatar = value;
				load_author_info();
			}
		}
	}

	private void load_author_info()
	{
		if (d_cancel_avatar != null)
		{
			d_cancel_avatar.cancel();
			d_cancel_avatar = new Cancellable();
		}

		var name = d_author.get_name();
		var email = d_author.get_email();

		var s = @"$name <$email>";
		d_label_user.set_label(s);

		var rtl = (get_style_context().get_state() & Gtk.StateFlags.DIR_RTL) != 0;

		if (rtl == (Pango.find_base_dir(s, -1) != Pango.Direction.RTL))
		{
			d_label_user.halign = Gtk.Align.END;
		}
		else
		{
			d_label_user.halign = Gtk.Align.START;
		}

		var t = d_author.get_time();
		var now = new DateTime.now_local();
		string date_string;

		if (now.difference(t) < TimeSpan.SECOND * 5)
		{
			date_string = "";
		}
		else
		{
			date_string = (new Gitg.Date.for_date_time(t)).for_display();
		}

		d_label_date.set_label(date_string);

		if (rtl == (Pango.find_base_dir(date_string, -1) != Pango.Direction.RTL))
		{
			d_label_date.halign = Gtk.Align.END;
		}
		else
		{
			d_label_date.halign = Gtk.Align.START;
		}

		if (use_gravatar)
		{
			var ac = Gitg.AvatarCache.default();
			d_cancel_avatar = new Cancellable();

			ac.load.begin(d_author.get_email(), 50, d_cancel_avatar, (obj, res) => {
				var pixbuf = ac.load.end(res);

				if (d_cancel_avatar.is_cancelled())
				{
					return;
				}

				if (pixbuf != null)
				{
					d_image_avatar.set_from_pixbuf(pixbuf);
				}
				else
				{
					d_image_avatar.set_from_icon_name("avatar-default-symbolic", Gtk.IconSize.DIALOG);
				}
			});
		}
		else
		{
			d_image_avatar.set_from_icon_name("avatar-default-symbolic", Gtk.IconSize.DIALOG);
		}
	}

	protected override void destroy()
	{
		if (d_cancel_avatar != null)
		{
			d_cancel_avatar.cancel();
		}

		d_message_settings = null;
		d_font_manager = null;
		d_commit_settings = null;

		base.destroy();
	}

	construct
	{
		reverse_pos_messages = 0;
		default_author = author;

		response.connect(() => {
			save_commit_message ();
		});

		d_message_array = load_commit_messages ();
		if (d_message_array.get_length () == 0) {
			reverse_pos_messages = 0;
			d_prev_commit_message_button.sensitive = false;
		}

		d_font_manager = new Gitg.FontManager(d_source_view_message, false);

		var b = d_source_view_message.buffer;

		d_source_view_message.buffer.changed.connect(() => {
			update_sensitivity();
		});

		d_check_button_amend.bind_property("active",
		                                   this, "amend",
		                                   BindingFlags.BIDIRECTIONAL |
		                                   BindingFlags.SYNC_CREATE);

		d_check_button_sign_off.bind_property("active",
		                                      this, "sign-off",
		                                      BindingFlags.BIDIRECTIONAL |
		                                      BindingFlags.SYNC_CREATE);

		d_check_button_sign_commit.bind_property("active",
		                                          this, "sign-commit",
		                                          BindingFlags.BIDIRECTIONAL |
		                                          BindingFlags.SYNC_CREATE);

		d_commit_settings = new Settings(Gitg.Config.APPLICATION_ID + ".state.commit");

		d_commit_settings.bind("sign-off",
		                     this,
		                     "sign-off",
		                     SettingsBindFlags.GET |
		                     SettingsBindFlags.SET);

		d_commit_settings.bind("sign-commit",
		                     this,
		                     "sign-commit",
		                     SettingsBindFlags.GET |
		                     SettingsBindFlags.SET);

		d_message_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.commit.message");

		d_message_settings.bind("max-number-days-commit-messages",
								this,
								"max-number-days-commit-messages",
								SettingsBindFlags.GET);
		d_message_settings.bind("max-number-commit-messages",
								this,
								"max-number-commit-messages",
								SettingsBindFlags.GET);
		d_message_settings.bind("show-markup",
		                        this,
		                        "show-markup",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("show-right-margin",
		                        this,
		                        "show-right-margin",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("right-margin-position",
		                        this,
		                        "right-margin-position",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("show-subject-margin",
		                        this,
		                        "show-subject-margin",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("subject-margin-position",
		                        this,
		                        "subject-margin-position",
		                        SettingsBindFlags.GET);

		d_message_settings.bind("spell-checking-language",
		                        this,
		                        "spell-checking-language",
		                        SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_message_settings.bind("enable-spell-checking",
		                        this,
		                        "enable-spell-checking",
		                        SettingsBindFlags.GET | SettingsBindFlags.SET);

		var interface_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
		interface_settings.bind("use-gravatar",
		                        this,
		                        "use-gravatar",
		                        SettingsBindFlags.GET);

		d_constructed = true;

		init_message_area();

		if (diff != null && diff.get_num_deltas() != 0)
		{
			iterate_diff();
		}
		else
		{
			show_infobar(_("There are no changes to be committed"),
			             _("Use amend to change the commit message of the previous commit"),
			             Gtk.MessageType.WARNING);
		}

		notify["amend"].connect((obj, pspec) => {
			if (!amend)
			{
				author = default_author;
				reset_message();
			}
			else
			{
				get_head_commit.begin((obj, res) => {
					var commit = get_head_commit.end(res);

					if (commit != null)
					{
						update_default_message();
						message = prepare_commit_msg_hook(commit.get_message(),
						                                  GitgCommit.Dialog.PREPARE_COMMIT_MSG_SOURCE_COMMIT,
						                                  commit.get_id().to_string());

						author = commit.get_author();
					}
				});
			}
		});

	}

	private void save_commit_message ()
	{
		var message = pretty_message;
		if (message == "") {
			return;
		}

		Json.Builder builder = new Json.Builder ();

		builder.begin_object ();
		builder.set_member_name (VERSION_PROP);
		builder.add_string_value ("1.0");

		builder.set_member_name (DESCRIPTION_PROP);
		builder.add_string_value ("recent commit messages");

		builder.set_member_name (MESSAGES_PROP);
		builder.begin_array ();
		builder.begin_object ();
		builder.set_member_name (DATETIME_PROP);
		builder.add_string_value (new DateTime.now_utc ().to_string ());
		builder.set_member_name (TEXT_PROP);
		builder.add_string_value (message);
		builder.end_object ();

		var max_datetime = new DateTime.now_utc ().add_days (-max_number_days_commit_messages);
		int message_counter = 1;
		foreach (unowned Json.Node node in d_message_array.get_elements ()) {
			var object_node = node.get_object ();
			if (max_number_commit_messages > 0)
			{
				var datetime_str = object_node.get_string_member (DATETIME_PROP);
				var datetime = new DateTime.from_iso8601 (datetime_str, null);
				if (datetime.compare (max_datetime) < 0)
				{
					break;
				}
			}
			if (max_number_commit_messages > 0)
			{
				if (message_counter == max_number_commit_messages)
				{
					break;
				}
				message_counter++;
			}
			var node_message = object_node.get_string_member (TEXT_PROP);
			if (message == node_message)
			{
				continue;
			}
			builder.add_value (node);
		}
		builder.end_array ();

		builder.end_object ();

		Json.Generator generator = new Json.Generator ();
		generator.pretty = true;
		Json.Node root = builder.get_root ();
		generator.set_root (root);

		string current_contents = generator.to_data (null);
		try {
				var dirname = Environment.get_user_data_dir() + "/" + Gitg.Config.APPLICATION_ID;
				var dir = File.new_for_path(dirname);
				if (!dir.query_exists ()) {
					dir.make_directory_with_parents ();
				}
				var file = File.new_for_path(dirname + "/" + COMMIT_MESSAGE_FILENAME);
				file.replace_contents (current_contents.data, null, false,
									   GLib.FileCreateFlags.NONE, null, null);
		}
		catch (GLib.Error err) {
			error ("%s\n", err.message);
		}
	}

	private void iterate_diff()
	{
		var n = diff.get_num_deltas();
		int num = 0;

		for (var i = 0; i < n; ++i)
		{
			Ggit.Patch patch;

			try
			{
				patch = new Ggit.Patch.from_diff(diff, i);
			} catch { continue; }

			size_t add;
			size_t remove;

			try
			{
				patch.get_line_stats(null, out add, out remove);
			} catch { continue; }

			var delta = patch.get_delta();

			var nf = delta.get_new_file();
			var path = nf.get_path();

			var row = new Gtk.ListBoxRow();
			var grid = new Gtk.Grid();
			row.add(grid);
			grid.column_spacing = 6;

			var ds = new Gitg.DiffStat();

			ds.get_style_context().add_class("no-frame");

			ds.added = (uint)add;
			ds.removed = (uint)remove;

			grid.attach(ds, 0, 0, 1, 1);

			var lbl = new Gtk.Label(path);
			lbl.selectable = true;

			grid.attach(lbl, 1, 0, 1, 1);
			row.show_all();

			d_list_box_stats.add(row);
			++num;
		}

		d_list_box_stats.size_allocate.connect(() => {
			update_min_stat_size(num);
		});
	}

	private void update_min_stat_size(int num)
	{
		if (num == 0)
		{
			d_scrolled_window_stats.hide();
			return;
		}

		int n = int.min(num, max_visible_stat_items);

		var lastrow = d_list_box_stats.get_row_at_index(n - 1);

		Gtk.Allocation allocation;
		lastrow.get_allocation(out allocation);

		if (n == num)
		{
			d_scrolled_window_stats.set_policy(Gtk.PolicyType.NEVER,
			                                   Gtk.PolicyType.NEVER);
		}

		d_scrolled_window_stats.set_min_content_height(allocation.y + allocation.height);
	}

	private bool on_commit_message_key_press_event(Gtk.Widget widget, Gdk.EventKey event)
	{
		var mmask = Gtk.accelerator_get_default_mod_mask();

		if ((mmask & event.state) == Gdk.ModifierType.CONTROL_MASK)
		{
			if ((event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter))
			{
				d_button_ok.activate();
				return true;
			}
		}
		else if ((mmask & event.state) == Gdk.ModifierType.MOD1_MASK)
		{
			if (event.keyval == Gdk.Key.Page_Up)
			{
				on_prev_commit_message_button_clicked ();
			}
			else if (event.keyval == Gdk.Key.Page_Down)
			{
				on_next_commit_message_button_clicked ();
			}
		}

		return false;
	}

	private void init_message_area()
	{
		d_source_view_message.key_press_event.connect(on_commit_message_key_press_event);

		var b = d_source_view_message.buffer;

		d_subject_tag = b.create_tag("subject",
		                             "weight", Pango.Weight.BOLD);

		d_too_long_tag = b.create_tag("too-long", "background", "#f57900");


		b.changed.connect(() => {
			do_highlight();
		});

		update_highlight();

		default_message = "";
		string source = "";

		try
		{
			Ggit.Config config;

			config = repository.get_config().snapshot();

			var template_path = config.get_string(CONFIG_COMMIT_TEMPLATE);

			if (template_path != null)
			{
				var path = Gitg.Utils.expand_home_dir(template_path);

				if (!GLib.Path.is_absolute(path))
				{
					path = repository.get_workdir().get_child(path).get_path();
				}

				string contents;
				size_t len;

				FileUtils.get_contents(path, out contents, out len);

				default_message = Gitg.Convert.utf8(contents, (ssize_t)len).strip();
				source = PREPARE_COMMIT_MSG_SOURCE_TEMPLATE;
			}
		}
		catch (Error e) {
		   warning("%s\n", e.message);
		}

		bool exists_squash_msg = repository.get_location().get_child(SQUASH_MSG_FILENAME).query_exists();
		if (exists_squash_msg)
		{
			source = PREPARE_COMMIT_MSG_SOURCE_SQUASH;
		}

		get_head_commit.begin((obj, res) => {
			var commit = get_head_commit.end(res);

			bool exists_merge_msg = repository.get_location().get_child(MERGE_MSG_FILENAME).query_exists();
			if (exists_merge_msg || commit != null && commit.get_parents().get_size() > 1)
			{
				source = PREPARE_COMMIT_MSG_SOURCE_MERGE;
			}
		});

		message = prepare_commit_msg_hook(default_message, source);
	}

	private async Gitg.Commit? get_head_commit()
	{
		Gitg.Commit? retval = null;

		try
		{
			yield Gitg.Async.thread(() => {
				try
				{
					var head = repository.get_head();
					retval = repository.lookup<Gitg.Commit>(head.get_target());
				} catch {}
			});
		} catch {}

		return retval;
	}

	private string prepare_commit_msg_hook (string commit_msg, string commit_src = "", string commit_sha = "") {
		string? output = null;
		var config = repository.get_config().snapshot();
		string? hooks_path = null;
		try {
			hooks_path = config.get_string(CONFIG_HOOKS_PATH);
		} catch {
			hooks_path = "%s/hooks".printf(repository.get_location().get_path());
		}
		var hook_name = "%s/%s".printf(hooks_path, PREPARE_COMMIT_MSG_FILENAME);
		var hook_file = File.new_for_path(hook_name);

		if (!hook_file.query_exists()) {
			return commit_msg;
		}

		File file = null;
		string filename = COMMIT_MSG_FILENAME;
		bool delete_filename = false;

		if (commit_src == PREPARE_COMMIT_MSG_SOURCE_MERGE) {
			filename = MERGE_MSG_FILENAME;
			delete_filename = true;
		} else if (commit_src == PREPARE_COMMIT_MSG_SOURCE_SQUASH) {
			filename = SQUASH_MSG_FILENAME;
			delete_filename = true;
		}

		try {
			var hook_file_info = hook_file.query_info(FileAttribute.ACCESS_CAN_EXECUTE, FileQueryInfoFlags.NONE);

			if (hook_file_info.get_attribute_boolean (FileAttribute.ACCESS_CAN_EXECUTE)) {
				try {
					file = repository.get_location().get_child(filename);
					FileIOStream stream;
					if (delete_filename) {
						stream = file.create_readwrite (FileCreateFlags.PRIVATE);
					} else {
						stream = file.open_readwrite ();
					}

					var command = "echo %s > %s".printf(Shell.quote(commit_msg), Shell.quote(file.get_path()));
					Posix.system(command);

					string commit_sha_hook_param = "";
					if (commit_sha == "") {
						commit_sha_hook_param = Shell.quote(commit_sha);
					}
					command = "%s %s %s %s".printf(Shell.quote(hook_name), Shell.quote(file.get_path()),
					                               Shell.quote(commit_src), commit_sha_hook_param);
					Posix.system(command);

					FileInputStream @is = stream.input_stream as FileInputStream;
					DataInputStream dis = new DataInputStream (@is);
					string str;

					try {
						while ((str = dis.read_line ()) !=null) {
							if (output != null)
								output += "\n%s".printf(str);
							else
								output = "%s".printf(str);
						}
					} catch (Error e) {
						warning ("Error reading %s hook result: %s", PREPARE_COMMIT_MSG_FILENAME, e.message);
					}
				} catch (Error e) {
					warning ("Error executing pre-commit-msg: %s", e.message);
				} finally {
					if (delete_filename && file != null) {
						file.delete_async.begin (Priority.DEFAULT, null, (obj, res) => {
							try {
								file.delete_async.end (res);
							} catch (Error e) {
								warning ("Error deleting %s file: %s", PREPARE_COMMIT_MSG_FILENAME, e.message);
							}
						});
					}
				}
			}
		} catch (Error e) {
			warning ("Error checking %s hook : %s", PREPARE_COMMIT_MSG_FILENAME, e.message);
		}

		return output;
	}

	private void update_highlight()
	{
		if (!d_constructed)
		{
			return;
		}

		d_source_view_message.show_right_margin = (d_show_markup && d_show_right_margin);
		d_source_view_message.right_margin_position = d_right_margin_position;

		do_highlight();
	}

	private void do_highlight()
	{
		var b = d_source_view_message.buffer;

		Gtk.TextIter start;
		Gtk.TextIter end;

		b.get_bounds(out start, out end);
		b.remove_tag(d_subject_tag, start, end);
		b.remove_tag(d_too_long_tag, start, end);

		if (!d_show_markup)
		{
			return;
		}

		Gtk.TextIter sstart;
		Gtk.TextIter send;

		if (!start.forward_search("\n\n",
		                          Gtk.TextSearchFlags.TEXT_ONLY,
		                          out sstart,
		                          out send,
		                          null))
		{
			sstart = end;
			send = end;
		}

		b.apply_tag(d_subject_tag, start, sstart);

		if (d_show_subject_margin)
		{
			var toolong = sstart;

			while (true)
			{
				var off = toolong.get_line_offset();

				if (off > d_subject_margin_position)
				{
					var border = toolong;
					border.set_line_offset(d_subject_margin_position);

					b.apply_tag(d_too_long_tag, border, toolong);
				}

				if (toolong.get_line() == 0)
				{
					break;
				}

				if (!toolong.backward_line())
				{
					break;
				}

				if (!toolong.ends_line())
					toolong.forward_to_line_end();
			}
		}

		if (d_show_right_margin)
		{
			while (!send.equal(end))
			{
				if (!send.ends_line())
				{
					send.forward_to_line_end();
				}

				if (send.get_line_offset() > d_right_margin_position)
				{
					var lstart = send;
					lstart.set_line_offset(d_right_margin_position);

					b.apply_tag(d_too_long_tag, lstart, send);
				}

				if (!send.forward_line())
				{
					break;
				}
			}
		}
	}

	public Dialog(Gitg.Repository repository,
	              Ggit.Signature  author,
	              Ggit.Diff?      diff)
	{
		Object(repository: repository, author: author, diff: diff, use_header_bar: 1);
	}

	public void show_infobar(string          primary_msg,
	                         string          secondary_msg,
	                         Gtk.MessageType type)
	{
		d_infobar_shown = true;
		d_infobar.message_type = type;

		var primary = "<b>%s</b>".printf(Markup.escape_text(primary_msg));
		var secondary = "<small>%s</small>".printf(Markup.escape_text(secondary_msg));

		d_infobar_primary_label.set_label(primary);
		d_infobar_secondary_label.set_label(secondary);
		d_infobar_revealer.set_reveal_child(true);

		set_response_sensitive(Gtk.ResponseType.OK, false);
	}

	private Json.Array load_commit_messages ()
	{
		var file = File.new_for_path(Environment.get_user_data_dir() + "/" +
									 Gitg.Config.APPLICATION_ID + "/" + COMMIT_MESSAGE_FILENAME);

		uint8[] file_contents;

		Json.Array message_array;
		try {
			file.load_contents (null, out file_contents, null);
			Json.Parser parser = new Json.Parser ();
			parser.load_from_data ((string) file_contents);
			Json.Node node = parser.get_root ();
			var root_object_node = node.get_object ();
			message_array = root_object_node.get_member (MESSAGES_PROP).get_array ();
		}
		catch (GLib.Error err) {
			warning ("%s\n", err.message);
			message_array = new Json.Array ();
		}
		return message_array;

	}

	[GtkCallback]
	private void on_next_commit_message_button_clicked ()
	{
		if (reverse_pos_messages > 0) {
		  d_prev_commit_message_button.sensitive = true;
		  reverse_pos_messages--;
		  if (reverse_pos_messages == 0) {
			  message = saved_commit_message;
			  d_next_commit_message_button.sensitive = false;
			  return;
		  }
		} else {
			d_next_commit_message_button.sensitive = false;
			d_prev_commit_message_button.sensitive = true;
			return;
		}

		load_selected_commit_message ();
	}

	[GtkCallback]
	private void on_prev_commit_message_button_clicked ()
	{
		if (reverse_pos_messages < d_message_array.get_length ()) {
		  if (reverse_pos_messages == 0) {
			  saved_commit_message = message;
		  }
		  d_next_commit_message_button.sensitive = true;
		  reverse_pos_messages++;
		} else {
			d_prev_commit_message_button.sensitive = false;
			if (reverse_pos_messages <= 0) {
				reverse_pos_messages = 0;
				d_next_commit_message_button.sensitive = true;
			}
			return;
		}

		if (d_message_array.get_length() == reverse_pos_messages) {
			d_prev_commit_message_button.sensitive = false;
		}

		load_selected_commit_message ();
	}

	private void load_selected_commit_message ()
	{
		int counter = 0;
		foreach (unowned Json.Node node_item in d_message_array.get_elements ()) {
			counter++;
			if (counter < reverse_pos_messages) {
				continue;
			}
			var object_node = node_item.get_object ();
			var commit_message = object_node.get_string_member(TEXT_PROP);
			message = commit_message;
			break;
		}
	}
}

}

// ex: ts=4 noet
