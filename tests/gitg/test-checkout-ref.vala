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

class Gitg.Test.CheckoutRef : Application
{
	private Gitg.Branch the_branch;
	private RefActionInterface action_interface;
	private RefActionCheckout action;

	protected override void set_up()
	{
		base.set_up();

		commit("b", "staged changes\n");
		commit("a", "lala\n");

		the_branch = create_branch("thebranch");

		commit("a", "changed?\n");

		action_interface = new RefActionInterface(this);
		action = new Gitg.RefActionCheckout(this, action_interface, the_branch);
	}

	/**
	 * test basic branch checkout.
	 */
	protected virtual signal void test_checkout_branch()
	{
		var loop = new MainLoop();

		action.checkout.begin((obj, res) => {
			action.checkout.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Checkout “thebranch”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);
		assert_streq(simple_notifications[0].message, "Successfully checked out branch to working directory");
		assert_file_contents("a", "lala\n");
	}

	protected virtual signal void test_checkout_branch_safe()
	{
		write_file("b", "something changed\n");

		var loop = new MainLoop();

		action.checkout.begin((obj, res) => {
			action.checkout.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Checkout “thebranch”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.SUCCESS);
		assert_streq(simple_notifications[0].message, "Successfully checked out branch to working directory");
		assert_file_contents("b", "something changed\n");
	}

	protected virtual signal void test_checkout_branch_conflict()
	{
		write_file("a", "something changed\n");

		var loop = new MainLoop();

		action.checkout.begin((obj, res) => {
			action.checkout.end(res);
			loop.quit();
		});

		loop.run();

		assert_inteq(simple_notifications.size, 1);
		assert_streq(simple_notifications[0].title, "Checkout “thebranch”");
		assert_inteq(simple_notifications[0].status, SimpleNotification.Status.ERROR);
		assert_streq(simple_notifications[0].message, "Failed to checkout branch: 1 conflict prevents checkout");
		assert_file_contents("a", "something changed\n");
	}
}

// ex:set ts=4 noet
