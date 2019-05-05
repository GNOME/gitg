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
	public enum CommitModelColumns
	{
		SHA1,
		SUBJECT,
		MESSAGE,
		AUTHOR,
		AUTHOR_NAME,
		AUTHOR_EMAIL,
		AUTHOR_DATE,
		COMMITTER,
		COMMITTER_NAME,
		COMMITTER_EMAIL,
		COMMITTER_DATE,
		COMMIT,
		NUM;

		public Type type()
		{
			switch (this)
			{
				case SHA1:
				case SUBJECT:
				case MESSAGE:
				case COMMITTER:
				case COMMITTER_NAME:
				case COMMITTER_EMAIL:
				case COMMITTER_DATE:
				case AUTHOR:
				case AUTHOR_NAME:
				case AUTHOR_EMAIL:
				case AUTHOR_DATE:
					return typeof(string);
				case COMMIT:
					return typeof(Commit);
				default:
				break;
			}

			return Type.INVALID;
		}
	}

	public class CommitModel : Object, Gtk.TreeModel
	{
		private Repository d_repository;
		private Cancellable? d_cancellable;
		private Commit[] d_ids;
		private Commit[] d_hidden_ids;
		private Thread<void*>? d_thread;
		private Ggit.RevisionWalker? d_walker;
		private uint d_advertized_size;
		private uint d_idleid;
		private Lanes d_lanes;
		private Ggit.SortMode d_sortmode;
		private Gee.HashMap<Ggit.OId, int> d_id_hash;

		private Ggit.OId[] d_include;
		private Ggit.OId[] d_exclude;

		private uint d_size;
		private int d_stamp;

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

		public Repository repository
		{
			get { return d_repository; }
			set
			{
				if (d_repository == value)
				{
					return;
				}

				cancel();

				d_walker = null;
				d_repository = value;
			}
		}

		private Ggit.OId[] _permanent_lanes;

		public Ggit.OId[] get_permanent_lanes() {
			return _permanent_lanes;
		}

		public void set_permanent_lanes(Ggit.OId[] value) {
			_permanent_lanes = value;
		}

		public signal void started();
		public signal void update(uint added);
		public signal void finished();

		public signal void begin_clear();
		public signal void end_clear();

		public CommitModel(Repository? repository)
		{
			Object(repository: repository);
		}

		construct
		{
			d_lanes = new Lanes();
			d_sortmode = Ggit.SortMode.TOPOLOGICAL | Ggit.SortMode.TIME;
		}

		public override void dispose()
		{
			cancel();
		}

		private void cancel()
		{
			if (d_cancellable != null)
			{
				var cancellable = d_cancellable;
				d_cancellable = null;

				cancellable.cancel();

				d_thread.join();
				d_thread = null;
			}

			lock(d_idleid)
			{
				if (d_idleid != 0)
				{
					Source.remove(d_idleid);
					d_idleid = 0;
				}
			}

			clear();

			d_ids = new Commit[0];
			d_hidden_ids = new Commit[0];
			d_advertized_size = 0;

			d_id_hash = new Gee.HashMap<Ggit.OId, int>();
		}

		public void reload()
		{
			cancel();

			if (d_repository == null || get_include().length == 0)
			{
				return;
			}

			var cancellable = new Cancellable();
			d_cancellable = cancellable;

			started();

			walk.begin(cancellable, (obj, res) => {
				walk.end(res);

				d_thread.join();
				d_thread = null;

				finished();
				d_cancellable = null;
			});
		}

		public uint size()
		{
			return d_advertized_size;
		}

		public new Commit? @get(uint idx)
		{
			Commit? ret;

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

		public void set_include(Ggit.OId[] ids)
		{
			this.d_include = ids;
		}

		public Ggit.OId[] get_include()
		{
			return this.d_include;
		}

		public void set_exclude(Ggit.OId[] ids)
		{
			this.d_exclude = ids;
		}

		private void notify_batch(owned SourceFunc? finishedcb)
		{
			lock(d_idleid)
			{
				if (d_idleid != 0)
				{
					Source.remove(d_idleid);
					d_idleid = 0;
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

						if (finishedcb != null)
						{
							finishedcb();
						}
					}

					return false;
				});
			}
		}

		private bool needs_resize(Gitg.Commit[] ids, ref uint size)
		{
			if (ids.length < size)
			{
				return false;
			}

			if (ids.length < 20000)
			{
				size *= 2;
			}
			else
			{
				size = (uint)((double)size * 1.2);
			}

			return true;
		}

		private async void walk(Cancellable cancellable)
		{
			Ggit.OId[] included = d_include;
			Ggit.OId[] excluded = d_exclude;

			uint limit = this.limit;

			SourceFunc cb = walk.callback;

			// First time, wait a bit longer to make loading small repositories
			// subjectively quicker
			var wait_elapsed_initial = 1.0;

			// After initial wait elapsed, continue with incremental updates at
			// a quicker pace
			var wait_elapsed_incremental = 0.2;

			var wait_elapsed = wait_elapsed_initial;

			var permlanes = get_permanent_lanes();

			ThreadFunc<void*> run = () => {
				if (d_walker == null)
				{
					try
					{
						d_walker = new Ggit.RevisionWalker(d_repository);
					}
					catch
					{
						notify_batch((owned)cb);
						return null;
					}
				}

				d_walker.reset();
				d_walker.set_sort_mode(d_sortmode);

				var incset = new Gee.HashSet<Ggit.OId>((Gee.HashDataFunc<Ggit.OId>)Ggit.OId.hash,
				                                       (Gee.EqualDataFunc<Ggit.OId>)Ggit.OId.equal);

				foreach (Ggit.OId oid in included)
				{
					try
					{
						d_walker.push(oid);
						incset.add(oid);
					} catch {};
				}

				foreach (Ggit.OId oid in excluded)
				{
					try
					{
						d_walker.hide(oid);
						incset.remove(oid);
					} catch {};
				}

				var permanent = new Ggit.OId[0];

				foreach (Ggit.OId oid in permlanes)
				{
					try
					{
						d_walker.push(oid);
						permanent += oid;
					} catch {}
				}

				d_lanes.reset(permanent, incset);

				uint size;
				uint hidden_size;

				// Pre-allocate array to store commits
				lock(d_ids)
				{
					d_ids = new Commit[1000];
					d_hidden_ids = new Commit[100];

					size = d_ids.length;
					hidden_size = d_hidden_ids.length;

					d_ids.length = 0;
					d_hidden_ids.length = 0;

					d_advertized_size = 0;
				}

				Timer timer = new Timer();

				lock(d_id_hash)
				{
					d_id_hash = new Gee.HashMap<Ggit.OId, int>((i) => { return i.hash(); }, (a, b) => { return a.equal(b); });
				}

				while (true)
				{
					Ggit.OId? id;
					Commit? commit;

					if (cancellable.is_cancelled())
					{
						return null;
					}

					try
					{
						id = d_walker.next();

						if (id == null)
						{
							break;
						}

						commit = d_repository.lookup<Commit>(id);
					} catch { break; }

					int mylane;
					SList<Lane> lanes;

					bool finded = d_lanes.next(commit, out lanes, out mylane, true);
					if (finded)
					{
						debug ("finded parent for %s %s\n", commit.get_subject(), commit.get_id().to_string());
						commit.update_lanes((owned)lanes, mylane);

						lock(d_id_hash)
						{
							d_id_hash.set(id, d_ids.length);
						}

						if (needs_resize(d_ids, ref size))
						{
							var l = d_ids.length;

							lock(d_ids)
							{
								d_ids.resize((int)size);
								d_ids.length = l;
							}
						}

						d_ids[d_ids.length++] = commit;
					}
					while (d_lanes.miss_commits.size > 0)
					{
						finded = false;
						var iter = d_lanes.miss_commits.iterator();
						while (iter.next())
						{
							var miss_commit = iter.get();
							debug ("trying again %s %s", miss_commit.get_subject(), miss_commit.get_id().to_string());
							bool tmp_finded = d_lanes.next(miss_commit, out lanes, out mylane);
							if (tmp_finded)
							{
								finded = true;
								debug ("finded parent for miss %s %s\n", miss_commit.get_subject(), miss_commit.get_id().to_string());
								iter.remove();
								commit = miss_commit;

								commit.update_lanes((owned)lanes, mylane);

								lock(d_id_hash)
								{
									d_id_hash.set(id, d_ids.length);
								}

								if (needs_resize(d_ids, ref size))
								{
									var l = d_ids.length;

									lock(d_ids)
									{
										d_ids.resize((int)size);
										d_ids.length = l;
									}
								}

								d_ids[d_ids.length++] = commit;
							}
						}
						if (!finded)
							break;
					}

					if (!finded)
					{
						if (needs_resize(d_hidden_ids, ref hidden_size))
						{
							var l = d_hidden_ids.length;

							d_hidden_ids.resize((int)hidden_size);
							d_hidden_ids.length = l;
						}

						d_hidden_ids[d_hidden_ids.length++] = commit;
					}

					if (timer.elapsed() >= wait_elapsed)
					{
						notify_batch(null);
						timer.start();

						wait_elapsed = wait_elapsed_incremental;
					}

					if (limit > 0 && d_ids.length == limit)
					{
						break;
					}
				}

				notify_batch((owned)cb);
				return null;
			};

			try
			{
				d_thread = new Thread<void*>.try("gitg-history-walk", (owned)run);
			}
			catch
			{
				d_thread = null;
				return;
			}

			yield;
		}

		private void clear()
		{
			begin_clear();

			// Remove all
			var path = new Gtk.TreePath.from_indices(d_size);

			while (d_size > 0)
			{
				path.prev();
				--d_size;

				row_deleted(path.copy());
			}

			++d_stamp;

			end_clear();
		}

		private void emit_update(uint added)
		{
			var path = new Gtk.TreePath.from_indices(d_size);

			Gtk.TreeIter iter = Gtk.TreeIter();
			iter.stamp = d_stamp;

			for (uint i = 0; i < added; ++i)
			{
				iter.user_data = (void *)(ulong)d_size;

				++d_size;

				row_inserted(path.copy(), iter);
				path.next();
			}

			update(added);
		}

		public Type get_column_type(int index)
		{
			return ((CommitModelColumns)index).type();
		}

		public Gtk.TreeModelFlags get_flags()
		{
			return Gtk.TreeModelFlags.LIST_ONLY |
			       Gtk.TreeModelFlags.ITERS_PERSIST;
		}

		public bool get_iter(out Gtk.TreeIter iter, Gtk.TreePath path)
		{
			iter = {};

			int[] indices = path.get_indices();

			if (indices.length != 1)
			{
				return false;
			}

			uint index = (uint)indices[0];

			if (index >= d_size)
			{
				return false;
			}

			iter.user_data = (void *)(ulong)index;
			iter.stamp = d_stamp;

			return true;
		}

		public int get_n_columns()
		{
			return CommitModelColumns.NUM;
		}

		public Gtk.TreePath? get_path(Gtk.TreeIter iter)
		{
			uint id = (uint)(ulong)iter.user_data;

			return_val_if_fail(iter.stamp == d_stamp, null);

			return new Gtk.TreePath.from_indices((int)id);
		}

		public void get_value(Gtk.TreeIter iter, int column, out Value val)
		{
			val = {};

			return_if_fail(iter.stamp == d_stamp);

			uint idx = (uint)(ulong)iter.user_data;
			Commit? commit = this[idx];

			val.init(get_column_type(column));

			if (commit == null)
			{
				return;
			}

			switch (column)
			{
				case CommitModelColumns.SHA1:
					val.set_string(commit.get_id().to_string());
				break;
				case CommitModelColumns.SUBJECT:
					val.set_string(commit.get_subject());
				break;
				case CommitModelColumns.MESSAGE:
					val.set_string(commit.get_message());
				break;
				case CommitModelColumns.COMMITTER:
					val.set_string("%s <%s>".printf(commit.get_committer().get_name(),
					                                commit.get_committer().get_email()));
				break;
				case CommitModelColumns.COMMITTER_NAME:
					val.set_string(commit.get_committer().get_name());
				break;
				case CommitModelColumns.COMMITTER_EMAIL:
					val.set_string(commit.get_committer().get_email());
				break;
				case CommitModelColumns.COMMITTER_DATE:
					val.set_string(commit.committer_date_for_display);
				break;
				case CommitModelColumns.AUTHOR:
					val.set_string("%s <%s>".printf(commit.get_author().get_name(),
					                                commit.get_author().get_email()));
				break;
				case CommitModelColumns.AUTHOR_NAME:
					val.set_string(commit.get_author().get_name());
				break;
				case CommitModelColumns.AUTHOR_EMAIL:
					val.set_string(commit.get_author().get_email());
				break;
				case CommitModelColumns.AUTHOR_DATE:
					val.set_string(commit.author_date_for_display);
				break;
				case CommitModelColumns.COMMIT:
					val.set_object(commit);
				break;
			}
		}

		public Commit? commit_from_iter(Gtk.TreeIter iter)
		{
			return_val_if_fail(iter.stamp == d_stamp, null);

			uint idx = (uint)(ulong)iter.user_data;

			return this[idx];
		}

		public Gtk.TreePath? path_from_commit(Commit commit)
		{
			lock(d_id_hash)
			{
				var id = commit.get_id();

				if (!d_id_hash.has_key(id))
				{
					return null;
				}

				return new Gtk.TreePath.from_indices(d_id_hash.get(commit.get_id()));
			}
		}

		public Commit? commit_from_path(Gtk.TreePath path)
		{
			int[] indices = path.get_indices();

			if (indices.length != 1)
			{
				return null;
			}

			return this[(uint)indices[0]];
		}

		public bool iter_children(out Gtk.TreeIter iter, Gtk.TreeIter? parent)
		{
			iter = {};

			if (parent == null)
			{
				iter.user_data = (void *)(ulong)0;
				iter.stamp = d_stamp;

				return true;
			}
			else
			{
				return_val_if_fail(parent.stamp == d_stamp, false);
				return false;
			}
		}

		public bool iter_has_child(Gtk.TreeIter iter)
		{
			return false;
		}

		public int iter_n_children(Gtk.TreeIter? iter)
		{
			if (iter == null)
			{
				return (int)d_size;
			}
			else
			{
				return_val_if_fail(iter.stamp == d_stamp, 0);
				return 0;
			}
		}

		public bool iter_next(ref Gtk.TreeIter iter)
		{
			return_val_if_fail(iter.stamp == d_stamp, false);

			uint index = (uint)(ulong)iter.user_data;
			++index;

			if (index >= d_size)
			{
				return false;
			}
			else
			{
				iter.user_data = (void *)(ulong)index;
				return true;
			}
		}

		public bool iter_nth_child(out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n)
		{
			iter = {};

			if (parent != null || (uint)n >= d_size)
			{
				return false;
			}

			iter.user_data = (void *)(ulong)n;
			iter.stamp = d_stamp;

			return true;
		}

		public bool iter_parent(out Gtk.TreeIter parent, Gtk.TreeIter iter)
		{
			parent = {};

			return_val_if_fail(iter.stamp == d_stamp, false);

			return false;
		}
	}
}

// ex:ts=4 noet
