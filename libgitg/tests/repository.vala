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

class Gitg.Test.Repository : Gitg.Test.Test
{
	protected Gitg.Repository? d_repository;
	private Ggit.Commit? d_last_commit;

	struct File
	{
		public string filename;
		public string? contents;
	}

	private File[] files_from_varargs(string? filename, va_list l)
	{
		File[] files = new File[] {};

		while (filename != null)
		{
			string contents = l.arg();

			files += File() {
				filename = filename,
				contents = contents
			};

			filename = l.arg();
		}

		return files;
	}

	private File[] filenames_from_varargs(string? filename, va_list l)
	{
		File[] files = new File[] {};

		while (filename != null)
		{
			files += File() {
				filename = filename,
				contents = null
			};

			filename = l.arg();
		}

		return files;
	}

	private void write_files(File[] files)
	{
		var wd = d_repository.get_workdir();

		foreach (var f in files)
		{
			var fp = wd.get_child(f.filename);

			try
			{
				var os = fp.replace(null, false, GLib.FileCreateFlags.NONE, null);
				os.write(f.contents.data);
				os.close();
			}
			catch (GLib.Error e)
			{
				assert_no_error(e);
			}
		}
	}

	protected void commit(string? filename, ...)
	{
		if (d_repository == null)
		{
			return;
		}

		var files = files_from_varargs(filename, va_list());
		write_files(files);

		// use the index to stage the files

		Ggit.Index index;

		try
		{
			index = d_repository.get_index();
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		foreach (var f in files)
		{
			try
			{
				index.add_path(f.filename);
			}
			catch (GLib.Error e)
			{
				assert_no_error(e);
			}
		}

		Ggit.OId treeoid;

		try
		{
			index.write();
			treeoid = index.write_tree();
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		// create commit
		Ggit.Signature sig;

		try
		{
			sig = new Ggit.Signature.now("gitg tester",
			                             "gitg-tester@gnome.org");
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		Ggit.Tree tree;

		try
		{
			tree = d_repository.lookup<Ggit.Tree>(treeoid); 
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		Ggit.OId commitoid;

		try
		{
			Ggit.Commit[] parents;

			if (d_last_commit != null)
			{
				parents = new Ggit.Commit[] {d_last_commit};
			}
			else
			{
				parents = new Ggit.Commit[] {};
			}

			commitoid = d_repository.create_commit("HEAD",
			                                       sig,
			                                       sig,
			                                       null,
			                                       "Initial commit",
			                                       tree,
			                                       parents);
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		try
		{
			d_last_commit = d_repository.lookup<Ggit.Commit>(commitoid);
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
		}
	}

	protected void workdir_remove(string? filename, ...)
	{
		if (d_repository == null)
		{
			return;
		}

		var files = filenames_from_varargs(filename, va_list());
		var wd = d_repository.get_workdir();

		foreach (var f in files)
		{
			var fs = wd.get_child(f.filename);

			try
			{
				fs.delete();
			}
			catch (GLib.Error e)
			{
				assert_no_error(e);
			}
		}
	}

	protected void workdir_modify(string? filename, ...)
	{
		if (d_repository == null)
		{
			return;
		}

		var files = files_from_varargs(filename, va_list());
		write_files(files);
	}

	protected void index_modify(string? filename, ...)
	{
		if (d_repository == null)
		{
			return;
		}

		var files = files_from_varargs(filename, va_list());

		Ggit.OId id;

		Ggit.Index index;

		try
		{
			index = d_repository.get_index();
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		// Stage modifications in the index
		foreach (var f in files)
		{
			try
			{
				id = d_repository.create_blob_from_buffer(f.contents.data);
			}
			catch (GLib.Error e)
			{
				assert_no_error(e);
				continue;
			}

			try
			{
				var entry = d_repository.create_index_entry_for_path(f.filename, id);
				index.add(entry);
			}
			catch (GLib.Error e)
			{
				assert_no_error(e);
			}
		}

		try
		{
			index.write();
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
		}
	}

	protected override void set_up()
	{
		string wd;

		d_last_commit = null;

		try
		{
			wd = GLib.DirUtils.make_tmp("gitg-test-XXXXXX");
		}
		catch (GLib.Error e)
		{
			assert_no_error(e);
			return;
		}

		var f = GLib.File.new_for_path(wd);

		try
		{
			d_repository = (Gitg.Repository)Ggit.Repository.init_repository(f, false);
		}
		catch (GLib.Error e)
		{
			GLib.DirUtils.remove(wd);
			assert_no_error(e);
		}
	}

	protected override void tear_down()
	{
		if (d_repository == null)
		{
			return;
		}

		var wd = d_repository.get_workdir();

		// nasty stuff, but I'm not going to implement recursive remove by hand
		// and glib doesn't provide anything for it
		Posix.system("rm -rf '%s'".printf(wd.get_path()));

		d_repository = null;
	}
}

// ex:set ts=4 noet
