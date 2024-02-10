/*
 * This file is part of gitg
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-commit-details.ui")]
class Gitg.DiffViewCommitDetails : Gtk.Grid
{
	[GtkChild( name = "image_avatar" )]
	private unowned Gtk.Image d_image_avatar;

	[GtkChild( name = "label_author" )]
	private unowned Gtk.Label d_label_author;

	[GtkChild( name = "label_author_date" )]
	private unowned Gtk.Label d_label_author_date;

	[GtkChild( name = "label_committer" )]
	private unowned Gtk.Label d_label_committer;

	[GtkChild( name = "label_committer_date" )]
	private unowned Gtk.Label d_label_committer_date;

	[GtkChild( name = "label_subject" )]
	private unowned Gtk.Label d_label_subject;

	[GtkChild( name = "label_sha1" )]
	private unowned Gtk.Label d_label_sha1;

	[GtkChild( name = "grid_parents_container" )]
	private unowned Gtk.Grid d_grid_parents_container;

	[GtkChild( name = "grid_parents" )]
	private unowned Gtk.Grid d_grid_parents;

	[GtkChild( name = "expander_files" )]
	private unowned Gtk.Expander d_expander_files;

	[GtkChild( name = "label_expand_collapse_files" )]
	private unowned Gtk.Label d_label_expand_collapse_files;

	private Settings d_settings;

	public bool expanded
	{
		get { return d_expander_files.expanded; }
		set
		{
			if (d_expander_files.expanded != value)
			{
				d_expander_files.expanded = value;
			}
		}
	}

	public bool expander_visible
	{
		get { return d_expander_files.visible; }

		set
		{
			d_expander_files.visible = value;
			d_label_expand_collapse_files.visible = value;
		}
	}

	private Cancellable? d_avatar_cancel;

	private Ggit.Commit? d_commit;

	public Ggit.Commit? commit
	{
		get { return d_commit; }
		construct set
		{
			if (d_commit != value)
			{
				d_commit = value;
				update();
			}
		}
	}

	private Ggit.Commit d_parent_commit;

	public Ggit.Commit parent_commit
	{
		get { return d_parent_commit; }
		set
		{
			if (d_parent_commit != value)
			{
				d_parent_commit = value;

				if (value != null)
				{
					var button = d_parents_map[value.get_id()];

					if (button != null)
					{
						button.active = true;
					}
				}
			}
		}
	}

	private bool d_use_gravatar;

	public bool use_gravatar
	{
		get { return d_use_gravatar; }
		construct set
		{
			d_use_gravatar = value;
			update_avatar();
		}
	}

	public Gitg.Repository? repository {get; set; }

	private string d_datetime_format;

	private string datetime_format
	{
		get {
			return d_datetime_format;
		}
		set {
			d_datetime_format = value;
			update_datetime();
		}
	}

	private Gee.HashMap<Ggit.OId, Gtk.RadioButton> d_parents_map;

	private GLib.Regex regex_url = /\w+:(\/?\/?)[^\s]+/;
	private Ggit.Config config {get; set;}
	private GLib.Regex regex_custom_links = /gitg\.custom-link\.(.+)\.regex/;

	private void on_change_datetime(Settings settings, string key) {
		datetime_format = settings.get_string("datetime-selection") == "custom"
			? settings.get_string("custom-datetime")
			: settings.get_string("predefined-datetime");
	}

	construct
	{
		d_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.commit.message");
		d_settings.changed["datetime-selection"].connect(on_change_datetime);
		d_settings.changed["custom-datetime"].connect(on_change_datetime);
		d_settings.changed["predefined-datetime"].connect(on_change_datetime);
		on_change_datetime(d_settings, "");

		d_expander_files.notify["expanded"].connect(() => {
			if (d_expander_files.expanded)
			{
				d_label_expand_collapse_files.label = _("Collapse all");
			}
			else
			{
				d_label_expand_collapse_files.label = _("Expand all");
			}

			notify_property("expanded");
		});
	}

	protected override void dispose()
	{

		if (d_settings != null)
		{
			d_settings.changed["datetime-selection"].disconnect(on_change_datetime);
			d_settings.changed["custom-datetime"].disconnect(on_change_datetime);
			d_settings.changed["predefined-datetime"].disconnect(on_change_datetime);
			d_settings = null;
		}

		if (d_avatar_cancel != null)
		{
			d_avatar_cancel.cancel();
		}

		base.dispose();
	}

	private string author_to_markup(Ggit.Signature author)
	{
		var name = Markup.escape_text(author.get_name());
		var email = Markup.escape_text(author.get_email());

		return "<a href=\"mailto:%s\" title=\"%s\">%s</a>".printf(email, email, name);
	}

	private void update()
	{
		d_parents_map = new Gee.HashMap<Ggit.OId, Gtk.RadioButton>((oid) => oid.hash(), (o1, o2) => o1.equal(o2));

		foreach (var child in d_grid_parents.get_children())
		{
			child.destroy();
		}

		if (commit == null)
		{
			return;
		}

		d_label_subject.set_markup(subject_to_markup(Markup.escape_text(commit.get_subject())));
		d_label_sha1.label = commit.get_id().to_string();

		var author = commit.get_author();

		d_label_author.label = _("<small>Authored by</small> %s").printf(author_to_markup(author));

		var committer = commit.get_committer();

		if (committer.get_name() != author.get_name() ||
		    committer.get_email() != author.get_email() ||
		    committer.get_time().compare(author.get_time()) != 0)
		{
			if (committer.get_email().has_prefix("noreply@") ||
			    committer.get_email().has_prefix("no-reply@") ||
			    committer.get_email().has_prefix("gnome-sysadmin@") ||
			    committer.get_email().has_prefix("root@") ||
			    committer.get_email().has_prefix("localhost@"))
			{
				d_label_committer.label = _("<small>Committed by</small> %s").printf(committer.get_name());
			}
			else
			{
				d_label_committer.label = _("<small>Committed by</small> %s").printf(author_to_markup(committer));
			}
		}
		else
		{
			d_label_committer.label = "";
		}

		update_datetime();

		var parents = commit.get_parents();
		var first_parent = parents.size == 0 ? null : parents.get(0);

		parent_commit = first_parent;

		if (parents.size > 1)
		{
			d_grid_parents_container.show();
			var grp = new SList<Gtk.RadioButton>();

			Gtk.RadioButton? first = null;

			foreach (var parent in parents)
			{
				var pid = parent.get_id().to_string().substring(0, 6);
				var psubj = parent.get_subject();

				var button = new Gtk.RadioButton.with_label(grp, @"$pid: $psubj");

				if (first == null)
				{
					first = button;
				}

				button.group = first;

				d_parents_map[parent.get_id()] = button;

				button.show();
				d_grid_parents.add(button);

				var par = parent;

				button.toggled.connect(() => {
					if (button.active) {
						parent_commit = par;
					}
				});
			}
		}
		else
		{
			d_grid_parents_container.hide();
		}

		update_avatar();
	}

	private void update_datetime()
	{
		if (commit == null)
		{
			return;
		}

		var author = commit.get_author();

		d_label_author_date.label = author.get_time().to_timezone(author.get_time_zone()).format(datetime_format);

		var committer = commit.get_committer();

		if (committer.get_name() != author.get_name() ||
		    committer.get_email() != author.get_email() ||
		    committer.get_time().compare(author.get_time()) != 0)
		{
			d_label_committer_date.label = committer.get_time().to_timezone(committer.get_time_zone()).format(datetime_format);
		}
		else
		{
			d_label_committer_date.label = "";
		}
	}

	private string subject_to_markup(string subject_text)
	{
		return parse_links_on_subject(subject_text);
	}

	private string parse_links_on_subject(string subject_text)
	{
		string result = subject_text.dup();
		try
		{
			GLib.MatchInfo matchInfo;
			regex_url.match (subject_text, 0, out matchInfo);

			while (matchInfo.matches ())
			{
				string text = matchInfo.fetch(0);
				result = result.replace(text, "<a href=\"%s\">%s</a>".printf(text, text));
				matchInfo.next();
			}

			result = parse_smart_text(result);
		}
		catch(Error e)
		{
		}
		return result;
	}

	private string parse_smart_text(string subject_text)
	{
		string result = subject_text;
		if (repository != null)
		{
			result = subject_text.dup();
			try
			{
				var conf = repository.get_config().snapshot();
				conf.match_foreach(regex_custom_links, (match_info, value) => {
					string group = match_info.fetch(1);
					debug ("found custom-link group: %s", group);
					debug (value == null ? "es nulo": "es vacio");
					string custom_link_regexp = value;
					string replacement_key = "gitg.custom-link.%s.replacement".printf(group);
					try
					{
						string custom_link_replacement = conf.get_string(replacement_key);

						var custom_regex = new Regex (custom_link_regexp);
						try
						{
							GLib.MatchInfo matchInfo;

							custom_regex.match (subject_text, 0, out matchInfo);

							while (matchInfo.matches ())
							{
								string text = matchInfo.fetch(0);
								string link = text.dup();
								debug ("found: %s", link);
								if (custom_link_replacement != null)
								{
									link = custom_regex.replace(link, text.length, 0, custom_link_replacement);
								}
								result = result.replace(text, "<a href=\"%s\" title=\"%s\">%s</a>".printf(link, link, text));

								matchInfo.next();
							}
						}
						catch(Error e)
						{
						}
					} catch (Error e)
					{
						warning ("Cannot read git config: %s", e.message);
					}
					return 0;
				});
			}
			catch(Error e)
			{
				warning ("Cannot read git config: %s", e.message);
			}
		}
		return result;
	}

	private void update_avatar()
	{
		if (commit == null)
		{
			return;
		}

		if (d_use_gravatar)
		{
			if (d_avatar_cancel != null)
			{
				d_avatar_cancel.cancel();
			}

			d_avatar_cancel = new Cancellable();
			var cancel = d_avatar_cancel;

			var cache = AvatarCache.default();

			cache.load.begin(commit.get_author().get_email(), d_image_avatar.pixel_size, cancel, (obj, res) => {
				if (!cancel.is_cancelled())
				{
					var pixbuf = cache.load.end(res);

					if (pixbuf != null)
					{
						d_image_avatar.pixbuf = pixbuf;
						d_image_avatar.get_style_context().remove_class("dim-label");
					}
					else
					{
						d_image_avatar.icon_name = "avatar-default-symbolic";
						d_image_avatar.get_style_context().add_class("dim-label");
					}
				}

				if (cancel == d_avatar_cancel)
				{
					d_avatar_cancel = null;
				}
			});
		}
		else
		{
			d_image_avatar.icon_name = "avatar-default-symbolic";
			d_image_avatar.get_style_context().add_class("dim-label");
		}
	}

	[GtkCallback]
	private bool button_press_on_event_box_expand_collapse(Gdk.EventButton event)
	{
		if (event.button == Gdk.BUTTON_PRIMARY)
		{
			d_expander_files.expanded = !d_expander_files.expanded;
			return true;
		}

		return false;
	}
}

// ex:ts=4 noet
