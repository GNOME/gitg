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
	private Repository d_repository;
	private StageStatusEnumerator ?d_enumerator;
	private Mutex d_index_mutex;

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

	public StageStatusEnumerator file_status()
	{
		if (d_enumerator == null)
		{
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

			// resolve the blob
			var blob = d_repository.lookup<Ggit.Blob>(id);

			var stream = file.replace(null, false, FileCreateFlags.NONE);
			stream.write_all(blob.get_raw_content(), null);
			stream.close();

			index.write();
		});
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
}

}

// ex:set ts=4 noet
