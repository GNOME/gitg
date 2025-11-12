/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

class CommitActionCheckout : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }

	public CommitActionCheckout(GitgExt.Application        application,
	                            GitgExt.RefActionInterface action_interface,
	                            Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);
	}

	public virtual string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/checkout"; }
	}

	public string display_name
	{
		owned get { return _("Checkout detached"); }
	}

	public virtual string description
	{
		owned get { return _("Checkout at selected commit"); }
	}

	public void activate()
	{
		checkout.begin();
	}

	public async bool checkout()
	{
		var repo = application.repository;
		var notification = new SimpleNotification(_("Checkout “%s”").printf(commit.get_id().to_string()));
		bool retval = false;

		application.notifications.add(notification);

		try
		{
			yield Async.thread(() => {
				try
				{
					var opts = new Ggit.CheckoutOptions();
					opts.set_strategy(Ggit.CheckoutStrategy.SAFE);

					repo.checkout_tree(commit.get_tree(), opts);
				}
				catch (Error e)
				{
					notification.error(_("Failed to checkout commit: %s").printf(e.message));
					return;
				}

				try
				{
					repo.set_head_detached(commit.get_id());
				}
				catch (Error e)
				{
					notification.error(_("Failed to update HEAD: %s").printf(e.message));
					return;
				}

				retval = true;
			});
		} catch {}

		if (retval)
		{
			notification.success(_("Successfully checked out commit to working directory"));
			application.repository_commits_changed();
		}

		return retval;
	}
}

}

// ex:set ts=4 noet
