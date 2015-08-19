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

namespace Gitg
{

class CommitActionCherryPick : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }

	private Gitg.Ref[]? d_destinations;
	private ActionSupport d_support;

	public CommitActionCherryPick(GitgExt.Application        application,
	                              GitgExt.RefActionInterface action_interface,
	                              Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);

		d_support = new ActionSupport(application, action_interface);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/cherry-pick"; }
	}

	public string display_name
	{
		owned get { return _("Cherry pick onto"); }
	}

	public string description
	{
		owned get { return _("Cherry pick this commit onto a branch"); }
	}

	public bool available
	{
		get { return true; }
	}

	public bool enabled
	{
		get
		{
			if (commit.get_parents().get_size() > 1)
			{
				return false;
			}

			ensure_destinations();
			return d_destinations.length != 0;
		}
	}

	private void ensure_destinations()
	{
		if (d_destinations != null)
		{
			return;
		}

		d_destinations = new Gitg.Ref[0];

		foreach (var r in action_interface.references)
		{
			if (r.is_branch())
			{
				try
				{
					var c = r.lookup() as Ggit.Commit;

					if (!c.get_id().equal(commit.get_id()))
					{
						d_destinations += r;
					}
				} catch {}
			}
		}
	}

	private async Ggit.Index? create_index(SimpleNotification notification, Gitg.Ref destination)
	{
		Gitg.Commit? theirs = null;
		string theirs_name = destination.parsed_name.shortname;

		try
		{
			theirs = destination.lookup() as Gitg.Commit;
		}
		catch (Error e)
		{
			notification.error(_("Failed to lookup the commit for branch %s: %s").printf(@"'$theirs_name'", e.message));
			return null;
		}

		var merge_options = new Ggit.MergeOptions();
		Ggit.Index? index = null;

		try
		{
			yield Async.thread(() => {
				index = application.repository.cherry_pick_commit(commit, theirs, 0, merge_options);
			});
		}
		catch (Error e)
		{
			notification.error(_("Failed to cherry-pick the commit: %s").printf(e.message));
			return null;
		}

		return index;
	}

	private async bool checkout_conflicts(SimpleNotification notification, Ggit.Index index, Gitg.Ref destination)
	{
		var ours_name = commit.get_id().to_string()[0:6];
		var theirs_name = destination.parsed_name.shortname;

		notification.message = _("Cherry pick has conflicts");

		Gitg.Ref? head = null;
		var ishead = d_support.reference_is_head(destination, ref head);

		string message;

		if (ishead)
		{
			message = _("The cherry pick of %s onto %s has caused conflicts, would you like to checkout branch %s with the cherry pick to your working directory to resolve the conflicts?").printf(@"'$ours_name'", @"'$theirs_name'", @"'$theirs_name'");
		}
		else
		{
			message = _("The cherry-pick of %s onto %s has caused conflicts, would you like to checkout the cherry pick to your working directory to resolve the conflicts?").printf(@"'$ours_name'", @"'$theirs_name'");
		}

		var q = new GitgExt.UserQuery.full(_("Cherry pick has conflicts"),
		                                   message,
		                                   Gtk.MessageType.QUESTION,
		                                   _("Cancel"), Gtk.ResponseType.CANCEL,
		                                   _("Checkout"), Gtk.ResponseType.OK);

		if ((yield application.user_query_async(q)) != Gtk.ResponseType.OK)
		{
			notification.error(_("Cherry pick failed with conflicts"));
			return false;
		}

		if (!(yield d_support.checkout_conflicts(notification, destination, index, head)))
		{
			return false;
		}

		write_cherry_pick_state_files();

		notification.success(_("Cherry pick finished with conflicts in working directory"));
		return true;
	}

	private void write_cherry_pick_state_files()
	{
		var wd = application.repository.get_location().get_path();

		try
		{
			FileUtils.set_contents(Path.build_filename(wd, "CHERRY_PICK_HEAD"), "%s\n".printf(commit.get_id().to_string()));
		} catch {}
	}

	public async void cherry_pick(Gitg.Ref destination)
	{
		var id = commit.get_id();
		var shortid = id.to_string()[0:6];
		var name = destination.parsed_name.shortname;

		var notification = new SimpleNotification(_("Cherry pick %s onto %s").printf(@"'$shortid'", @"'$name'"));

		application.notifications.add(notification);

		var index = yield create_index(notification, destination);

		if (index == null)
		{
			return;
		}

		if (index.has_conflicts())
		{
			yield checkout_conflicts(notification, index, destination);
			return;
		}

		var oid = yield d_support.commit_index(notification,
		                                       destination,
		                                       index,
		                                       null,
		                                       commit.get_author(),
		                                       commit.get_message());

		if (oid != null) {
			notification.success(_("Successfully cherry picked"));
		}
	}

	private void activate_destination(Gitg.Ref destination)
	{
		cherry_pick.begin(destination, (obj, res) => {
			cherry_pick.end(res);
		});
	}

	public void populate_menu(Gtk.Menu menu)
	{
		if (!available)
		{
			return;
		}

		ensure_destinations();

		if (!enabled)
		{
			return;
		}

		var item = new Gtk.MenuItem.with_label(display_name);
		item.tooltip_text = description;
		item.show();

		var submenu = new Gtk.Menu();
		submenu.show();

		foreach (var dest in d_destinations)
		{
			var name = dest.parsed_name.shortname;
			var subitem = new Gtk.MenuItem.with_label(name);

			subitem.tooltip_text = _("Cherry pick onto %s").printf(@"'$name'");
			subitem.show();

			subitem.activate.connect(() => {
				activate_destination(dest);
			});

			submenu.append(subitem);
		}

		item.submenu = submenu;
		menu.append(item);
	}

	public void activate()
	{
	}
}

}

// ex:set ts=4 noet
