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

class Gitg.Test.Stage : Gitg.Test.Repository
{
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

	protected virtual signal void test_index_files()
	{
		var stage = d_repository.get_stage();
		var e = stage.file_status();

		var loop = new GLib.MainLoop();

		e.next_files.begin(-1, (obj, res) => {
			var files = e.next_files.end(res);

			assert(files.length == 3);

			foreach (var f in files)
			{
				assert(f.path == "a" || f.path == "b" || f.path == "c");

				switch (f.path)
				{
				case "a":
					assert(f.flags == Ggit.StatusFlags.WORKING_TREE_MODIFIED);
					break;
				case "b":
					assert(f.flags == (Ggit.StatusFlags.WORKING_TREE_MODIFIED |
					                   Ggit.StatusFlags.INDEX_MODIFIED));
					break;
				case "c":
					assert(f.flags == Ggit.StatusFlags.WORKING_TREE_DELETED);
					break;
				}
			}

			loop.quit();
		});

		loop.run();
	}
}

// ex:set ts=4 noet
