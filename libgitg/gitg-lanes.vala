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
	public int inactive_max { get; set; }
	public int inactive_collapse { get; set; }
	public int inactive_gap { get; set; }
	public bool inactive_enabled { get; set; }

	private SList<Commit> d_previous;
	private SList<LaneContainer> d_lanes;
	private HashTable<Ggit.OId, CollapsedLane> d_collapsed;

	[Compact]
	class LaneContainer
	{
		public Lane lane;
		public uint inactive;
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
			lane = lane.copy();

			lane.tag = LaneTag.NONE;
			lane.from = new SList<int>();
			lane.from.prepend(index);

			if (to != null)
			{
				++inactive;
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

		reset();
	}

	public void reset()
	{
		d_previous = new SList<Commit>();
		d_lanes = new SList<LaneContainer>();

		Color.reset();

		d_collapsed.remove_all();
	}

	public SList<Lane> next(Commit  next,
	                        out int nextpos)
	{
		var myoid = next.get_id();

		if (inactive_enabled)
		{
			collapse_lanes();
			expand_lanes(next);
		}

		unowned LaneContainer? mylane = find_lane_by_oid(myoid, out nextpos);

		if (mylane == null)
		{
			// there is no lane reserver for this comit, add a new lane
			d_lanes.append(new LaneContainer(myoid, null));
			nextpos = (int)d_lanes.length() - 1;
		}
		else
		{
			// copy the color here because the commit is a new stop
			mylane.lane.color = mylane.lane.color.copy();

			mylane.to = null;
			mylane.from = next.get_id();
			mylane.inactive = 0;
		}

		var res = lanes_list();
		prepare_lanes(next, nextpos);

		return res;
	}

	private void prepare_lanes(Commit next, int pos)
	{
		var parents = next.get_parents();
		var myoid = next.get_id();

		init_next_layer();
		unowned LaneContainer mylane = d_lanes.nth_data(pos);

		for (uint i = 0; i < parents.size(); ++i)
		{
			int lnpos;
			var poid = parents.get_id(i);

			unowned LaneContainer? container = find_lane_by_oid(poid, out lnpos);

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
					mylane.lane.from.append(lnpos);
					mylane.lane.color = mylane.lane.color.copy();
					mylane.inactive = 0;
					d_lanes.remove(container);
				}
				else
				{
					container.from = myoid;
					container.lane.from.append(pos);
					container.lane.color = container.lane.color.copy();
					container.inactive = 0;
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
			else
			{
				// generate a new lane for this parent
				LaneContainer newlane = new LaneContainer(myoid, poid);

				newlane.lane.from.prepend(pos);
				d_lanes.append((owned)newlane);
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

		unowned SList<Commit> item = d_previous;

		while (item != null)
		{
			var commit = item.data;
			unowned SList<Lane> lns = commit.get_lanes();
			unowned Lane lane = lns.nth_data(index);

			if (item.next != null)
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

			item = item.next;
		}
	}

	private void collapse_lanes()
	{
		int index = 0;
		unowned SList<LaneContainer> item = d_lanes;

		while (item != null)
		{
			unowned LaneContainer container = item.data;

			if (container.inactive != inactive_max + inactive_gap)
			{
				item = item.next;
				++index;
				continue;
			}

			collapse_lane(container, container.lane.from.data);
			update_current_lane_merge_indices(index, -1);

			unowned SList<LaneContainer> next = item.next;
			d_lanes.remove_link(item);
			item = next;
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
		foreach (unowned LaneContainer container in d_lanes)
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
		var len = d_lanes.length();

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
		d_lanes.insert((owned)container, (int)index);

		index = next;
		uint cnt = 0;

		unowned SList<Commit> ptr = d_previous;

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

		for (uint i = 0; i < parents.size(); ++i)
		{
			expand_lane_from_oid(parents.get_id(i));
		}
	}

	private void init_next_layer()
	{
		int index = 0;

		foreach (unowned LaneContainer container in d_lanes)
		{
			container.next(index++);
		}
	}

	private unowned LaneContainer? find_lane_by_oid(Ggit.OId id,
	                                                out int  pos)
	{
		int p = 0;
		unowned SList<LaneContainer> ptr = d_lanes;

		while (ptr != null)
		{
			unowned LaneContainer? container = ptr.data;

			if (container != null &&
			    id.equal(container.to))
			{
				pos = p;
				return container;
			}

			++p;
			ptr = ptr.next;
		}

		pos = -1;
		return null;
	}

	private SList<Lane> lanes_list()
	{
		var ret = new SList<Lane>();

		foreach (unowned LaneContainer container in d_lanes)
		{
			ret.prepend(container.lane.copy());
		}

		ret.reverse();
		return ret;
	}
}

}

// ex:set ts=4 noet
