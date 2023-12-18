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

class RefActionCheckout : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Ref reference { get; construct set; }

	public RefActionCheckout(GitgExt.Application        application,
	                         GitgExt.RefActionInterface action_interface,
	                         Gitg.Ref                   reference)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       reference:        reference);
	}

	public string id
	{
		owned get { return "/org/gnome/gitg/ref-actions/checkout"; }
	}

	public string display_name
	{
		owned get { return _("Checkout"); }
	}

	public string description
	{
		owned get { return _("Checkout the selected reference"); }
	}

	public bool enabled
	{
		get
		{
			try
			{
				return (reference.is_branch() && !((Ggit.Branch)reference).is_head()) || reference.is_remote();
			} catch {}

			return false;
		}
	}

	public async bool checkout()
	{
		var repo = application.repository;
		var notification = new SimpleNotification(_("Checkout “%s”").printf(reference.parsed_name.shortname));
		bool retval = false;

		application.notifications.add(notification);

		try
		{
			yield Async.thread(() => {
				Commit commit;

				try
				{
					commit = reference.resolve().lookup() as Gitg.Commit;
				}
				catch (Error e)
				{
					notification.error(_("Failed to lookup commit: %s").printf(e.message));
					return;
				}

				try
				{
					var opts = new Ggit.CheckoutOptions();
					opts.set_strategy(Ggit.CheckoutStrategy.SAFE);

					repo.checkout_tree(commit.get_tree(), opts);
				}
				catch (Error e)
				{
					notification.error(_("Failed to checkout branch: %s").printf(e.message));
					return;
				}

				try
				{
					repo.set_head(reference.get_name());
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
			notification.success(_("Successfully checked out branch to working directory"));
			action_interface.refresh();
		}

		return retval;
	}

	public void activate()
	{
		if (reference.is_branch())
		{
			checkout.begin();
		}
		else if (reference.is_remote())
		{
			var dlg = new CheckoutRemoteBranchDialog((Gtk.Window)application, application.repository, reference);
			dlg.response.connect((d, resp) => {
				on_checkout_remote_branch_dialog_response(dlg, resp);
			});

			dlg.show();
		}
	}

	private void on_checkout_remote_branch_dialog_response(Gitg.CheckoutRemoteBranchDialog dialog, int response_id) {
		if (response_id != Gtk.ResponseType.OK)
		{
			dialog.destroy();
			return;
		}

		string? remote_branch_name = dialog.track_remote ? dialog.remote_branch_name : null;

		create_branch.begin(reference, dialog.new_branch_name, remote_branch_name, (obj, res) => {
			var branch_ref = create_branch.end(res) as Gitg.Ref;

			if (branch_ref != null)
			{
				action_interface.add_ref(branch_ref);
				reference = branch_ref;
				checkout.begin();
				dialog.destroy();
			}
		});
	}

	private async Ggit.Branch? create_branch(Ggit.Ref reference, string new_branch_name, string? remote_branch_name)
	{
		Ggit.Branch? branch = null;

		var repo = application.repository;

		try
		{
			Gitg.Commit commit = reference.lookup() as Gitg.Commit;
			branch = repo.create_branch(new_branch_name,
			                            commit,
			                            Ggit.CreateFlags.NONE);
		}
		catch (Error e)
		{
			application.show_infobar(_("Failed to create branch"),
			                         e.message,
			                         Gtk.MessageType.ERROR);
		}

		if (branch != null)
		{
			if (remote_branch_name != null) {
				try
				{
					branch.set_upstream(remote_branch_name);
				}
				catch (Error e)
				{
					application.show_infobar(
					   _("Failed to set the upstream branch %s for %s").printf(remote_branch_name,
					   new_branch_name),
					   e.message,
					   Gtk.MessageType.ERROR);
				}
			}
		}

		return branch;
	}
}

}

// ex:set ts=4 noet
