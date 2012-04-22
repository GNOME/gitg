namespace Gitg
{

public class CommitModel : Object
{
	private Repository d_repository;
	private Cancellable? d_cancellable;
	private Gitg.Commit[] d_ids;
	private unowned Thread<void*>? d_thread;
	private Ggit.RevisionWalker? d_walker;
	private uint d_advertized_size;
	private uint d_idleid;
	private Lanes d_lanes;

	public uint limit { get; set; }

	private Ggit.OId[] d_include;
	private Ggit.OId[] d_exclude;

	public signal void started();
	public signal void update(uint added);
	public signal void finished();

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
		if (d_cancellable == null)
		{
			return;
		}

		d_cancellable.cancel();
		d_thread.join();

		if (d_idleid != 0)
		{
			Source.remove(d_idleid);
			d_idleid = 0;
		}

		d_thread = null;
		d_cancellable = null;

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

		walk.begin((obj, res) => {
			walk.end(res);
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
					d_thread.join();
					d_thread = null;
					d_cancellable = null;

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

		d_cancellable = new Cancellable();
		uint limit = this.limit;

		SourceFunc cb = walk.callback;

		ThreadFunc<void*> run = () => {
			if (d_walker == null)
			{
				try
				{
					d_walker = new Ggit.RevisionWalker(d_repository);
					d_walker.set_sort_mode(Ggit.SortMode.TOPOLOGICAL |
					                       Ggit.SortMode.TIME);
				}
				catch
				{
					notify_batch(true);
					return null;
				}
			}

			d_walker.reset();

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
					commit = d_repository.lookup(id, typeof(Gitg.Commit)) as Gitg.Commit;
				} catch { break; }

				// Add the id
				if (d_ids.length == size)
				{
					lock(d_ids)
					{
						size *= 2;

						d_ids.resize((int)size);
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
			d_thread = Thread.create<void*>(run, true);
			yield;
		}
		catch
		{
			emit_finished();
			d_cancellable = null;
		}
	}
}

}

// ex:set ts=4 noet
