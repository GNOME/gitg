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

public interface StageStatusItem : Object
{
	public abstract string path { owned get; }

	public abstract bool is_staged { get; }
	public abstract bool is_unstaged { get; }
	public abstract bool is_untracked { get; }

	public abstract string? icon_name { owned get; }
}

public class StageStatusFile : Object, StageStatusItem
{
	private string d_path;
	private Ggit.StatusFlags d_flags;

	private static Ggit.StatusFlags s_index_flags =
		  Ggit.StatusFlags.INDEX_NEW
		| Ggit.StatusFlags.INDEX_MODIFIED
		| Ggit.StatusFlags.INDEX_DELETED
		| Ggit.StatusFlags.INDEX_RENAMED
		| Ggit.StatusFlags.INDEX_TYPECHANGE;

	private static Ggit.StatusFlags s_work_flags =
		  Ggit.StatusFlags.WORKING_TREE_MODIFIED
		| Ggit.StatusFlags.WORKING_TREE_DELETED
		| Ggit.StatusFlags.WORKING_TREE_TYPECHANGE
		| Ggit.StatusFlags.CONFLICTED;

	private static Ggit.StatusFlags s_untracked_flags =
		  Ggit.StatusFlags.WORKING_TREE_NEW;

	private static Ggit.StatusFlags s_ignored_flags =
		  Ggit.StatusFlags.IGNORED;

	public StageStatusFile(string path, Ggit.StatusFlags flags)
	{
		d_path = path;
		d_flags = flags;
	}

	public string path
	{
		owned get { return d_path; }
	}

	public bool is_staged
	{
		get { return (d_flags & s_index_flags) != 0; }
	}

	public bool is_unstaged
	{
		get { return (d_flags & s_work_flags) != 0; }
	}

	public bool is_untracked
	{
		get { return (d_flags & s_untracked_flags) != 0; }
	}

	public Ggit.StatusFlags flags
	{
		get { return d_flags; }
	}

	private string? icon_for_status(Ggit.StatusFlags status)
	{
		if ((status & (Ggit.StatusFlags.INDEX_NEW |
			           Ggit.StatusFlags.WORKING_TREE_NEW)) != 0)
		{
			return "list-add-symbolic";
		}
		else if ((status & (Ggit.StatusFlags.INDEX_MODIFIED |
			                Ggit.StatusFlags.INDEX_RENAMED |
			                Ggit.StatusFlags.INDEX_TYPECHANGE |
			                Ggit.StatusFlags.WORKING_TREE_MODIFIED |
			                Ggit.StatusFlags.WORKING_TREE_TYPECHANGE)) != 0)
		{
			return "text-editor-symbolic";
		}
		else if ((status & (Ggit.StatusFlags.INDEX_DELETED |
			                Ggit.StatusFlags.WORKING_TREE_DELETED)) != 0)
		{
			return "edit-delete-symbolic";
		}

		return null;
	}

	public string? icon_name
	{
		owned get { return icon_for_status(d_flags); }
	}
}

public class StageStatusSubmodule : Object, StageStatusItem
{
	private Ggit.Submodule d_submodule;
	private string d_path;
	private Ggit.SubmoduleStatus d_flags;

	private static Ggit.SubmoduleStatus s_index_flags =
		  Ggit.SubmoduleStatus.INDEX_ADDED
		| Ggit.SubmoduleStatus.INDEX_DELETED
		| Ggit.SubmoduleStatus.INDEX_MODIFIED;

	private static Ggit.SubmoduleStatus s_work_flags =
		  Ggit.SubmoduleStatus.WD_ADDED
		| Ggit.SubmoduleStatus.WD_DELETED
		| Ggit.SubmoduleStatus.WD_MODIFIED;

	private static Ggit.SubmoduleStatus s_untracked_flags =
		  Ggit.SubmoduleStatus.IN_WD;

	private static Ggit.SubmoduleStatus s_tracked_flags =
		  Ggit.SubmoduleStatus.IN_HEAD
		| Ggit.SubmoduleStatus.IN_INDEX;

	private static Ggit.SubmoduleStatus s_dirty_flags =
		  Ggit.SubmoduleStatus.WD_INDEX_MODIFIED
		| Ggit.SubmoduleStatus.WD_WD_MODIFIED;

	public StageStatusSubmodule(Ggit.Submodule submodule)
	{
		d_submodule = submodule;
		d_path = submodule.get_path();

		var repository = submodule.get_owner();

		try
		{
			d_flags = repository.get_submodule_status(submodule.get_name(),
			                                          Ggit.SubmoduleIgnore.UNTRACKED);
		} catch {}
	}

	public Ggit.Submodule submodule
	{
		get { return d_submodule; }
	}

	public string path
	{
		owned get { return d_path; }
	}

	public bool is_staged
	{
		get { return (d_flags & s_index_flags) != 0; }
	}

	public bool is_unstaged
	{
		get { return !is_untracked && (d_flags & s_work_flags) != 0; }
	}

	public bool is_untracked
	{
		get
		{
			return    (d_flags & s_untracked_flags) != 0
			       && (d_flags & s_tracked_flags) == 0;
		}
	}

	public bool is_dirty
	{
		get { return (d_flags & s_dirty_flags) != 0; }
	}

	public Ggit.SubmoduleStatus flags
	{
		get { return d_flags; }
	}

	public string? icon_name {
		owned get { return "folder-remote-symbolic"; }
	}
}

public class StageStatusEnumerator : Object
{
	private Repository d_repository;
	private Thread<void *> d_thread;
	private StageStatusItem[] d_items;
	private int d_offset;
	private int d_callback_num;
	private Cancellable d_cancellable;
	private SourceFunc d_callback;
	private Ggit.StatusOptions? d_options;
	private Gee.HashSet<string> d_ignored_submodules;

	private static Regex s_ignore_regex;

	static construct
	{
		try
		{
			s_ignore_regex = new Regex("submodule\\.(.*)\\.gitgignore");
		}
		catch (Error e)
		{
			stderr.printf(@"Failed to compile stage status enumerator regex: $(e.message)\n");
		}
	}

	internal StageStatusEnumerator(Repository repository,
	                               Ggit.StatusOptions? options = null)
	{
		d_repository = repository;
		d_options = options;

		d_items = new StageStatusItem[100];
		d_items.length = 0;
		d_cancellable = new Cancellable();

		try
		{
			d_ignored_submodules = new Gee.HashSet<string>();

			repository.get_config().snapshot().match_foreach(s_ignore_regex, (match, val) => {
				if (val != "true")
				{
					return 0;
				}

				d_ignored_submodules.add(match.fetch(1));
				return 0;
			});
		} catch {}

		try
		{
			d_thread = new Thread<void *>.try("gitg-status-enumerator", run_status);
		} catch {}
	}

	public void cancel()
	{
		lock (d_items)
		{
			if (d_cancellable != null)
			{
				d_cancellable.cancel();
			}
		}

		if (d_thread != null)
		{
			d_thread.join();
			d_thread = null;
		}
	}

	private delegate void AddItem(StageStatusItem item);

	private void *run_status()
	{
		AddItem add = (item) => {
			lock (d_items)
			{
				d_items += item;

				if (d_callback != null && d_callback_num != -1 && d_items.length >= d_callback_num)
				{
					var cb = (owned)d_callback;
					d_callback = null;

					Idle.add((owned)cb);
				}
			}
		};

		var submodule_paths = new Gee.HashSet<string>();

		// Due to a bug in libgit2, submodule iteration crashes when performed
		// on a bare repository
		if (!d_repository.is_bare)
		{
			try
			{
				d_repository.submodule_foreach((submodule, name) => {
					submodule_paths.add(submodule.get_path());

					if (!d_ignored_submodules.contains(name))
					{
						try
						{
							add(new StageStatusSubmodule(d_repository.lookup_submodule(name)));
						} catch {}
					}

					return d_cancellable.is_cancelled() ? 1 : 0;
				});
			} catch {}
		}

		try
		{
			d_repository.file_status_foreach(d_options, (path, flags) => {
				if (!submodule_paths.contains(path))
				{
					add(new StageStatusFile(path, flags));
				}

				return d_cancellable.is_cancelled() ? 1 : 0;
			});
		} catch {}

		lock (d_items)
		{
			d_cancellable = null;

			if (d_callback != null && d_callback_num == -1)
			{
				var cb = (owned)d_callback;
				d_callback = null;

				Idle.add((owned)cb);
			}
		}

		return null;
	}

	private StageStatusItem[] fill_items(int num)
	{
		int n = 0;

		if (num == -1)
		{
			num = d_items.length - d_offset;
		}

		StageStatusItem[] ret = new StageStatusItem[int.min(num, d_items.length - d_offset)];
		ret.length = 0;

		// d_items is already locked here, so it's safe to access
		while (d_offset < d_items.length)
		{
			if (n == num)
			{
				break;
			}

			ret += d_items[d_offset];
			d_offset++;

			++n;
		}

		return ret;
	}

	public async StageStatusItem[] next_items(int num)
	{
		SourceFunc callback = next_items.callback;
		StageStatusItem[] ret;

		lock (d_items)
		{
			if (d_cancellable == null)
			{
				// Already finished
				return fill_items(num);
			}
			else
			{
				d_callback = (owned)callback;
				d_callback_num = num;
			}
		}

		yield;

		lock (d_items)
		{
			ret = fill_items(num);
		}

		if (ret.length != num)
		{
			cancel();
		}

		return ret;
	}
}

}

// ex:set ts=4 noet
