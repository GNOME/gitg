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

using Gitg.Test;
using Gitg.Test.Assert;

class LibGitg.Test.Stage : Gitg.Test.Repository
{
	/**
	 * Create basic repository with files in a variety of states.
	 */
	protected override void set_up()
	{
		base.set_up();

		// Configure repository
		commit("a", "hello world\n",
		       "b", "gitg test file\n",
		       "c", "hello\n");

		workdir_remove("c");
		workdir_modify("a", "changed world\n");
		workdir_modify("b", "changed test\n");

		index_modify("b", "staged changes\n");
	}

	private void check_file_status(MainLoop loop, Gee.HashMap<string, Ggit.StatusFlags> cfiles)
	{
		var seen = new Gee.HashSet<string>();

		foreach (var f in cfiles.keys)
		{
			seen.add(f);
		}

		var stage = d_repository.stage;
		var e = stage.file_status(null);

		e.next_items.begin(-1, (obj, res) => {
			var items = e.next_items.end(res);

			assert(items.length == cfiles.size);

			foreach (var item in items)
			{
				var f = item as Gitg.StageStatusFile;

				assert(cfiles.has_key(f.path));
				assert_inteq(cfiles[f.path], f.flags);

				seen.remove(f.path);
			}

			assert(seen.size == 0);
			loop.quit();
		});
	}

	/**
	 * Test whether the different file statuses created by the set_up()
	 * are properly reported by the stage file status enumerator.
	 */
	protected virtual signal void test_file_status()
	{
		var m = new Gee.HashMap<string, Ggit.StatusFlags>();

		m["a"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
		m["b"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED | Ggit.StatusFlags.INDEX_MODIFIED;
		m["c"] = Ggit.StatusFlags.WORKING_TREE_DELETED;

		var loop = new GLib.MainLoop();

		check_file_status(loop, m);
		loop.run();
	}

	/**
	 * test staging a complete file in the index.
	 */
	protected virtual signal void test_stage()
	{
		var stage = d_repository.stage;

		var loop = new MainLoop();

		stage.stage_path.begin("a", (obj, res) => {
			try
			{
				stage.stage_path.end(res);
			} catch (Error e) { Assert.assert_no_error(e); }

			var m = new Gee.HashMap<string, Ggit.StatusFlags>();

			m["a"] = Ggit.StatusFlags.INDEX_MODIFIED;
			m["b"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED | Ggit.StatusFlags.INDEX_MODIFIED;
			m["c"] = Ggit.StatusFlags.WORKING_TREE_DELETED;

			check_file_status(loop, m);
		});

		loop.run();
	}

	/**
	 * test staging a complete file in the index.
	 */
	protected virtual signal void test_unstage()
	{
		var stage = d_repository.stage;

		var loop = new MainLoop();

		stage.unstage_path.begin("b", (obj, res) => {
			try
			{
				stage.unstage_path.end(res);
			} catch (Error e) { Assert.assert_no_error(e); }

			var m = new Gee.HashMap<string, Ggit.StatusFlags>();

			m["a"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
			m["b"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
			m["c"] = Ggit.StatusFlags.WORKING_TREE_DELETED;

			check_file_status(loop, m);
		});

		loop.run();
	}

	/**
	 * test reverting a complete file in the index.
	 */
	protected virtual signal void test_revert()
	{
		var stage = d_repository.stage;

		var loop = new MainLoop();

		stage.revert_path.begin("a", (obj, res) => {
			try
			{
				stage.revert_path.end(res);
			} catch (Error e) { Assert.assert_no_error(e); }

			var m = new Gee.HashMap<string, Ggit.StatusFlags>();

			m["b"] = Ggit.StatusFlags.INDEX_MODIFIED | Ggit.StatusFlags.WORKING_TREE_MODIFIED;
			m["c"] = Ggit.StatusFlags.WORKING_TREE_DELETED;

			check_file_status(loop, m);
		});

		loop.run();
	}

	/**
	 * test deleting a file in the index.
	 */
	protected virtual signal void test_delete()
	{
		var stage = d_repository.stage;

		var loop = new MainLoop();

		stage.delete_path.begin("c", (obj, res) => {
			try
			{
				stage.delete_path.end(res);
			} catch (Error e) { Assert.assert_no_error(e); }

			var m = new Gee.HashMap<string, Ggit.StatusFlags>();

			m["a"] = Ggit.StatusFlags.WORKING_TREE_MODIFIED;
			m["b"] = Ggit.StatusFlags.INDEX_MODIFIED | Ggit.StatusFlags.WORKING_TREE_MODIFIED;
			m["c"] = Ggit.StatusFlags.INDEX_DELETED;

			check_file_status(loop, m);
		});

		loop.run();
	}
}

// ex:set ts=4 noet
