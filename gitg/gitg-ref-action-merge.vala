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

class RefActionMerge : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	private struct RemoteSource
	{
		public string name;
		public Gitg.Ref[] sources;
	}

	private bool d_has_sourced;
	private Gitg.Ref? d_upstream;
	private Gitg.Ref[]? d_local_sources;
	private RemoteSource[]? d_remote_sources;
	private Gitg.Ref[]? d_tag_sources;

	public RefActionMerge(GitgExt.Application        application,
	                      GitgExt.RefActionInterface action_interface,
	                      Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/merge"; }
	}

	public string display_name
	{
		owned get { return _("Merge into %s").printf(reference.parsed_name.shortname); }
	}

	public string description
	{
		// TODO
		owned get { return _("Merge another branch into branch %s").printf(reference.parsed_name.shortname); }
	}

	public bool available
	{
		get
		{
			return reference.is_branch();
		}
	}

	public bool enabled
	{
		get
		{
			ensure_sources();

			return d_upstream != null ||
			       d_local_sources.length != 0 ||
			       d_remote_sources.length != 0 ||
			       d_tag_sources.length != 0;
		}
	}

	private async Ggit.Index create_merge_index(SimpleNotification notification, Ggit.Commit ours, Ggit.Commit theirs)
	{
		Ggit.Index? index = null;

		yield Async.thread_try(() => {
			var options = new Ggit.MergeOptions();

			try
			{
				index = application.repository.merge_commits(ours, theirs, options);
			}
			catch (Error e)
			{
				notification.error(_("Failed to merge commits: %s").printf(e.message));
				return;
			}
		});

		return index;
	}

	private async bool working_directory_dirty()
	{
		var options = new Ggit.StatusOptions(0, Ggit.StatusShow.WORKDIR_ONLY, null);
		var is_dirty = false;

		yield Async.thread_try(() => {
			application.repository.file_status_foreach(options, (path, flags) => {
				is_dirty = true;
				return -1;
			});
		});

		return is_dirty;
	}

	private async bool save_stash(SimpleNotification notification, Gitg.Ref? head)
	{
		var committer = application.get_verified_committer();

		if (committer == null)
		{
			return false;
		}

		try
		{
			yield Async.thread(() => {
				// Try to stash changes
				string message;

				if (head != null)
				{
					var headname = head.parsed_name.shortname;

					try
					{
						var head_commit = head.resolve().lookup() as Ggit.Commit;
						var shortid = head_commit.get_id().to_string()[0:6];
						var subject = head_commit.get_subject();

						message = @"WIP on $(headname): $(shortid) $(subject)";
					}
					catch
					{
						message = @"WIP on $(headname)";
					}
				}
				else
				{
					message = "WIP on HEAD";
				}

				application.repository.save_stash(committer, message, Ggit.StashFlags.DEFAULT);
			});
		}
		catch (Error err)
		{
			notification.error(_("Failed to stash changes: %s").printf(err.message));
			return false;
		}

		return true;
	}

	private bool reference_is_head(ref Gitg.Ref? head)
	{
		var branch = reference as Ggit.Branch;
		head = null;

		if (branch == null)
		{
			return false;
		}

		try
		{
			if (!branch.is_head())
			{
				return false;
			}

			head = application.repository.lookup_reference("HEAD");
		} catch {}

		return head != null;
	}

	private async bool stash_if_needed(SimpleNotification notification, Gitg.Ref head)
	{
		// Offer to stash if there are any local changes
		if ((yield working_directory_dirty()))
		{
			var q = new GitgExt.UserQuery.full(_("Unstaged changes"),
			                                   _("You appear to have unstaged changes in your working directory. Would you like to stash the changes before the checkout?"),
			                                   Gtk.MessageType.QUESTION,
			                                   _("Cancel"), Gtk.ResponseType.CANCEL,
			                                   _("Stash changes"), Gtk.ResponseType.OK);

			if ((yield application.user_query_async(q)) != Gtk.ResponseType.OK)
			{
				notification.error(_("Merge failed with conflicts"));
				return false;
			}

			if (!(yield save_stash(notification, head)))
			{
				return false;
			}
		}

		return true;
	}

	private async bool checkout_conflicts(SimpleNotification notification, Ggit.Index index, Gitg.Ref source)
	{
		var ours_name = reference.parsed_name.shortname;
		var theirs_name = source.parsed_name.shortname;

		notification.message = _("Merge has conflicts");

		Gitg.Ref? head = null;
		var ishead = reference_is_head(ref head);

		string message;

		if (ishead)
		{
			message = _("The merge of %s into %s has caused conflicts, would you like to checkout branch %s with the merge to your working directory to resolve the conflicts?").printf(@"'$theirs_name'", @"'$ours_name'", @"'$ours_name'");
		}
		else
		{
			message = _("The merge of %s into %s has caused conflicts, would you like to checkout the merge to your working directory to resolve the conflicts?").printf(@"'$theirs_name'", @"'$ours_name'");
		}

		var q = new GitgExt.UserQuery.full(_("Merge has conflicts"),
		                                   message,
		                                   Gtk.MessageType.QUESTION,
		                                   _("Cancel"), Gtk.ResponseType.CANCEL,
		                                   _("Checkout"), Gtk.ResponseType.OK);

		if ((yield application.user_query_async(q)) != Gtk.ResponseType.OK)
		{
			notification.error(_("Merge failed with conflicts"));
			return false;
		}

		if (!(yield stash_if_needed(notification, head)))
		{
			return false;
		}

		if (!ishead)
		{
			// Perform checkout of the local branch first
			var checkout = new RefActionCheckout(application, action_interface, reference);

			if (!(yield checkout.checkout()))
			{
				notification.error(_("Merge failed with conflicts"));
				return false;
			}
		}

		// Finally, checkout the conflicted index
		try
		{
			yield Async.thread(() => {
				var opts = new Ggit.CheckoutOptions();
				opts.set_strategy(Ggit.CheckoutStrategy.SAFE);
				application.repository.checkout_index(index, opts);
			});
		}
		catch (Error err)
		{
			notification.error(_("Failed to checkout conflicts: %s").printf(err.message));
			return false;
		}

		// Write the merge state files
		var wd = application.repository.get_location().get_path();

		try
		{
			var dest_oid = reference.resolve().get_target();

			FileUtils.set_contents(Path.build_filename(wd, "ORIG_HEAD"), "%s\n".printf(dest_oid.to_string()));
		} catch {}

		try
		{
			var source_oid = source.resolve().get_target();

			FileUtils.set_contents(Path.build_filename(wd, "MERGE_HEAD"), "%s\n".printf(source_oid.to_string()));
		} catch {}

		try
		{
			FileUtils.set_contents(Path.build_filename(wd, "MERGE_MODE"), "no-ff\n");
		} catch {}

		try
		{
			string msg;

			if (source.parsed_name.rtype == RefType.REMOTE)
			{
				msg = @"Merge remote branch '$theirs_name'";
			}
			else
			{
				msg = @"Merge branch '$theirs_name'";
			}

			msg += "\n\nConflicts:\n";

			var entries = index.get_entries();
			var seen = new Gee.HashSet<string>();

			for (var i = 0; i < entries.size(); i++)
			{
				var entry = entries.get_by_index(i);
				var p = entry.get_path();

				if (entry.is_conflict() && !seen.contains(p))
				{
					msg += "\t%s\n".printf(p);
					seen.add(p);
				}
			}

			FileUtils.set_contents(Path.build_filename(wd, "MERGE_MSG"), msg);
		} catch {}

		notification.success(_("Finished merge with conflicts in working directory"));
		return true;
	}

	public async Ggit.OId? merge(Gitg.Ref source)
	{
		Ggit.Commit ours;
		Ggit.Commit theirs;

		var ours_name = reference.parsed_name.shortname;
		var theirs_name = source.parsed_name.shortname;

		var notification = new SimpleNotification(_("Merge %s into %s").printf(@"'$theirs_name'", @"'$ours_name'"));
		application.notifications.add(notification);

		try
		{
			ours = reference.resolve().lookup() as Ggit.Commit;
		}
		catch (Error e)
		{
			notification.error(_("Failed to lookup our commit: %s").printf(e.message));
			return null;
		}

		try
		{
			theirs = source.resolve().lookup() as Ggit.Commit;
		}
		catch (Error e)
		{
			notification.error(_("Failed to lookup their commit: %s").printf(e.message));
			return null;
		}

		var index = yield create_merge_index(notification, ours, theirs);

		if (index == null)
		{
			return null;
		}

		if (index.has_conflicts())
		{
			yield checkout_conflicts(notification, index, source);
			return null;
		}

		var committer = application.get_verified_committer();

		if (committer == null)
		{
			notification.error(_("Failed to obtain author details"));
			return null;
		}

		string msg;

		if (source.parsed_name.rtype == RefType.REMOTE)
		{
			msg = @"Merge remote branch '$theirs_name'";
		}
		else
		{
			msg = @"Merge branch '$theirs_name'";
		}

		var stage = application.repository.stage;

		Gitg.Ref? head = null;
		var ishead = reference_is_head(ref head);

		Ggit.OId? oid = null;
		Ggit.Tree? head_tree = null;

		if (ishead)
		{
			if (!(yield stash_if_needed(notification, head)))
			{
				return null;
			}

			try
			{
				head_tree = (reference.lookup() as Ggit.Commit).get_tree();
			}
			catch (Error e)
			{
				notification.error(_("Failed to obtain HEAD tree: %s").printf(e.message));
				return null;
			}
		}

		try
		{
			// TODO: not all hooks are being executed yet
			oid = yield stage.commit_index(index,
			                               ishead ? head : reference,
			                               msg,
			                               committer,
			                               committer,
			                               new Ggit.OId[] { ours.get_id(), theirs.get_id() },
			                               StageCommitOptions.NONE);
		}
		catch (Error e)
		{
			notification.error(_("Failed to create commit: %s").printf(e.message));
			return null;
		}

		if (ishead)
		{
			try
			{
				yield Async.thread(() => {
					var opts = new Ggit.CheckoutOptions();

					opts.set_strategy(Ggit.CheckoutStrategy.SAFE);
					opts.set_baseline(head_tree);

					var commit = application.repository.lookup<Ggit.Commit>(oid);
					var tree = commit.get_tree();

					application.repository.checkout_tree(tree, opts);
				});
			}
			catch (Error e)
			{
				notification.error(_("Failed to checkout index: %s").printf(e.message));
				return null;
			}
		}

		notification.success(_("Successfully merged %s into %s").printf(@"'$theirs_name'", @"'$ours_name'"));
		return oid;
	}

	public void activate_source(Gitg.Ref source)
	{
		merge.begin(source, (obj, res) => {
			merge.end(res);
		});
	}

	private Gitg.Ref? upstream_reference()
	{
		var branch = reference as Ggit.Branch;

		if (branch != null)
		{
			try
			{
				return branch.get_upstream() as Gitg.Ref;
			} catch {}
		}

		return null;
	}

	private void add_merge_source(Gtk.Menu submenu, Gitg.Ref? source)
	{
		if (source == null)
		{
			var sep = new Gtk.SeparatorMenuItem();
			sep.show();
			submenu.append(sep);
			return;
		}

		var name = source.parsed_name.shortname;
		var item = new Gtk.MenuItem.with_label(name);

		item.show();
		item.tooltip_text = _("Merge %s into branch %s").printf(@"'$name'", @"'$(reference.parsed_name.shortname)'");

		item.activate.connect(() => {
			activate_source(source);
		});

		submenu.append(item);
	}

	private void ensure_sources()
	{
		if (d_has_sourced)
		{
			return;
		}

		d_has_sourced = true;

		if (!available)
		{
			return;
		}

		// Allow merging from remotes and other local branches, offer
		// to merge upstream first.
		d_upstream = upstream_reference();

		d_local_sources = new Gitg.Ref[0];
		d_remote_sources = new RemoteSource[0];
		d_tag_sources = new Gitg.Ref[0];

		Ggit.OId? target_oid = null;

		try
		{
			target_oid = reference.resolve().get_target();
		} catch {}

		string? last_remote = null;

		foreach (var r in action_interface.references)
		{
			if (d_upstream != null && r.get_name() == d_upstream.get_name())
			{
				continue;
			}

			// Filter out things where merging is a noop
			if (target_oid != null)
			{
				Ggit.OId? oid = null;

				try
				{
					oid = r.resolve().get_target();
				} catch {}

				if (oid != null && oid.equal(target_oid))
				{
					continue;
				}
			}

			if (r.is_branch())
			{
				d_local_sources += r;
			}
			else if (r.is_tag())
			{
				d_tag_sources += r;
			}
			else if (r.parsed_name.rtype == RefType.REMOTE)
			{
				var remote_name = r.parsed_name.remote_name;

				if (remote_name != last_remote)
				{
					var source = RemoteSource() {
						name = remote_name,
						sources = new Gitg.Ref[] { r }
					};

					d_remote_sources += source;
				}
				else
				{
					d_remote_sources[d_remote_sources.length - 1].sources += r;
				}

				last_remote = remote_name;
			}
		}
	}

	public void populate_menu(Gtk.Menu menu)
	{
		if (!available)
		{
			return;
		}

		var item = new Gtk.MenuItem.with_label(display_name);
		item.tooltip_text = description;

		if (enabled)
		{
			var submenu = new Gtk.Menu();
			submenu.show();

			if (d_upstream != null)
			{
				add_merge_source(submenu, d_upstream);
			}

			if (d_local_sources.length != 0)
			{
				if (d_upstream != null)
				{
					// Add a separator
					add_merge_source(submenu, null);
				}

				foreach (var source in d_local_sources)
				{
					add_merge_source(submenu, source);
				}
			}

			if (d_remote_sources.length != 0)
			{
				if (d_local_sources.length != 0 || d_upstream != null)
				{
					// Add a separator
					add_merge_source(submenu, null);
				}

				foreach (var remote in d_remote_sources)
				{
					var subitem = new Gtk.MenuItem.with_label(remote.name);
					subitem.show();

					var subsubmenu = new Gtk.Menu();
					subsubmenu.show();

					foreach (var source in remote.sources)
					{
						add_merge_source(subsubmenu, source);
					}

					subitem.submenu = subsubmenu;
					submenu.append(subitem);
				}
			}

			if (d_tag_sources.length != 0)
			{
				if (d_remote_sources.length != 0 || d_local_sources.length != 0 || d_upstream != null)
				{
					// Add a separator
					add_merge_source(submenu, null);
				}

				var subitem = new Gtk.MenuItem.with_label(_("Tags"));
				subitem.show();

				var subsubmenu = new Gtk.Menu();
				subsubmenu.show();

				foreach (var source in d_tag_sources)
				{
					add_merge_source(subsubmenu, source);
				}

				subitem.submenu = subsubmenu;
				submenu.append(subitem);
			}

			item.submenu = submenu;
		}
		else
		{
			item.sensitive = false;
		}

		item.show();
		menu.append(item);
	}
}

}

// ex:set ts=4 noet
