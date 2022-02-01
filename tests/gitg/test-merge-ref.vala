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

using Gitg.Test.Assert;

class Gitg.Test.MergeRef : Application
{
	private Gitg.Branch ours;
	private Gitg.Branch theirs;
	private Gitg.Branch master;
	private Gitg.Branch not_master;

	private RefActionInterface action_interface;
	private RefActionCheckout action;

	protected override void set_up()
	{
		base.set_up();

		commit("a", "a file\n");
		create_branch("theirs");

		commit("b", "b file\n");

		checkout_branch("theirs");
		commit("c", "c file\n");

		theirs = lookup_branch("theirs");

		checkout_branch("master");
		not_master = create_branch("not_master");

		master = lookup_branch("master");

		action_interface = new RefActionInterface(this);
	}

	private void assert_merged(Ggit.OId ours, Ggit.OId theirs, string name)
	{
		var now_commit = lookup_commit(name);

		var parents = now_commit.get_parents();
		assert_uinteq(parents.size, 2);

		assert_streq(parents[0].get_id().to_string(), ours.to_string());
		assert_streq(parents[1].get_id().to_string(), theirs.to_string());
	}

	protected virtual signal void test_merge_simple()
	{
		var loop = new MainLoop();
		var action = new Gitg.RefActionMerge(this, action_interface, master);

		var ours_oid = lookup_commit("master").get_id();
		var theirs_oid = theirs.get_target();

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “master”");
		assert_streq(simple_notifications[0].message, "Successfully merged “theirs” into “master”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "c file\n");

		assert_merged(ours_oid, theirs_oid, "master");
	}

	protected virtual signal void test_merge_not_head()
	{
		var loop = new MainLoop();
		var action = new Gitg.RefActionMerge(this, action_interface, not_master);

		var ours_oid = not_master.get_target();
		var theirs_oid = theirs.get_target();

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “not_master”");
		assert_streq(simple_notifications[0].message, "Successfully merged “theirs” into “not_master”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_true(!file_exists("c"));

		assert_merged(ours_oid, theirs_oid, "not_master");
	}

	protected virtual signal void test_merge_not_head_would_have_conflicted()
	{
		var loop = new MainLoop();

		commit("c", "c file other content\n");

		var ours_oid = not_master.get_target();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, not_master);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “not_master”");
		assert_streq(simple_notifications[0].message, "Successfully merged “theirs” into “not_master”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "c file other content\n");

		assert_merged(ours_oid, theirs_oid, "not_master");
	}

	protected virtual signal void test_merge_theirs_conflicts_no_checkout()
	{
		var loop = new MainLoop();

		commit("c", "c file other content\n");

		var ours_oid = lookup_commit("master").get_id();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, master);

		expect_user_query(new GitgExt.UserQuery.full("Merge has conflicts",
		                                            "The merge of “theirs” into “master” has caused conflicts, would you like to checkout branch “master” with the merge to your working directory to resolve the conflicts?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Checkout",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.CANCEL);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “master”");
		assert_streq(simple_notifications[0].message, "Merge failed with conflicts");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.ERROR);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "c file other content\n");
	}

	protected virtual signal void test_merge_theirs_conflicts_checkout()
	{
		var loop = new MainLoop();

		commit("c", "c file other content\n");

		var ours_oid = lookup_commit("master").get_id();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, master);

		expect_user_query(new GitgExt.UserQuery.full("Merge has conflicts",
		                                             "The merge of “theirs” into “master” has caused conflicts, would you like to checkout branch “master” with the merge to your working directory to resolve the conflicts?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Checkout",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “master”");
		assert_streq(simple_notifications[0].message, "Finished merge with conflicts in working directory");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "<<<<<<< ours\nc file other content\n=======\nc file\n>>>>>>> theirs\n");

		assert_file_contents(".git/ORIG_HEAD", "e1219dd5fbcf8fb5b17bbd3db7a9fa88e98d6651\n");
		assert_file_contents(".git/MERGE_HEAD", "72af7ccf47852d832b06c7244de8ae9ded639024\n");
		assert_file_contents(".git/MERGE_MODE", "no-ff\n");
		assert_file_contents(".git/MERGE_MSG", "Merge branch “theirs”\n\nConflicts:\n\tc\n");
	}

	protected virtual signal void test_merge_theirs_dirty_stash()
	{
		var loop = new MainLoop();

		write_file("b", "b file other content\n");

		var ours_oid = lookup_commit("master").get_id();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, master);

		expect_user_query(new GitgExt.UserQuery.full("Unstaged changes",
		                                             "You appear to have unstaged changes in your working directory. Would you like to stash the changes before the checkout?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Stash changes",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Merge “theirs” into “master”");
		assert_streq(simple_notifications[0].message, "Successfully merged “theirs” into “master”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "c file\n");

		var messages = new string[0];
		var oids = new Ggit.OId[0];

		d_repository.stash_foreach((index, message, oid) => {
			messages += message;
			oids += oid;

			return 0;
		});

		assert_merged(ours_oid, theirs_oid, "master");

		assert_inteq(messages.length, 1);
		assert_streq(messages[0], "On master: WIP on HEAD: 50ac9b commit b");
		assert_streq(oids[0].to_string(), "aaf63a72d8c0d5799ccfcf1623daef228968382f");
	}

	protected virtual signal void test_merge_theirs_not_master_conflicts_checkout()
	{
		var loop = new MainLoop();

		checkout_branch("not_master");
		commit("c", "c file other content\n");
		not_master = lookup_branch("not_master");
		checkout_branch("master");

		var ours_oid = not_master.get_target();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, not_master);

		expect_user_query(new GitgExt.UserQuery.full("Merge has conflicts",
		                                             "The merge of “theirs” into “not_master” has caused conflicts, would you like to checkout the merge to your working directory to resolve the conflicts?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Checkout",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		expect_user_query(new GitgExt.UserQuery.full("Unstaged changes",
		                                             "You appear to have unstaged changes in your working directory. Would you like to stash the changes before the checkout?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Stash changes",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 2);

		assert_streq(simple_notifications[0].title, "Merge “theirs” into “not_master”");
		assert_streq(simple_notifications[0].message, "Finished merge with conflicts in working directory");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_streq(simple_notifications[1].title, "Checkout “not_master”");
		assert_streq(simple_notifications[1].message, "Successfully checked out branch to working directory");
		assert_inteq(simple_notifications[1].status, SimpleNotification.Status.SUCCESS);

		assert_streq(lookup_branch("HEAD").get_name(), "refs/heads/not_master");

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "<<<<<<< ours\nc file other content\n=======\nc file\n>>>>>>> theirs\n");

		assert_file_contents(".git/ORIG_HEAD", "e1219dd5fbcf8fb5b17bbd3db7a9fa88e98d6651\n");
		assert_file_contents(".git/MERGE_HEAD", "72af7ccf47852d832b06c7244de8ae9ded639024\n");
		assert_file_contents(".git/MERGE_MODE", "no-ff\n");
		assert_file_contents(".git/MERGE_MSG", "Merge branch “theirs”\n\nConflicts:\n\tc\n");
	}

	protected virtual signal void test_merge_theirs_not_master_conflicts_checkout_dirty()
	{
		var loop = new MainLoop();

		checkout_branch("not_master");
		commit("c", "c file other content\n");
		not_master = lookup_branch("not_master");
		checkout_branch("master");

		write_file("b", "b file other content\n");

		var ours_oid = not_master.get_target();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, not_master);

		expect_user_query(new GitgExt.UserQuery.full("Merge has conflicts",
		                                             "The merge of “theirs” into “not_master” has caused conflicts, would you like to checkout the merge to your working directory to resolve the conflicts?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Checkout",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		expect_user_query(new GitgExt.UserQuery.full("Unstaged changes",
		                                             "You appear to have unstaged changes in your working directory. Would you like to stash the changes before the checkout?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Stash changes",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 2);

		assert_streq(simple_notifications[0].title, "Merge “theirs” into “not_master”");
		assert_streq(simple_notifications[0].message, "Finished merge with conflicts in working directory");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);

		assert_streq(simple_notifications[1].title, "Checkout “not_master”");
		assert_streq(simple_notifications[1].message, "Successfully checked out branch to working directory");
		assert_inteq(simple_notifications[1].status, SimpleNotification.Status.SUCCESS);

		assert_streq(lookup_branch("HEAD").get_name(), "refs/heads/not_master");

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file\n");
		assert_file_contents("c", "<<<<<<< ours\nc file other content\n=======\nc file\n>>>>>>> theirs\n");

		assert_file_contents(".git/ORIG_HEAD", "e1219dd5fbcf8fb5b17bbd3db7a9fa88e98d6651\n");
		assert_file_contents(".git/MERGE_HEAD", "72af7ccf47852d832b06c7244de8ae9ded639024\n");
		assert_file_contents(".git/MERGE_MODE", "no-ff\n");
		assert_file_contents(".git/MERGE_MSG", "Merge branch “theirs”\n\nConflicts:\n\tc\n");

		var messages = new string[0];
		var oids = new Ggit.OId[0];

		d_repository.stash_foreach((index, message, oid) => {
			messages += message;
			oids += oid;

			return 0;
		});

		assert_inteq(messages.length, 1);
		assert_streq(messages[0], "On master: WIP on HEAD");
		assert_streq(oids[0].to_string(), "147b7b7b6ad2f9c90f4c93f3bfda78c78ec2dcde");
	}

	protected virtual signal void test_merge_theirs_not_master_conflicts_checkout_dirty_no_stash()
	{
		var loop = new MainLoop();

		checkout_branch("not_master");
		commit("c", "c file other content\n");
		not_master = lookup_branch("not_master");
		checkout_branch("master");

		write_file("b", "b file other content\n");

		var ours_oid = not_master.get_target();
		var theirs_oid = theirs.get_target();

		var action = new Gitg.RefActionMerge(this, action_interface, not_master);

		expect_user_query(new GitgExt.UserQuery.full("Merge has conflicts",
		                                             "The merge of “theirs” into “not_master” has caused conflicts, would you like to checkout the merge to your working directory to resolve the conflicts?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Checkout",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.OK);

		expect_user_query(new GitgExt.UserQuery.full("Unstaged changes",
		                                             "You appear to have unstaged changes in your working directory. Would you like to stash the changes before the checkout?",
		                                             Gtk.MessageType.QUESTION,
		                                             "Cancel",
		                                             Gtk.ResponseType.CANCEL,
		                                             "Stash changes",
		                                             Gtk.ResponseType.OK),
		                       Gtk.ResponseType.CANCEL);

		action.merge.begin(theirs, (obj, res) => {
			action.merge.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);

		assert_streq(simple_notifications[0].title, "Merge “theirs” into “not_master”");
		assert_streq(simple_notifications[0].message, "Failed with conflicts");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.ERROR);

		assert_streq(lookup_branch("HEAD").get_name(), "refs/heads/master");

		assert_file_contents("a", "a file\n");
		assert_file_contents("b", "b file other content\n");
		assert(!file_exists("c"));

		assert(!file_exists(".git/ORIG_HEAD"));
		assert(!file_exists(".git/MERGE_HEAD"));
		assert(!file_exists(".git/MERGE_MODE"));
		assert(!file_exists(".git/MERGE_MSG"));

		d_repository.stash_foreach((index, message, oid) => {
			assert(false);
			return 0;
		});
	}
}

// ex:set ts=4 noet
