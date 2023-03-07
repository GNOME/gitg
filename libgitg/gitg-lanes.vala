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

public class Lanes : Object
{
	public int inactive_max { get; set; default = 30; }
	public int inactive_collapse { get; set; default = 10; }
	public int inactive_gap { get; set; default = 10; }
	public bool inactive_enabled { get; set; default = true; }
	public Gee.LinkedList<Commit> miss_commits {get; set; }

	private SList<weak Commit> d_previous;
	private Gee.LinkedList<LaneContainer> d_lanes;
	private HashTable<Ggit.OId, CollapsedLane> d_collapsed;
	private Gee.HashSet<Ggit.OId>? d_roots;

	class LaneContainer
	{
		public Lane lane;
		public int inactive;
		public Ggit.OId? from;
		public Ggit.OId? to;

		public LaneContainer.with_color(Ggit.OId? from,
		                                Ggit.OId? to,
		                                Color?    color)
		{
			this.from = from;
			this.to = to;
			this.lane = new Lane.with_color(color);
			this.inactive = 0;
		}

		public LaneContainer(Ggit.OId? from,
		                     Ggit.OId? to)
		{
			this.with_color(from, to, null);
		}

		public void next(int index)
		{
			var hidden = is_hidden;
			lane = lane.copy();

			lane.tag = LaneTag.NONE;
			lane.from = new SList<int>();

			if (!hidden)
			{
				lane.from.prepend(index);
			}

			is_hidden = hidden;

			if (to != null && inactive >= 0)
			{
				++inactive;
			}
		}

		public bool is_hidden
		{
			get { return (lane.tag & LaneTag.HIDDEN) != 0; }
			set
			{
				if (value)
				{
					lane.tag |= LaneTag.HIDDEN;
				}
				else
				{
					lane.tag &= ~LaneTag.HIDDEN;
				}
			}
		}
	}

	[Compact]
	class CollapsedLane
	{
		public Color color;
		public uint index;
		public Ggit.OId? from;
		public Ggit.OId? to;

		public CollapsedLane(LaneContainer container)
		{
			color = container.lane.color;
			from = container.from;
			to = container.to;
		}
	}

	public Lanes()
	{
		d_collapsed = new HashTable<Ggit.OId, CollapsedLane>(Ggit.OId.hash,
		                                                     Ggit.OId.equal);

		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.history");

		settings.bind("collapse-inactive-lanes-enabled",
		              this,
		              "inactive-enabled",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		settings.bind("collapse-inactive-lanes",
		              this,
		              "inactive-collapse",
		              SettingsBindFlags.GET | SettingsBindFlags.SET);

		reset();
	}

	public void reset(Ggit.OId[]?            reserved = null,
	                  Gee.HashSet<Ggit.OId>? roots    = null)
	{
		d_lanes = new Gee.LinkedList<LaneContainer>();
		miss_commits = new Gee.LinkedList<Commit>();
		d_roots = roots;

		Color.reset();

		if (reserved != null)
		{
			foreach (var r in reserved)
			{
				var ct = new LaneContainer(null, r);
				ct.inactive = -1;
				ct.is_hidden = true;

				d_lanes.add(ct);
			}
		}

		d_collapsed.remove_all();
		d_previous = new SList<weak Commit>();
	}

	public bool next(Commit           next,
	                 out SList<Lane> lanes,
	                 out int         nextpos,
	                 bool save_miss = false)
	{
		var myoid = next.get_id();

		if (inactive_enabled)
		{
			collapse_lanes();
			expand_lanes(next);
		}

		debug("commit: %s %s", next.get_subject(), next.get_id().to_string());
		LaneContainer? mylane = find_lane_by_oid(myoid, out nextpos);
		if (mylane == null && d_roots != null && !d_roots.contains(myoid))
		{
			lanes = null;
			if (save_miss) {
				debug ("saving miss %s %s", next.get_id().to_string(), next.get_id().to_string());
				miss_commits.add(next);
			}

			return false;
		}

		if (mylane == null)
		{
			// there is no lane reserved for this commit, add a new lane
			mylane = new LaneContainer(myoid, null);

			d_lanes.add(mylane);
			nextpos = (int)d_lanes.size - 1;
		}
		else
		{
			// copy the color here because the commit is a new stop
			mylane.lane.color = mylane.lane.color.copy();

			mylane.to = null;
			mylane.from = next.get_id();

			if (mylane.is_hidden && d_roots != null && d_roots.contains(myoid))
			{
				mylane.is_hidden = false;
				mylane.lane.from = new SList<int>();
			}

			if (mylane.inactive >= 0)
			{
				mylane.inactive = 0;
			}
		}

		var hidden = mylane.is_hidden;

		lanes = lanes_list();
		prepare_lanes(next, nextpos, hidden);

		return !hidden;
	}

	private void prepare_lanes(Commit next, int pos, bool hidden)
	{
		var parents = next.get_parents();
		var myoid = next.get_id();

		if (!hidden)
		{
			init_next_layer();
		}

		var mylane = d_lanes[pos];

		for (uint i = 0; i < parents.size; ++i)
		{
			int lnpos;
			var poid = parents.get_id(i);

			var container = find_lane_by_oid(poid, out lnpos);

			if (container != null)
			{
				// there is already a lane for this parent. This means that
				// we add pos as a merge for the lane.
				if (i == 0 && pos < lnpos)
				{
					// we are at the mainline of a merge, and this parent has
					// already been assigned to an existing lane, if our
					// lane's pos is smaller, then the this parent should be in
					// our lane instead.
					mylane.to = poid;
					mylane.from = myoid;

					if (!container.is_hidden)
					{
						mylane.lane.from.append(lnpos);
						mylane.is_hidden = false;
					}

					mylane.lane.color = mylane.lane.color.copy();

					if (mylane.inactive >= 0)
					{
						mylane.inactive = 0;
					}

					d_lanes.remove(container);
				}
				else
				{
					container.from = myoid;

					if (!hidden)
					{
						container.lane.from.append(pos);
					}

					container.lane.color = container.lane.color.copy();

					if (!hidden)
					{
						container.is_hidden = false;
					}

					if (container.inactive >= 0)
					{
						container.inactive = 0;
					}
				}

				continue;
			}
			else if (mylane != null && mylane.to == null)
			{
				// there is no parent yet which can proceed on the current
				// commit lane, so set it now
				mylane.to = poid;

				mylane.lane.color = mylane.lane.color.copy();
			}
			else if (!hidden)
			{
				// generate a new lane for this parent
				var newlane = new LaneContainer(myoid, poid);

				newlane.lane.from.prepend(pos);
				d_lanes.add(newlane);
			}
		}

		if (mylane != null && mylane.to == null)
		{
			// remove current lane if no longer needed (i.e. merged)
			d_lanes.remove(mylane);
		}

		// store new commit in track list
		if (d_previous.length() == inactive_collapse + inactive_gap + 1)
		{
			d_previous.delete_link(d_previous.last());
		}

		d_previous.prepend(next);
	}

	private void add_collapsed(LaneContainer container,
	                           int           index)
	{
		var collapsed = new CollapsedLane(container);
		collapsed.index = index;

		d_collapsed.insert(container.to, (owned)collapsed);
	}

	private void collapse_lane(LaneContainer container,
	                           int           index)
	{
		add_collapsed(container, index);

		unowned SList<weak Commit> item = d_previous;

		while (item != null)
		{
			var commit = item.data;
			unowned SList<Lane> lns = commit.get_lanes();

			if (lns != null && index < lns.length())
			{
				unowned Lane lane = lns.nth_data(index);

				if (item.next != null && lane.from != null)
			        {
					var newindex = lane.from.data;

					lns = commit.remove_lane(lane);

					if (item.next.next != null)
					{
						update_merge_indices(lns, newindex, -1);
					}

					var mylane = commit.mylane;

					if (mylane > index)
					{
						--commit.mylane;
					}

					index = newindex;
				}
				else
				{
					lane.tag |= LaneTag.END;
					lane.boundary_id = container.to;
				}
			}

			item = item.next;
		}
	}

	private void collapse_lanes()
	{
		int index = 0;

		var iter = d_lanes.iterator();

		while (iter.next())
		{
			var container = iter.get();

			if (container.inactive != inactive_max + inactive_gap)
			{
				++index;
				continue;
			}

			collapse_lane(container, container.lane.from.data);
			update_current_lane_merge_indices(index, -1);

			iter.remove();
		}
	}

	private int ensure_correct_index(Commit commit,
	                                 int    index)
	{
		var len = commit.get_lanes().length();

		if (index > len)
		{
			return (int)len;
		}
		else
		{
			return index;
		}
	}

	private void update_lane_merge_indices(SList<int> from,
	                                       int        index,
	                                       int        direction)
	{
		while (from != null)
		{
			int idx = from.data;

			if (idx > index || (direction > 0 && idx == index))
			{
				from.data = idx + direction;
			}

			from = from.next;
		}
	}

	private void update_merge_indices(SList<Lane> lanes,
	                                  int         index,
	                                  int         direction)
	{
		foreach (unowned Lane lane in lanes)
		{
			update_lane_merge_indices(lane.from, index, direction);
		}
	}
	private void update_current_lane_merge_indices(int index,
	                                               int direction)
	{
		foreach (var container in d_lanes)
		{
			update_lane_merge_indices(container.lane.from,
			                          index,
			                          direction);
		}
	}

	private void expand_lane(CollapsedLane lane)
	{
		var index = lane.index;
		var ln = new Lane.with_color(lane.color);
		var len = d_lanes.size;

		if (index > len)
		{
			index = len;
		}

		var next = ensure_correct_index(d_previous.data, (int)index);

		var container = new LaneContainer.with_color(lane.from,
		                                             lane.to,
		                                             lane.color);

		update_current_lane_merge_indices((int)index, 1);

		container.lane.from.prepend(next);
		d_lanes.insert((int)index, container);

		index = next;
		uint cnt = 0;

		unowned SList<weak Commit> ptr = d_previous;

		while (ptr != null)
		{
			var commit = ptr.data;

			if (cnt == inactive_collapse)
			{
				break;
			}

			// Insert new lane at the index
			Lane copy = ln.copy();
			unowned SList<Lane> lns = commit.get_lanes();

			if (ptr.next == null || cnt + 1 == inactive_collapse)
			{
				copy.boundary_id = lane.from;
				copy.tag |= LaneTag.START;
			}
			else
			{
				next = ensure_correct_index(ptr.next.data, (int)index);
				copy.from.prepend(next);

				update_merge_indices(lns, (int)index, 1);
			}

			commit.insert_lane(copy, (int)index);

			var mylane = commit.mylane;

			if (mylane >= index)
			{
				++commit.mylane;
			}

			index = next;
			++cnt;

			ptr = ptr.next;
		}
	}

	private void expand_lane_from_oid(Ggit.OId id)
	{
		unowned CollapsedLane? collapsed = d_collapsed.lookup(id);

		if (collapsed != null)
		{
			expand_lane(collapsed);
			d_collapsed.remove(id);
		}
	}

	private void expand_lanes(Commit commit)
	{
		expand_lane_from_oid(commit.get_id());

		var parents = commit.get_parents();

		for (uint i = 0; i < parents.size; ++i)
		{
			expand_lane_from_oid(parents.get_id(i));
		}
	}

	private void init_next_layer()
	{
		int index = 0;

		foreach (var container in d_lanes)
		{
			container.next(index++);
		}
	}

	private LaneContainer? find_lane_by_oid(Ggit.OId id,
	                                        out int  pos)
	{
		int p = 0;

		foreach (var container in d_lanes)
		{
			if (container != null &&
			    id.equal(container.to))
			{
				pos = p;
				return container;
			}

			++p;
		}

		pos = -1;
		return null;
	}

	private SList<Lane> lanes_list()
	{
		var ret = new SList<Lane>();

		foreach (var container in d_lanes)
		{
			ret.append(container.lane.copy());
		}

		return ret;
	}
}

}

// ex:set ts=4 noet
