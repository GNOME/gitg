/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

class LibGitg.Test.Commit : Gitg.Test.Repository
{
	/**
	 * Create basic repository with files in a variety of states.
	 */
	protected override void set_up()
	{
		base.set_up();

		index_modify("b", "staged changes\n");
		index_modify("a", "lala\n");
	}

	/**
	 * test commit.
	 */
	protected virtual signal void test_commit()
	{
		var stage = d_repository.stage;
		var loop = new MainLoop();

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		var msg = "This is the commit\n\nWith a message.\n";

		stage.commit.begin(msg,
		                   sig,
		                   sig,
		                   Gitg.StageCommitOptions.NONE, (obj, res) => {

			var oid = stage.commit.end(res);
			var commit = d_repository.lookup<Gitg.Commit>(oid);

			assert_streq(commit.get_author().get_name(), sig.get_name());
			assert_streq(commit.get_author().get_email(), sig.get_email());

			assert_streq(commit.get_committer().get_name(), sig.get_name());
			assert_streq(commit.get_committer().get_email(), sig.get_email());

			assert_streq(commit.get_message(), msg);
			assert_streq(commit.get_subject(), "This is the commit");

			assert_streq(d_repository.get_head().get_target().to_string(),
			             oid.to_string());

			var reflog = d_repository.lookup_reference("HEAD").get_log();
			var entry = reflog.get_entry_from_index(0);

			assert_streq(entry.get_new_id().to_string(), oid.to_string());
			assert_streq(entry.get_message(), "commit: This is the commit");

			loop.quit();
		});

		loop.run();
	}

	protected virtual signal void test_sign_off()
	{
		var stage = d_repository.stage;
		var loop = new MainLoop();

		var author = new Ggit.Signature.now("Jesse",
		                                    "jessevdk@gnome.org");

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gmail.com");

		var msg = "This is the commit\n\nWith a message.\n";

		stage.commit.begin(msg,
		                   author,
		                   sig,
		                   Gitg.StageCommitOptions.SIGN_OFF, (obj, res) => {

			var oid = stage.commit.end(res);

			var commit = d_repository.lookup<Gitg.Commit>(oid);

			assert_streq(commit.get_author().get_name(), author.get_name());
			assert_streq(commit.get_author().get_email(), author.get_email());

			assert_streq(commit.get_committer().get_name(), sig.get_name());
			assert_streq(commit.get_committer().get_email(), sig.get_email());

			assert_streq(commit.get_message(), msg + "\nSigned-off-by: Jesse van den Kieboom <jessevdk@gmail.com>\n");

			loop.quit();
		});

		loop.run();
	}

	private void setup_failing_pre_commit_hook()
	{
		var hookdir = d_repository.get_location().get_child("hooks");
		var pc = hookdir.get_child("pre-commit").get_path();

		assert(FileUtils.set_contents(pc, "#!/bin/bash\n\necho 'pre-commit failed'; exit 1;\n"));
		assert_inteq(FileUtils.chmod(pc, 0744), 0);
	}

	protected virtual signal void test_pre_commit_hook()
	{
		setup_failing_pre_commit_hook();

		var stage = d_repository.stage;
		var loop = new MainLoop();

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		stage.pre_commit_hook.begin(sig, (obj, res) => {
			Gitg.StageError? e = null;

			try
			{
				stage.pre_commit_hook.end(res);
			}
			catch (Gitg.StageError err)
			{
				e = err;
			}

			assert(e != null);
			assert(e is Gitg.StageError.PRE_COMMIT_HOOK_FAILED);
			assert_streq(e.message, "pre-commit failed");

			loop.quit();
		});

		loop.run();
	}

	protected virtual signal void test_commit_msg_hook()
	{
		var hookdir = d_repository.get_location().get_child("hooks");
		var pc = hookdir.get_child("commit-msg").get_path();

		assert(FileUtils.set_contents(pc, "#!/bin/bash\n\necho 'override message' > $1\n"));
		assert_inteq(FileUtils.chmod(pc, 0744), 0);

		var stage = d_repository.stage;
		var loop = new MainLoop();

		var msg = "original message\n";

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		stage.commit.begin(msg,
		                   sig,
		                   sig,
		                   Gitg.StageCommitOptions.NONE, (obj, res) => {
			var oid = stage.commit.end(res);

			var commit = d_repository.lookup<Gitg.Commit>(oid);
			assert_streq(commit.get_message(), "override message\n");

			loop.quit();
		});

		loop.run();
	}

	protected virtual signal void test_skip_hooks()
	{
		var hookdir = d_repository.get_location().get_child("hooks");
		var pc = hookdir.get_child("commit-msg").get_path();

		assert(FileUtils.set_contents(pc, "#!/bin/bash\n\necho 'override message' > $1\n"));
		assert_inteq(FileUtils.chmod(pc, 0744), 0);

		var stage = d_repository.stage;
		var loop = new MainLoop();

		var msg = "original message\n";

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		stage.commit.begin(msg,
		                   sig,
		                   sig,
		                   Gitg.StageCommitOptions.SKIP_HOOKS, (obj, res) => {
			var oid = stage.commit.end(res);

			var commit = d_repository.lookup<Gitg.Commit>(oid);
			assert_streq(commit.get_message(), "original message\n");

			loop.quit();
		});

		loop.run();
	}

	protected virtual signal void test_amend()
	{
		commit("a", "lala\n",
		       "b", "for real\n");

		var stage = d_repository.stage;
		var loop = new MainLoop();

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		var headoid = d_repository.get_head().get_target();
		var headc = d_repository.lookup<Ggit.Commit>(headoid);

		var msg = "This is the commit\n\nWith a message.\n";

		stage.commit.begin(msg,
		                   headc.get_author(),
		                   sig,
		                   Gitg.StageCommitOptions.AMEND, (obj, res) => {

			var oid = stage.commit.end(res);
			var commit = d_repository.lookup<Gitg.Commit>(oid);

			assert_streq(commit.get_author().get_name(), "gitg tester");
			assert_streq(commit.get_author().get_email(), "gitg-tester@gnome.org");

			assert_streq(commit.get_committer().get_name(), sig.get_name());
			assert_streq(commit.get_committer().get_email(), sig.get_email());

			assert_streq(commit.get_message(), msg);
			assert_streq(commit.get_subject(), "This is the commit");

			assert_streq(d_repository.get_head().get_target().to_string(),
			             oid.to_string());

			assert_uinteq(commit.get_parents().size, 0);

			var reflog = d_repository.lookup_reference("HEAD").get_log();
			var entry = reflog.get_entry_from_index(0);

			assert_streq(entry.get_new_id().to_string(), oid.to_string());
			assert_streq(entry.get_message(), "commit (amend): This is the commit");

			loop.quit();
		});

		loop.run();
	}

}

// ex:set ts=4 noet
