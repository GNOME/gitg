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
	private Gtk.Image d_image_avatar;

	[GtkChild( name = "label_author" )]
	private Gtk.Label d_label_author;

	[GtkChild( name = "label_author_date" )]
	private Gtk.Label d_label_author_date;

	[GtkChild( name = "label_committer" )]
	private Gtk.Label d_label_committer;

	[GtkChild( name = "label_committer_date" )]
	private Gtk.Label d_label_committer_date;

	[GtkChild( name = "label_subject" )]
	private Gtk.Label d_label_subject;

	[GtkChild( name = "label_sha1" )]
	private Gtk.Label d_label_sha1;

	[GtkChild( name = "grid_parents_container" )]
	private Gtk.Grid d_grid_parents_container;

	[GtkChild( name = "grid_parents" )]
	private Gtk.Grid d_grid_parents;

	[GtkChild( name = "expander_files" )]
	private Gtk.Expander d_expander_files;

	[GtkChild( name = "label_expand_collapse_files" )]
	private Gtk.Label d_label_expand_collapse_files;

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

	public string config_file { get; construct set; }

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

	private Gee.HashMap<Ggit.OId, Gtk.RadioButton> d_parents_map;

	private GLib.Regex regex_url = /\w+:(\/?\/?)[^\s]+/;

	construct
	{
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

		use_gravatar = true;
	}

	protected override void dispose()
	{
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

		return "%s &lt;<a href=\"mailto:%s\">%s</a>&gt;".printf(name, email, email);
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

		d_label_subject.label = parse_links_on_subject(commit.get_subject());
		d_label_sha1.label = commit.get_id().to_string();

		var author = commit.get_author();

		d_label_author.label = author_to_markup(author);
		d_label_author_date.label = author.get_time().to_timezone(author.get_time_zone()).format("%x %X %z");

		var committer = commit.get_committer();

		if (committer.get_name() != author.get_name() ||
		    committer.get_email() != author.get_email() ||
		    committer.get_time().compare(author.get_time()) != 0)
		{
			d_label_committer.label = _("Committed by %s").printf(author_to_markup(committer));
			d_label_committer_date.label = committer.get_time().to_timezone(committer.get_time_zone()).format("%x %X %z");
		}
		else
		{
			d_label_committer.label = "";
			d_label_committer_date.label = "";
		}

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

			result = parse_ini_file(result);
		}
		catch(Error e)
		{
		}
		return result;
	}

	private string parse_ini_file(string subject_text)
	{
		string result = subject_text;
		if (config_file!=null)
		{
			try
			{
				debug ("parsing %s", config_file);
				GLib.KeyFile file = new GLib.KeyFile();
				if (file.load_from_file(config_file , GLib.KeyFileFlags.NONE))
				{
					result = subject_text.dup();
					foreach (string group in file.get_groups())
					{
						if (group.has_prefix("gitg.custom-link"))
						{
							string custom_link_regexp = file.get_string (group, "regexp");
							string custom_link_replacement = file.get_string (group, "replacement");
							debug ("found group: %s", custom_link_regexp);
							bool custom_color = file.has_key (group, "color");
							string color = null;
							if (custom_color)
							{
								string custom_link_color = file.get_string (group, "color");
								color = custom_link_color;
							}

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
									if (color != null) {
										result = result.replace(text, "<a href=\"%s\" title=\"%s\" style=\"color:%s\">%s</a>".printf(link, link, color, text));
									} else {
										result = result.replace(text, "<a href=\"%s\" title=\"%s\">%s</a>".printf(link, link, text));
									}

									matchInfo.next();
								}
							}
							catch(Error e)
							{
							}
						}
					}
				}
			} catch (Error e)
			{
				warning ("Cannot read %s %s", config_file, e.message);
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
