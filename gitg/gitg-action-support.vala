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

public class ActionSupport : Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { owned get; construct set; }

	public ActionSupport(GitgExt.Application application, GitgExt.RefActionInterface action_interface)
	{
		Object(application: application, action_interface: action_interface);
	}

	public async bool working_directory_dirty()
	{
		var options = new Ggit.StatusOptions(Ggit.StatusOption.EXCLUDE_SUBMODULES,
		                                     Ggit.StatusShow.WORKDIR_ONLY,
		                                     null);
		var is_dirty = false;

		yield Async.thread_try(() => {
			application.repository.file_status_foreach(options, (path, flags) => {
				is_dirty = true;
				return -1;
			});
		});

		return is_dirty;
	}

	public async bool save_stash(SimpleNotification notification, Gitg.Ref? head)
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

	public bool reference_is_head(Gitg.Ref reference, ref Gitg.Ref? head)
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

	public async bool stash_if_needed(SimpleNotification notification, Gitg.Ref head)
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
				notification.error(_("Failed with conflicts"));
				return false;
			}

			if (!(yield save_stash(notification, head)))
			{
				return false;
			}
		}

		return true;
	}

	public async bool checkout_conflicts(SimpleNotification notification, Gitg.Ref reference, Ggit.Index index, Gitg.Ref? head)
	{
		if (!(yield stash_if_needed(notification, head)))
		{
			return false;
		}

		if (head == null)
		{
			// Perform checkout of the local branch first
			var checkout = new RefActionCheckout(application, action_interface, reference);

			if (!(yield checkout.checkout()))
			{
				notification.error(_("Failed with conflicts"));
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

		return true;
	}

	public async Ggit.OId? commit_index(SimpleNotification notification,
	                                    Gitg.Ref           reference,
	                                    Ggit.Index         index,
	                                    owned Ggit.OId[]?  parents,
	                                    Ggit.Signature?    author,
	                                    string             message)
	{
		var committer = application.get_verified_committer();

		if (committer == null)
		{
			notification.error(_("Failed to obtain author details"));
			return null;
		}

		if (author == null)
		{
			author = committer;
		}

		var stage = application.repository.stage;

		Gitg.Ref? head = null;
		var ishead = reference_is_head(reference, ref head);

		Ggit.OId? oid = null;
		Ggit.Tree? head_tree = null;
		Gitg.Commit? commit = null;

		try
		{
			commit = reference.lookup() as Gitg.Commit;
		}
		catch (Error e)
		{
			notification.error(_("Failed to lookup commit: %s").printf(e.message));
			return null;
		}

		if (ishead)
		{
			if (!(yield stash_if_needed(notification, head)))
			{
				return null;
			}

			head_tree = commit.get_tree();
		}

		if (parents == null)
		{
			parents = new Ggit.OId[] { commit.get_id() };
		}

		try
		{
			// TODO: not all hooks are being executed yet
			oid = yield stage.commit_index(index,
			                               ishead ? head : reference,
			                               message,
			                               author,
			                               committer,
			                               parents,
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

					var newcommit = application.repository.lookup<Ggit.Commit>(oid);
					var newtree = newcommit.get_tree();

					application.repository.checkout_tree(newtree, opts);
				});
			}
			catch (Error e)
			{
				notification.error(_("Failed to checkout index: %s").printf(e.message));
				return null;
			}
		}

		return oid;
	}
}

}

// ex:set ts=4 noet
