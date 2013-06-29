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
		private Thread<void*>? d_thread;
		private Ggit.RevisionWalker? d_walker;
		private uint d_advertized_size;
		private uint d_idleid;
		private Lanes d_lanes;
		private Ggit.SortMode d_sortmode;

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

		public signal void started();
		public signal void update(uint added);
		public signal void finished();

		public CommitModel(Repository? repository)
		{
			Object(repository: repository);
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

			d_ids = new Commit[0];
			d_advertized_size = 0;

			emit_started();
			finished();
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
			d_include = ids;
		}

		public void set_exclude(Ggit.OId[] ids)
		{
			d_exclude = ids;
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
						finished();
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
					d_ids = new Commit[1000];

					size = d_ids.length;

					d_ids.length = 0;
					d_advertized_size = 0;
				}

				Timer timer = new Timer();

				while (true)
				{
					Ggit.OId? id;
					Commit? commit;

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

						commit = d_repository.lookup<Commit>(id);
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
				finished();

				d_cancellable.cancel();
				d_thread = null;
			}
		}

		private void emit_started()
		{
			clear();
			d_lanes.reset();
			started();
		}

		private void clear()
		{
			// Remove all
			var path = new Gtk.TreePath.from_indices(d_size);

			while (d_size > 0)
			{
				path.prev();
				--d_size;

				row_deleted(path.copy());
			}

			++d_stamp;
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
