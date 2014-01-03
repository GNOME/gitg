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

public class StageStatusFile : Object
{
	private string d_path;
	private Ggit.StatusFlags d_flags;

	public StageStatusFile(string path, Ggit.StatusFlags flags)
	{
		d_path = path;
		d_flags = flags;
	}

	public string path
	{
		owned get { return d_path; }
	}

	public Ggit.StatusFlags flags
	{
		get { return d_flags; }
	}
}

public class StageStatusEnumerator : Object
{
	private Repository d_repository;
	private Thread<void *> d_thread;
	private StageStatusFile[] d_files;
	private int d_offset;
	private int d_callback_num;
	private Cancellable d_cancellable;
	private SourceFunc d_callback;
	private Ggit.StatusOptions? d_options;

	internal StageStatusEnumerator(Repository repository,
	                               Ggit.StatusOptions? options = null)
	{
		d_repository = repository;
		d_options = options;

		d_files = new StageStatusFile[100];
		d_files.length = 0;
		d_cancellable = new Cancellable();

		try
		{
			d_thread = new Thread<void *>.try("gitg-status-enumerator", run_status);
		} catch {}
	}

	public void cancel()
	{
		lock (d_files)
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

	private void *run_status()
	{
		try
		{
			d_repository.file_status_foreach(d_options, (path, flags) => {
				lock (d_files)
				{
					d_files += new StageStatusFile(path, flags);

					if (d_callback != null && d_callback_num != -1 && d_files.length >= d_callback_num)
					{
						var cb = (owned)d_callback;
						d_callback = null;

						Idle.add((owned)cb);
					}
				}

				if (d_cancellable.is_cancelled())
				{
					return 1;
				}

				return 0;
			});
		} catch {}

		lock (d_files)
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

	private StageStatusFile[] fill_files(int num)
	{
		int n = 0;

		if (num == -1)
		{
			num = d_files.length - d_offset;
		}

		StageStatusFile[] ret = new StageStatusFile[int.min(num, d_files.length - d_offset)];
		ret.length = 0;

		// d_files is already locked here, so it's safe to access
		while (d_offset < d_files.length)
		{
			if (n == num)
			{
				break;
			}

			ret += d_files[d_offset];
			d_offset++;

			++n;
		}

		return ret;
	}

	public async StageStatusFile[] next_files(int num)
	{
		SourceFunc callback = next_files.callback;
		StageStatusFile[] ret;

		lock (d_files)
		{
			if (d_cancellable == null)
			{
				// Already finished
				return fill_files(num);
			}
			else
			{
				d_callback = (owned)callback;
				d_callback_num = num;
			}
		}

		yield;

		lock (d_files)
		{
			ret = fill_files(num);
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
