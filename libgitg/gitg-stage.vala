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

namespace Gitg
{

public class Stage : Object
{
	private weak Repository d_repository;
	private Mutex d_index_mutex;
	private Ggit.Tree? d_head_tree;

	internal Stage(Repository repository)
	{
		d_repository = repository;
	}

	public async void refresh() throws Error
	{
		yield thread_index((index) => {
			index.read();
		});
	}

	public async Ggit.Tree? get_head_tree() throws Error
	{
		if (d_head_tree != null)
		{
			return d_head_tree;
		}

		Error? e = null;

		yield Async.thread(() => {
			try
			{
				var head = d_repository.get_head();
				var commit = (Ggit.Commit)head.lookup();

				d_head_tree = commit.get_tree();
			}
			catch (Error err)
			{
				e = err;
			}
		});

		if (e != null)
		{
			throw e;
		}

		return d_head_tree;
	}

	public StageStatusEnumerator file_status(Ggit.StatusOptions? options = null)
	{
		return new StageStatusEnumerator(d_repository, options);
	}

	private delegate void WithIndexFunc(Ggit.Index index) throws Error;

	private void with_index(WithIndexFunc func)
	{
		lock(d_index_mutex)
		{
			try
			{
				func(d_repository.get_index());
			} catch {}
		}
	}

	private async void thread_index(WithIndexFunc func) throws Error
	{
		yield Async.thread(() => {
			with_index(func);
		});
	}

	/**
	 * Revert index changes.
	 *
	 * @param file the file to revert.
	 *
	 * Revert a file in the index to the version currently recorded in HEAD.
	 * Note that this only affects the index, not the working directory.
	 */
	public async void revert_index(File file) throws Error
	{
		var tree = yield get_head_tree();

		yield thread_index((index) => {
			// get path relative to the repository working directory
			var wd = d_repository.get_workdir();
			var path = wd.get_relative_path(file);

			// get the tree entry of that file
			var entry = tree.get_by_path(path);
			var id = entry.get_id();

			var ientry = d_repository.create_index_entry_for_file(file, id);
			index.add(ientry);

			index.write();
		});
	}

	/**
	 * Revert index changes.
	 *
	 * @param path path relative to the working directory.
	 *
	 * Revert a path in the index to the version currently recorded in HEAD.
	 * Note that this only affects the index, not the working directory.
	 */
	public async void revert_index_path(string path) throws Error
	{
		yield revert_index(d_repository.get_workdir().resolve_relative_path(path));
	}

	/**
	 * Revert working directory changes.
	 *
	 * @param file the file to revert.
	 *
	 * Revert a file to the version currently recorded in HEAD. This will delete
	 * any modifications done in the current working directory to this file,
	 * so use with care! Note that this only affects the working directory,
	 * not the index.
	 */
	public async void revert(File file) throws Error
	{
		var tree = yield get_head_tree();

		yield thread_index((index) => {
			// get path relative to the repository working directory
			var wd = d_repository.get_workdir();
			var path = wd.get_relative_path(file);

			// get the tree entry of that file
			var entry = tree.get_by_path(path);
			var id = entry.get_id();

			// resolve the blob
			var blob = d_repository.lookup<Ggit.Blob>(id);

			var stream = file.replace(null, false, FileCreateFlags.NONE);

			stream.write_all(blob.get_raw_content(), null);
			stream.close();

			index.write();
		});
	}

	/**
	 * Revert working directory changes.
	 *
	 * @param path path relative to the working directory.
	 *
	 * Revert a path to the version currently recorded in HEAD. This will delete
	 * any modifications done in the current working directory to this file,
	 * so use with care! Note that this only affects the working directory,
	 * not the index.
	 */
	public async void revert_path(string path) throws Error
	{
		yield revert(d_repository.get_workdir().resolve_relative_path(path));
	}

	/**
	 * Delete a file from the index.
	 *
	 * @param file the file to delete.
	 *
	 * Delete the file from the index.
	 */
	public async void @delete(File file) throws Error
	{
		yield thread_index((index) => {
			index.remove(file, 0);
			index.write();
		});
	}

	/**
	 * Delete a relative path from the index.
	 *
	 * @param path path relative to the working directory.
	 *
	 * Delete the relative path from the index.
	 */
	public async void delete_path(string path) throws Error
	{
		yield this.delete(d_repository.get_workdir().resolve_relative_path(path));
	}

	/**
	 * Stage a file to the index.
	 *
	 * @param file the file to stage.
	 *
	 * Stage the file to the index. This will record the state of the file in
	 * the working directory to the index.
	 */
	public async void stage(File file) throws Error
	{
		yield thread_index((index) => {
			index.add_file(file);
			index.write();
		});
	}

	/**
	 * Stage a path to the index.
	 *
	 * @param path path relative to the working directory.
	 *
	 * Stage a relative path to the index. This will record the state of the file in
	 * the working directory to the index.
	 */
	public async void stage_path(string path) throws Error
	{
		yield stage(d_repository.get_workdir().resolve_relative_path(path));
	}

	/**
	 * Unstage a file from the index.
	 *
	 * @param file the file to unstage.
	 *
	 * Unstage changes in the specified file from the index. This will record
	 * the state of the file in HEAD to the index.
	 */
	public async void unstage(File file) throws Error
	{
		yield thread_index((index) => {
			// lookup the tree of HEAD
			var head = d_repository.get_head();
			var commit = (Ggit.Commit)head.lookup();
			var tree = commit.get_tree();

			// get path relative to the repository working directory
			var wd = d_repository.get_workdir();
			var path = wd.get_relative_path(file);

			// get the tree entry of that file
			var entry = tree.get_by_path(path);
			var id = entry.get_id();

			// create a new index entry for the file, pointing to the blob
			// from the HEAD tree
			var ientry = d_repository.create_index_entry_for_path(path, id);

			// override file mode since the file might not actually exist.
			ientry.set_mode(entry.get_file_mode());

			index.add(ientry);
			index.write();
		});
	}

	/**
	 * Unstage a path from the index.
	 *
	 * @param path path relative to the working directory.
	 *
	 * Unstage changes in the specified relative path from the index. This will record
	 * the state of the file in HEAD to the index.
	 */
	public async void unstage_path(string path) throws Error
	{
		yield unstage(d_repository.get_workdir().resolve_relative_path(path));
	}

	public async Ggit.DiffList? diff_index(StageStatusFile f) throws Error
	{
		var opts = new Ggit.DiffOptions(Ggit.DiffOption.INCLUDE_UNTRACKED_CONTENT |
		                                Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		                                Ggit.DiffOption.RECURSE_UNTRACKED_DIRS,
		                                3,
		                                3,
		                                null,
		                                null,
		                                new string[] {f.path});

		var tree = yield get_head_tree();

		return new Ggit.DiffList.tree_to_index(d_repository,
		                                       tree,
		                                       d_repository.get_index(),
		                                       opts);
	}

	public async Ggit.DiffList? diff_workdir(StageStatusFile f) throws Error
	{
		var opts = new Ggit.DiffOptions(Ggit.DiffOption.INCLUDE_UNTRACKED_CONTENT |
		                                Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		                                Ggit.DiffOption.RECURSE_UNTRACKED_DIRS,
		                                3,
		                                3,
		                                null,
		                                null,
		                                new string[] {f.path});

		return new Ggit.DiffList.index_to_workdir(d_repository,
		                                          d_repository.get_index(),
		                                          opts);
	}
}

}

// ex:set ts=4 noet
