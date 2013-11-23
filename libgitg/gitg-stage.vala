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

[Flags]
public enum StageCommitOptions
{
	NONE       = 0,
	SIGN_OFF   = 1 << 0,
	AMEND      = 1 << 1,
	SKIP_HOOKS = 1 << 2
}

public errordomain StageError
{
	PRE_COMMIT_HOOK_FAILED,
	COMMIT_MSG_HOOK_FAILED,
	NOTHING_TO_COMMIT
}

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
			index.read(false);
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

	private void with_index(WithIndexFunc func) throws Error
	{
		lock(d_index_mutex)
		{
			func(d_repository.get_index());
		}
	}

	private async void thread_index(WithIndexFunc func) throws Error
	{
		yield Async.thread(() => {
			with_index(func);
		});
	}

	private string message_with_sign_off(string         message,
	                                     Ggit.Signature committer)
	{
		return "%s\nSigned-off-by: %s <%s>\n".printf(message,
		                                             committer.get_name(),
		                                             committer.get_email());
	}

	private string convert_message_to_encoding(Ggit.Config conf,
	                                           string      message,
	                                           out string? encoding)
	{
		encoding = null;

		try
		{
			encoding = conf.get_string("i18n.commitencoding");
		}
		catch
		{
			encoding = null;
			return message;
		}

		if (encoding != null &&
		    encoding != "" &&
		    encoding.ascii_casecmp("UTF-8") != 0)
		{
			try
			{
				return convert(message, -1, encoding, "UTF-8");
			}
			catch
			{
				encoding = null;
			}
		}
		else
		{
			encoding = null;
		}

		return message;
	}

	private void setup_commit_hook_environment(Gitg.Hook       hook,
	                                           Ggit.Signature? author)
	{
		var wd = d_repository.get_workdir();
		var gd = d_repository.get_location();

		hook.working_directory = wd;

		var gitdir = wd.get_relative_path(gd);

		hook.environment["GIT_DIR"] = gitdir;
		hook.environment["GIT_INDEX_FILE"] = Path.build_filename(gitdir, "index");
		hook.environment["GIT_PREFIX"] = ".";

		if (author != null)
		{
			hook.environment["GIT_AUTHOR_NAME"] = author.get_name();
			hook.environment["GIT_AUTHOR_EMAIL"] = author.get_email();

			var date = author.get_time();

			var un = date.to_unix();
			var tz = date.to_timezone(author.get_time_zone()).format("%z");

			hook.environment["GIT_AUTHOR_DATE"] = @"@$(un) $(tz)";
		}
	}

	public async void pre_commit_hook(Ggit.Signature author) throws StageError
	{
		string? errormsg = null;

		try
		{
			yield Async.thread(() => {
				// First run the pre-commit hook
				var hook = new Gitg.Hook("pre-commit");

				setup_commit_hook_environment(hook, author);

				try
				{
					int status = hook.run_sync(d_repository);

					if (status != 0)
					{
						errormsg = string.joinv("\n", hook.output);
					}
				}
				catch (SpawnError e) {}
			});
		} catch {}

		if (errormsg != null)
		{
			throw new StageError.PRE_COMMIT_HOOK_FAILED(errormsg);
		}
	}

	private bool has_index_changes()
	{
		var opts = Ggit.StatusOption.EXCLUDE_SUBMODULES;
		var show = Ggit.StatusShow.INDEX_ONLY;

		var options = new Ggit.StatusOptions(opts, show, null);
		bool has_changes = false;

		try
		{
			d_repository.file_status_foreach(options, (path, flags) => {
				has_changes = true;
				return -1;
			});
		} catch {}

		return has_changes;
	}

	private string commit_msg_hook(string         message,
	                               Ggit.Signature author,
	                               Ggit.Signature committer) throws Error
	{
		var hook = new Gitg.Hook("commit-msg");

		if (!hook.exists_in(d_repository))
		{
			return message;
		}

		setup_commit_hook_environment(hook, author);

		var msgfile = d_repository.get_location().get_child("COMMIT_EDITMSG");

		try
		{
			FileUtils.set_contents(msgfile.get_path(), message);
		}
		catch { return message; }

		hook.add_argument(msgfile.get_path());

		int status;

		try
		{
			status = hook.run_sync(d_repository);
		}
		catch { return message; }

		if (status != 0)
		{
			throw new StageError.COMMIT_MSG_HOOK_FAILED(string.joinv("\n", hook.output));
		}

		// Read back the message
		try
		{
			string newmessage;

			FileUtils.get_contents(msgfile.get_path(), out newmessage);
			return newmessage;
		}
		catch (Error e)
		{
			throw new StageError.COMMIT_MSG_HOOK_FAILED(_("Could not read commit message after running commit-msg hook: %s").printf(e.message));
		}
		finally
		{
			FileUtils.remove(msgfile.get_path());
		}
	}

	private void post_commit_hook(Ggit.Signature author)
	{
		var hook = new Gitg.Hook("post-commit");

		setup_commit_hook_environment(hook, author);

		hook.run.begin(d_repository, (obj, res) => {
			try
			{
				hook.run.end(res);
			} catch {}
		});
	}

	private string get_subject(string message)
	{
		var nlpos = message.index_of("\n");

		if (nlpos == -1)
		{
			return message;
		}
		else
		{
			return message[0:nlpos];
		}
	}

	public async Ggit.OId? commit(string             message,
	                              Ggit.Signature     author,
	                              Ggit.Signature     committer,
	                              StageCommitOptions options) throws Error
	{
		Ggit.OId? ret = null;

		bool skip_hooks = (options & StageCommitOptions.SKIP_HOOKS) != 0;
		bool amend = (options & StageCommitOptions.AMEND) != 0;

		yield thread_index((index) => {
			if (!amend && !has_index_changes())
			{
				throw new StageError.NOTHING_TO_COMMIT("Nothing to commit");
			}

			// Write tree from index
			var conf = d_repository.get_config();

			string emsg = message;

			if ((options & StageCommitOptions.SIGN_OFF) != 0)
			{
				emsg = message_with_sign_off(emsg, committer);
			}

			string? encoding;

			emsg = convert_message_to_encoding(conf, emsg, out encoding);

			if (!skip_hooks)
			{
				emsg = commit_msg_hook(emsg, author, committer);
			}

			var treeoid = index.write_tree();

			// Note: get the symbolic ref here
			var head = d_repository.lookup_reference("HEAD");

			Ggit.OId? headoid = null;

			try
			{
				// Resolve the ref and get the actual target id
				headoid = head.resolve().get_target();
			} catch {}

			Ggit.OId[] parents;

			if (headoid == null)
			{
				parents = new Ggit.OId[] {};
			}
			else
			{
				if (amend)
				{
					var commit = d_repository.lookup<Ggit.Commit>(headoid);
					var p = commit.get_parents();

					parents = new Ggit.OId[p.size()];

					for (int i = 0; i < p.size(); ++i)
					{
						parents[i] = p.get_id(i);
					}
				}
				else
				{
					parents = new Ggit.OId[] { headoid };
				}
			}

			ret = d_repository.create_commit_from_oids("HEAD",
			                                           author,
			                                           committer,
			                                           encoding,
			                                           emsg,
			                                           treeoid,
			                                           parents);

			bool always_update = false;

			try
			{
				always_update = conf.get_bool("core.logAllRefUpdates");
			} catch {}

			string reflogmsg = "commit";

			if (amend)
			{
				reflogmsg += " (amend)";
			}

			reflogmsg += ": " + get_subject(message);

			// Update reflog of HEAD
			try
			{
				if (always_update || head.has_reflog())
				{
					var reflog = head.get_reflog();
					reflog.append(ret, committer, reflogmsg);
					reflog.write();
				}
			} catch {}

			if (head.get_reference_type() == Ggit.RefType.SYMBOLIC)
			{
				// Update reflog of whereever HEAD points to
				try
				{
					var resolved = head.resolve();

					if (always_update || resolved.has_reflog())
					{
						var reflog = resolved.get_reflog();

						reflog.append(ret, committer, reflogmsg);
						reflog.write();
					}
				} catch {}
			}

			// run post commit
			post_commit_hook(author);
		});

		return ret;
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
		var tree = yield get_head_tree();

		yield thread_index((index) => {
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

	public async Ggit.Diff? diff_index(StageStatusFile f) throws Error
	{
		var opts = new Ggit.DiffOptions(Ggit.DiffOption.INCLUDE_UNTRACKED |
		                                Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		                                Ggit.DiffOption.RECURSE_UNTRACKED_DIRS,
		                                3,
		                                3,
		                                null,
		                                null,
		                                new string[] {f.path});

		var tree = yield get_head_tree();

		return new Ggit.Diff.tree_to_index(d_repository,
		                                   tree,
		                                   d_repository.get_index(),
		                                   opts);
	}

	public async Ggit.Diff? diff_workdir(StageStatusFile f) throws Error
	{
		var opts = new Ggit.DiffOptions(Ggit.DiffOption.INCLUDE_UNTRACKED |
		                                Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		                                Ggit.DiffOption.RECURSE_UNTRACKED_DIRS,
		                                3,
		                                3,
		                                null,
		                                null,
		                                new string[] {f.path});

		return new Ggit.Diff.index_to_workdir(d_repository,
		                                      d_repository.get_index(),
		                                      opts);
	}
}

}

// ex:set ts=4 noet
