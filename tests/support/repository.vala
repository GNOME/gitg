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
	private uint d_current_time;

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

	public void assert_file_contents(string filename, string expected_contents)
	{
		var wd = d_repository.get_workdir();

		Assert.assert_file_contents(Path.build_filename(wd.get_path(), filename), expected_contents);
	}

	public bool file_exists(string filename)
	{
		return d_repository.get_workdir().get_child(filename).query_exists();
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
				Assert.assert_no_error(e);
			}
		}
	}

	protected void write_file(string filename, string contents)
	{
		write_files(new File[] {
			File() {
				filename = filename,
				contents = contents
			}
		});
	}

	public Ggit.Signature? get_verified_committer()
	{
		try
		{
			return new Ggit.Signature("gitg tester", "gitg-tester@gnome.org", new DateTime.from_unix_utc(d_current_time++));
		}
		catch (Error e)
		{
			Assert.assert_no_error(e);
			return null;
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
			Assert.assert_no_error(e);
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
				Assert.assert_no_error(e);
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
			Assert.assert_no_error(e);
			return;
		}

		// create commit
		var sig = get_verified_committer();

		Ggit.Tree tree;

		try
		{
			tree = d_repository.lookup<Ggit.Tree>(treeoid);
		}
		catch (GLib.Error e)
		{
			Assert.assert_no_error(e);
			return;
		}

		Ggit.OId commitoid;

		Ggit.Ref? head = null;
		Ggit.Commit? parent = null;

		try
		{
			head = d_repository.get_head();
			parent = head.lookup() as Ggit.Commit;
		} catch {}

		try
		{
			Ggit.Commit[] parents;

			if (parent != null)
			{
				parents = new Ggit.Commit[] { parent };
			}
			else
			{
				parents = new Ggit.Commit[] {};
			}

			commitoid = d_repository.create_commit("HEAD",
			                                       sig,
			                                       sig,
			                                       null,
			                                       "commit " + filename,
			                                       tree,
			                                       parents);
		}
		catch (GLib.Error e)
		{
			Assert.assert_no_error(e);
			return;
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
				Assert.assert_no_error(e);
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
			Assert.assert_no_error(e);
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
				Assert.assert_no_error(e);
				continue;
			}

			try
			{
				var entry = d_repository.create_index_entry_for_path(f.filename, id);
				index.add(entry);
			}
			catch (GLib.Error e)
			{
				Assert.assert_no_error(e);
			}
		}

		try
		{
			index.write();
		}
		catch (GLib.Error e)
		{
			Assert.assert_no_error(e);
		}
	}

	protected Gitg.Branch? create_branch(string name)
	{
		try
		{
			var commit = d_repository.lookup<Gitg.Commit>(d_repository.get_head().get_target());
			return d_repository.create_branch(name, commit, Ggit.CreateFlags.NONE);
		}
		catch (Error e)
		{
			Assert.assert_no_error(e);
			return null;
		}
	}

	protected void checkout_branch(string name)
	{
		try
		{
			var branch = d_repository.lookup_reference_dwim(name) as Gitg.Branch;
			var commit = branch.resolve().lookup() as Ggit.Commit;
			var tree = commit.get_tree();

			var opts = new Ggit.CheckoutOptions();
			opts.set_strategy(Ggit.CheckoutStrategy.SAFE);

			d_repository.checkout_tree(tree, opts);
			d_repository.set_head(branch.get_name());
		}
		catch (Error e)
		{
			Assert.assert_no_error(e);
			return;
		}
	}

	protected override void set_up()
	{
		string wd;
		d_current_time = 0;

		try
		{
			wd = GLib.DirUtils.make_tmp("gitg-test-XXXXXX");
		}
		catch (GLib.Error e)
		{
			Assert.assert_no_error(e);
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
			Assert.assert_no_error(e);
		}
	}

	private void remove_recursively(GLib.File f)
	{
		try
		{
			var info = f.query_info("standard::*", FileQueryInfoFlags.NONE);

			if (info.get_file_type() == FileType.DIRECTORY)
			{
				var e = f.enumerate_children("standard::*", FileQueryInfoFlags.NONE);

				while ((info = e.next_file()) != null)
				{
					var c = f.get_child(info.get_name());
					remove_recursively(c);
				}
			}

			f.delete();
		}
		catch (Error e)
		{
			stderr.printf("Failed to remove %s: %s\n", f.get_path(), e.message);
		}
	}

	protected Gitg.Branch? lookup_branch(string name)
	{
		try
		{
			var ret = d_repository.lookup_reference_dwim(name) as Gitg.Branch;
			assert_nonnull(ret);

			return ret;
		}
		catch (Error e)
		{
			Assert.assert_no_error(e);
		}

		return null;
	}

	protected Gitg.Commit? lookup_commit(string name)
	{
		try
		{
			var ret = lookup_branch(name).lookup() as Gitg.Commit;
			assert_nonnull(ret);

			return ret;
		}
		catch (Error e)
		{
			Assert.assert_no_error(e);
		}

		return null;
	}

	protected override void tear_down()
	{
		if (d_repository == null)
		{
			return;
		}

		remove_recursively(d_repository.get_workdir());
		d_repository = null;
	}
}

// ex:set ts=4 noet
