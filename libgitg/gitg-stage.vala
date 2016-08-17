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
	NOTHING_TO_COMMIT,
	INDEX_ENTRY_NOT_FOUND
}

public class PatchSet
{
	public enum Type
	{
		ADD    = 'a',
		REMOVE = 'r'
	}

	public struct Patch
	{
		Type   type;
		size_t old_offset;
		size_t new_offset;
		size_t length;
	}

	public string  filename;
	public Patch[] patches;

	public PatchSet reversed()
	{
		var ret = new PatchSet();

		ret.filename = filename;
		ret.patches = new Patch[patches.length];

		for (int i = 0; i < patches.length; i++)
		{
			var orig = patches[i];

			var p = Patch() {
				old_offset = orig.new_offset,
				new_offset = orig.old_offset,
				length = orig.length
			};

			switch (patches[i].type)
			{
				case Type.ADD:
					p.type = Type.REMOVE;
					break;
				case Type.REMOVE:
					p.type = Type.ADD;
					break;
			}

			ret.patches[i] = p;
		}

		return ret;
	}
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
		d_head_tree = null;

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
		var show = Ggit.StatusShow.INDEX_ONLY;

		var options = new Ggit.StatusOptions(0, show, null);
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

	public async Ggit.OId? commit_index(Ggit.Index         index,
	                                    Ggit.Ref           reference,
	                                    string             message,
	                                    Ggit.Signature     author,
	                                    Ggit.Signature     committer,
	                                    Ggit.OId[]?        parents,
	                                    StageCommitOptions options) throws Error
	{
		Ggit.OId? treeoid = null;

		yield Async.thread(() => {
			treeoid = index.write_tree_to(d_repository);
		});

		return yield commit_tree(treeoid, reference, message, author, committer, parents, options);
	}

	public async Ggit.OId? commit_tree(Ggit.OId           treeoid,
	                                   Ggit.Ref           reference,
	                                   string             message,
	                                   Ggit.Signature     author,
	                                   Ggit.Signature     committer,
	                                   Ggit.OId[]?        parents,
	                                   StageCommitOptions options) throws Error
	{
		Ggit.OId? ret = null;

		yield Async.thread(() => {
			bool skip_hooks = (options & StageCommitOptions.SKIP_HOOKS) != 0;
			bool amend = (options & StageCommitOptions.AMEND) != 0;

			// Write tree from index
			var conf = d_repository.get_config().snapshot();

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

			Ggit.OId? refoid = null;

			try
			{
				// Resolve the ref and get the actual target id
				refoid = reference.resolve().get_target();
			} catch {}

			if (!amend)
			{
				Ggit.OId[] pars;

				if (parents == null)
				{
					if (refoid == null)
					{
						pars = new Ggit.OId[] {};
					}
					else
					{
						pars = new Ggit.OId[] { refoid };
					}
				}
				else
				{
					pars = parents;
				}

				ret = d_repository.create_commit_from_ids(reference.get_name(),
				                                          author,
				                                          committer,
				                                          encoding,
				                                          emsg,
				                                          treeoid,
				                                          pars);
			}
			else
			{
				var refcommit = d_repository.lookup<Ggit.Commit>(refoid);
				var tree = d_repository.lookup<Ggit.Tree>(treeoid);

				ret = refcommit.amend(reference.get_name(),
				                       author,
				                       committer,
				                       encoding,
				                       emsg,
				                       tree);
			}

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

			// Update reflog of reference
			try
			{
				if (always_update || reference.has_log())
				{
					var reflog = reference.get_log();
					reflog.append(ret, committer, reflogmsg);
					reflog.write();
				}
			} catch {}

			if (reference.get_reference_type() == Ggit.RefType.SYMBOLIC)
			{
				// Update reflog of whereever HEAD points to
				try
				{
					var resolved = reference.resolve();

					if (always_update || resolved.has_log())
					{
						var reflog = resolved.get_log();

						reflog.append(ret, committer, reflogmsg);
						reflog.write();
					}
				} catch {}
			}

			if (reference.get_name() == "HEAD")
			{
				d_head_tree = null;
			}

			// run post commit
			post_commit_hook(author);
		});

		return ret;
	}

	public async Ggit.OId? commit(string             message,
	                              Ggit.Signature     author,
	                              Ggit.Signature     committer,
	                              StageCommitOptions options) throws Error
	{
		bool amend = (options & StageCommitOptions.AMEND) != 0;
		Ggit.OId? ret = null;

		lock(d_index_mutex)
		{
			Ggit.Index? index = null;

			yield Async.thread(() => {
				index = d_repository.get_index();
			});

			if (!amend && !has_index_changes())
			{
				throw new StageError.NOTHING_TO_COMMIT("Nothing to commit");
			}

			ret = yield commit_index(index,
			                         d_repository.lookup_reference("HEAD"),
			                         message,
			                         author,
			                         committer,
			                         null,
			                         options);
		}

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
	 * Revert a patch in the working directory.
	 *
	 * @param patch the patch to revert.
	 *
	 * Revert a provided patch from the working directory. The patch should
	 * contain changes of the file in the current working directory to the contents
	 * of the index (i.e. as obtained from diff_workdir)
	 */
	public async void revert_patch(PatchSet patch) throws Error
	{
		// new file is the current file in the working directory
		var workdirf = d_repository.get_workdir().resolve_relative_path(patch.filename);
		var workdirf_stream = yield workdirf.read_async();

		yield thread_index((index) => {
			var entries = index.get_entries();
			var entry = entries.get_by_path(workdirf, 0);

			if (entry == null)
			{
				throw new StageError.INDEX_ENTRY_NOT_FOUND(patch.filename);
			}

			var index_blob = d_repository.lookup<Ggit.Blob>(entry.get_id());
			unowned uchar[] index_content = index_blob.get_raw_content();

			var index_stream = new MemoryInputStream.from_bytes(new Bytes(index_content));
			var reversed = patch.reversed();

			FileIOStream? out_stream = null;
			File ?outf = null;

			try
			{
				outf = File.new_tmp(null, out out_stream);

				apply_patch_stream(workdirf_stream,
				                   index_stream,
				                   out_stream.output_stream,
				                   reversed);
			}
			catch (Error e)
			{
				workdirf_stream.close();
				index_stream.close();

				if (outf != null)
				{
					try
					{
						outf.delete();
					} catch {}
				}

				throw e;
			}

			workdirf_stream.close();
			index_stream.close();

			if (out_stream != null)
			{
				out_stream.close();
			}

			// Move outf to workdirf
			try
			{
				var repl = workdirf.replace(null,
				                            false,
				                            FileCreateFlags.NONE);

				repl.splice(outf.read(),
				            OutputStreamSpliceFlags.CLOSE_SOURCE |
				            OutputStreamSpliceFlags.CLOSE_TARGET);
			}
			catch (Error e)
			{
				try
				{
					outf.delete();
				} catch {}

				throw e;
			}

			try
			{
				outf.delete();
			} catch {}
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
	 * Stage a commit to the index.
	 *
	 * @param path path relative to the working directory.
	 * @param id the id of the commit object to stage at the given path.
	 *
	 * Stage a commit to the index with a relative path. This will record the
	 * given commit id for file pointed to at path in the index.
	 */
	public async void stage_commit(string path, Ggit.Commit commit) throws Error
	{
		yield thread_index((index) => {
			var entry = d_repository.create_index_entry_for_path(path, commit.get_id());
			entry.set_commit(commit);

			index.add(entry);
			index.write();
		});
	}

	private void copy_stream(OutputStream dest, InputStream src, ref size_t pos, size_t index, size_t length) throws Error
	{
		if (length == 0)
		{
			return;
		}

		var buf = new uint8[length];

		if (pos != index)
		{
			((Seekable)src).seek(index, SeekType.SET);
			pos = index;
		}

		src.read_all(buf, null);
		dest.write_all(buf, null);

		pos += length;
	}

	private void apply_patch(Ggit.Index  index,
	                         InputStream old_stream,
	                         InputStream new_stream,
	                         PatchSet    patch) throws Error
	{
		var patched_stream = d_repository.create_blob();

		apply_patch_stream(old_stream, new_stream, patched_stream, patch);

		patched_stream.close();
		var new_id = patched_stream.get_id();

		var new_entry = d_repository.create_index_entry_for_path(patch.filename,
		                                                         new_id);

		index.add(new_entry);
		index.write();
	}

	private void apply_patch_stream(InputStream  old_stream,
	                                InputStream  new_stream,
	                                OutputStream patched_stream,
	                                PatchSet     patch) throws Error
	{
		size_t old_ptr = 0;
		size_t new_ptr = 0;

		// Copy old_content to patched_stream while applying patches as
		// specified in patch.patches from new_stream
		foreach (var p in patch.patches)
		{
			// Copy from old_ptr until p.old_offset
			copy_stream(patched_stream,
			            old_stream,
			            ref old_ptr,
			            old_ptr,
			            p.old_offset - old_ptr);

			if (p.type == PatchSet.Type.REMOVE)
			{
				// Removing, just advance old stream
				((Seekable)old_stream).seek(p.length, SeekType.CUR);
				old_ptr += p.length;
			}
			else
			{
				// Inserting, copy from new_stream
				copy_stream(patched_stream,
				            new_stream,
				            ref new_ptr,
				            p.new_offset,
				            p.length);
			}
		}

		// Copy remaining part of old
		patched_stream.splice(old_stream, OutputStreamSpliceFlags.NONE);
	}

	/**
	 * Stage a patch to the index.
	 *
	 * @param patch the patch to stage.
	 *
	 * Stage a provided patch to the index. The patch should contain changes
	 * of the file in the current working directory to the contents of the
	 * index (i.e. as obtained from diff_workdir)
	 */
	public async void stage_patch(PatchSet patch) throws Error
	{
		// new file is the current file in the working directory
		var newf = d_repository.get_workdir().resolve_relative_path(patch.filename);
		var new_stream = yield newf.read_async();

		yield thread_index((index) => {
			var entries = index.get_entries();
			var entry = entries.get_by_path(newf, 0);

			if (entry == null)
			{
				throw new StageError.INDEX_ENTRY_NOT_FOUND(patch.filename);
			}

			var old_blob = d_repository.lookup<Ggit.Blob>(entry.get_id());
			unowned uchar[] old_content = old_blob.get_raw_content();

			var old_stream = new MemoryInputStream.from_bytes(new Bytes(old_content));

			apply_patch(index, old_stream, new_stream, patch);

			new_stream.close();
			old_stream.close();
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

	/**
	 * Unstage a patch from the index.
	 *
	 * @param patch the patch to unstage.
	 *
	 * Unstage a provided patch from the index. The patch should contain changes
	 * of the file in the index to the file in HEAD.
	 */
	public async void unstage_patch(PatchSet patch) throws Error
	{
		var file = d_repository.get_workdir().resolve_relative_path(patch.filename);
		var tree = yield get_head_tree();

		yield thread_index((index) => {
			var entries = index.get_entries();
			var entry = entries.get_by_path(file, 0);

			if (entry == null)
			{
				throw new StageError.INDEX_ENTRY_NOT_FOUND(patch.filename);
			}

			var head_entry = tree.get_by_path(patch.filename);
			var head_blob = d_repository.lookup<Ggit.Blob>(head_entry.get_id());
			var index_blob = d_repository.lookup<Ggit.Blob>(entry.get_id());

			unowned uchar[] head_content = head_blob.get_raw_content();
			unowned uchar[] index_content = index_blob.get_raw_content();

			var head_stream = new MemoryInputStream.from_bytes(new Bytes(head_content));
			var index_stream = new MemoryInputStream.from_bytes(new Bytes(index_content));

			var reversed = patch.reversed();

			apply_patch(index, index_stream, head_stream, reversed);

			head_stream.close();
			index_stream.close();
		});
	}

	public async Ggit.Diff? diff_index_all(StageStatusItem[]? files,
	                                       Ggit.DiffOptions?  defopts = null) throws Error
	{
		var opts = new Ggit.DiffOptions();

		opts.flags = Ggit.DiffOption.INCLUDE_UNTRACKED |
		             Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		             Ggit.DiffOption.RECURSE_UNTRACKED_DIRS;


		if (files != null)
		{
			var pspec = new string[files.length];

			for (var i = 0; i < files.length; i++)
			{
				pspec[i] = files[i].path;
			}

			opts.pathspec = pspec;
		}

		if (defopts != null)
		{
			opts.flags |= defopts.flags;

			opts.n_context_lines = defopts.n_context_lines;
			opts.n_interhunk_lines = defopts.n_interhunk_lines;

			opts.old_prefix = defopts.old_prefix;
			opts.new_prefix = defopts.new_prefix;
		}

		Ggit.Tree? tree = null;

		if (!d_repository.is_empty())
		{
			tree = yield get_head_tree();
		}

		return new Ggit.Diff.tree_to_index(d_repository,
		                                   tree,
		                                   d_repository.get_index(),
		                                   opts);
	}

	public async Ggit.Diff? diff_index(StageStatusItem   f,
	                                   Ggit.DiffOptions? defopts = null) throws Error
	{
		return yield diff_index_all(new StageStatusItem[] {f}, defopts);
	}

	public async Ggit.Diff? diff_workdir_all(StageStatusItem[] files,
	                                         Ggit.DiffOptions? defopts = null) throws Error
	{
		var opts = new Ggit.DiffOptions();

		opts.flags = Ggit.DiffOption.INCLUDE_UNTRACKED |
		             Ggit.DiffOption.DISABLE_PATHSPEC_MATCH |
		             Ggit.DiffOption.RECURSE_UNTRACKED_DIRS |
		             Ggit.DiffOption.SHOW_UNTRACKED_CONTENT;

		if (files != null)
		{
			var pspec = new string[files.length];

			for (var i = 0; i < files.length; i++)
			{
				pspec[i] = files[i].path;
			}

			opts.pathspec = pspec;
		}

		if (defopts != null)
		{
			opts.flags |= defopts.flags;

			opts.n_context_lines = defopts.n_context_lines;
			opts.n_interhunk_lines = defopts.n_interhunk_lines;

			opts.old_prefix = defopts.old_prefix;
			opts.new_prefix = defopts.new_prefix;
		}

		return new Ggit.Diff.index_to_workdir(d_repository,
		                                      d_repository.get_index(),
		                                      opts);
	}

	public async Ggit.Diff? diff_workdir(StageStatusItem   f,
	                                     Ggit.DiffOptions? defopts = null) throws Error
	{
		return yield diff_workdir_all(new StageStatusItem[] {f}, defopts);
	}
}

}

// ex:set ts=4 noet
