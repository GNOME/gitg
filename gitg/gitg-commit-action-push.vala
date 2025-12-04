/*
 * This file is part of gitg
 *
 * Copyright (C) 2025 - Alberto Fanjul
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

class CommitActionPush : GitgExt.UIElement, GitgExt.Action, GitgExt.CommitAction, Object
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	public GitgExt.Application? application { owned get; construct set; }
	public GitgExt.RefActionInterface action_interface { get; construct set; }
	public Gitg.Commit commit { get; construct set; }

	public CommitActionPush(GitgExt.Application        application,
	                        GitgExt.RefActionInterface action_interface,
	                        Gitg.Commit                commit)
	{
		Object(application:      application,
		       action_interface: action_interface,
		       commit:           commit);
	}

	public virtual string id
	{
		owned get { return "/org/gnome/gitg/commit-actions/push"; }
	}

	public string display_name
	{
		owned get { return _("Push to…"); }
	}

	public virtual string description
	{
		owned get { return _("Push to remote the selected commit"); }
	}

	public virtual string get_ref_name()
	{
		return commit.get_id().to_string();
	}

	public virtual Object get_ref()
	{
		return commit;
	}

	class PushCallbacks:Ggit.RemoteCallbacks {
		public GitgExt.Application? application { owned get; construct set; }

		public ResultDialog push_dlg;

		public PushCallbacks(GitgExt.Application application)
		{
			Object(application: application);
			push_dlg = new ResultDialog((Gtk.Window)application, _("Push Output"));
			push_dlg.response.connect((d, resp) => {
				push_dlg.destroy();
			});
		}

		public override void progress(string message) {
			if (message == "")
				return;

			push_dlg.append_message(message);

			if (!push_dlg.is_visible()) {
				Idle.add(() => {
					push_dlg.show();
					return false;
				});
			}
		}
	}

	public async bool push(Gitg.Remote remote, bool force, string local_branch, string remote_branch)
	{
		var notification = new RemoteNotification(remote);
		application.notifications.add(notification);

		notification.text = _("Pushing to %s").printf(remote.get_url());

		try
		{
			yield remote.push(force, local_branch, remote_branch, new PushCallbacks(application));
			((Gtk.ApplicationWindow)application).activate_action("reload", null);
		}
		catch (Error e)
		{
			notification.error(_("Failed to push to %s: %s").printf(remote.get_url(), e.message));
			stderr.printf("Failed to push: %s\n", e.message);

			return false;
		}

		/* Translators: the %s will get replaced with the remote url, */
		notification.success(_("Pushed to %s").printf(remote.get_url()));

		return true;
	}

	public virtual void activate()
	{
		var dlg = new PushDialog((Gtk.Window)application, application.repository, get_ref());
		dlg.response.connect(on_push_dialog_response);

		dlg.show();
	}

	private void on_push_dialog_response(Gtk.Dialog dialog, int response_id) {
		var dlg = dialog as Gitg.PushDialog;
		if (response_id != Gtk.ResponseType.OK)
		{
			dlg.destroy();
			return;
		}

		var ref_name = get_ref_name();
		var remote_name = dlg.remote_name;
		var remote_ref_name = dlg.remote_ref_name;
		var remote = application.remote_lookup.lookup(remote_name);
		var remote_ref = dlg.remote_ref;
		var force = dlg.force;
		var set_upstream = dlg.set_upstream;

		bool do_push = false;
		if (force)
		{
			var alert_dialog = new Gtk.MessageDialog((Gtk.Window) application,
					Gtk.DialogFlags.MODAL, Gtk.MessageType.ERROR, Gtk.ButtonsType.NONE,
					_("Push force will rewrite remote ref “%s”. Are you sure?"), remote_ref);
			alert_dialog.add_button(_("Cancel"), Gtk.ResponseType.CANCEL);
			alert_dialog.add_button(_("Push force"), Gtk.ResponseType.OK);

			var push_force_button = alert_dialog.get_widget_for_response(Gtk.ResponseType.OK);
			push_force_button.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

			alert_dialog.response.connect ((r) => {
				if (r == Gtk.ResponseType.OK)
				{
					do_push = true;
				}
				alert_dialog.destroy();
			});

			alert_dialog.run();
		} else {
			do_push = true;
		}

		if (do_push) {
			push.begin(remote, force, ref_name, remote_ref, (obj, res) => {
				if(push.end(res))
					after_successful_push(set_upstream, remote_name, remote_ref_name);
			});
		}
		dlg.destroy();
		finished();
	}

	protected virtual void after_successful_push(bool set_upstream, string remote_name, string
												 remote_ref_name)
	{
	}
}
}

// ex:set ts=4 noet
