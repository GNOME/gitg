/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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

public class CommitModel : Object
{
	private Repository d_repository;
	private Cancellable? d_cancellable;
	private Gitg.Commit[] d_ids;
	private Thread<void*>? d_thread;
	private Ggit.RevisionWalker? d_walker;
	private uint d_advertized_size;
	private uint d_idleid;
	private Lanes d_lanes;
	private Ggit.SortMode d_sortmode;

	public uint limit { get; set; }

	public Ggit.SortMode sort_mode
	{
		get { return d_sortmode; }
		set
		{
			if (d_sortmode != value)
			{
				d_sortmode = value;
				reload();
			}
		}
	}

	private Ggit.OId[] d_include;
	private Ggit.OId[] d_exclude;

	public signal void started();
	public signal void update(uint added);
	public signal void finished();

	[Notify]
	public Repository repository
	{
		get { return d_repository; }
		set
		{
			cancel();

			d_walker = null;
			d_repository = value;
		}
	}

	public CommitModel(Repository repository)
	{
		d_repository = repository;
	}

	construct
	{
		d_lanes = new Lanes();
		d_cancellable = new Cancellable();
		d_cancellable.cancel();

		d_sortmode = Ggit.SortMode.TIME | Ggit.SortMode.TOPOLOGICAL;
	}

	~CommitModel()
	{
		cancel();
	}

	public void set_include(Ggit.OId[] ids)
	{
		d_include = ids;
	}

	public void set_exclude(Ggit.OId[] ids)
	{
		d_exclude = ids;
	}

	private void cancel()
	{
		if (!d_cancellable.is_cancelled())
		{
			d_cancellable.cancel();

			d_thread.join();
			d_thread = null;
		}

		if (d_idleid != 0)
		{
			Source.remove(d_idleid);
			d_idleid = 0;
		}

		d_ids = new Gitg.Commit[0];
		d_advertized_size = 0;

		emit_started();
		emit_finished();
	}

	protected virtual void emit_started()
	{
		d_lanes.reset();
		started();
	}

	protected virtual void emit_finished()
	{
		finished();
	}

	protected virtual void emit_update(uint added)
	{
		update(added);
	}

	public void reload()
	{
		cancel();

		if (d_include.length == 0)
		{
			return;
		}

		walk.begin((obj, res) => {
			walk.end(res);

			d_cancellable.cancel();
			if (d_thread != null)
			{
				d_thread.join();
				d_thread = null;
			}
		});
	}

	public uint size()
	{
		return d_advertized_size;
	}

	public new Gitg.Commit? @get(uint idx)
	{
		Gitg.Commit? ret;

		if (idx >= d_advertized_size)
		{
			return null;
		}

		lock(d_ids)
		{
			ret = d_ids[idx];
		}

		return ret;
	}

	private void notify_batch(bool isend)
	{
		lock(d_idleid)
		{
			if (d_idleid != 0)
			{
				Source.remove(d_idleid);
				d_idleid = 0;
			}
		}

		uint newsize = d_ids.length;

		d_idleid = Idle.add(() => {
			lock(d_idleid)
			{
				if (d_idleid == 0)
				{
					return false;
				}

				d_idleid = 0;

				uint added = newsize - d_advertized_size;
				d_advertized_size = newsize;

				emit_update(added);

				if (isend)
				{
					emit_finished();
				}
			}

			return false;
		});
	}

	private async void walk()
	{
		Ggit.OId[] included = d_include;
		Ggit.OId[] excluded = d_exclude;

		uint limit = this.limit;

		SourceFunc cb = walk.callback;

		ThreadFunc<void*> run = () => {
			if (d_walker == null)
			{
				try
				{
					d_walker = new Ggit.RevisionWalker(d_repository);
				}
				catch
				{
					notify_batch(true);
					return null;
				}
			}

			d_walker.reset();
			d_walker.set_sort_mode(d_sortmode);

			foreach (Ggit.OId oid in included)
			{
				try
				{
					d_walker.push(oid);
				} catch {};
			}

			foreach (Ggit.OId oid in excluded)
			{
				try
				{
					d_walker.hide(oid);
				} catch {};
			}

			uint size;

			// Pre-allocate array to store commits
			lock(d_ids)
			{
				d_ids = new Gitg.Commit[1000];

				size = d_ids.length;

				d_ids.length = 0;
				d_advertized_size = 0;
			}

			Timer timer = new Timer();

			while (true)
			{
				Ggit.OId? id;
				Gitg.Commit? commit;

				if (d_cancellable.is_cancelled())
				{
					break;
				}

				try
				{
					id = d_walker.next();

					if (id == null)
					{
						break;
					}

					commit = d_repository.lookup(id, typeof(Gitg.Commit)) as Gitg.Commit;
				} catch { break; }

				// Add the id
				if (d_ids.length == size)
				{
					lock(d_ids)
					{
						var oldlen = d_ids.length;

						size *= 2;

						d_ids.resize((int)size);
						d_ids.length = oldlen;
					}
				}

				d_ids += commit;

				int mylane;
				var lanes = d_lanes.next(commit, out mylane);

				commit.update_lanes((owned)lanes, mylane);

				if (timer.elapsed() >= 200)
				{
					notify_batch(false);
					timer.start();
				}

				if (limit > 0 && d_ids.length == limit)
				{
					break;
				}
			}

			notify_batch(true);

			Idle.add((owned)cb);
			return null;
		};

		try
		{
			d_cancellable.reset();
			emit_started();
			d_thread = new Thread<void*>.try("gitg-history-walk", (owned)run);
			yield;
		}
		catch
		{
			emit_finished();

			d_cancellable.cancel();
			d_thread = null;
		}
	}
}

}

// ex:set ts=4 noet
