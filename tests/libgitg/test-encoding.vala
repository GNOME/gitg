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

class LibGitg.Test.Encoding : Gitg.Test.Repository
{
	/**
	 * Create basic repository with files in a variety of states.
	 */
	protected override void set_up()
	{
		base.set_up();

		d_repository.get_config().set_string("i18n.commitencoding", "KOI8-R");

		index_modify("b", "staged changes\n");
		index_modify("a", "lala\n");
	}

	/**
	 * test commit.
	 */
	protected virtual signal void test_commit_encoding()
	{
		var stage = d_repository.stage;
		var loop = new MainLoop();

		var sig = new Ggit.Signature.now("Jesse van den Kieboom",
		                                 "jessevdk@gnome.org");

		var msg = "This is the commit\n\nWith some cyЯЯilic.\n";

		stage.commit.begin(msg,
		                   sig,
		                   sig,
		                   Gitg.StageCommitOptions.NONE, (obj, res) => {

			var oid = stage.commit.end(res);
			var commit = d_repository.lookup<Gitg.Commit>(oid);

			assert_streq(commit.get_message(), msg);

			loop.quit();
		});

		loop.run();
	}
}

// ex:set ts=4 noet
