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

public class Commit : Ggit.Commit
{
	public LaneTag tag { get; set; }

	private uint d_mylane;
	private SList<Lane> d_lanes;

	public unowned SList<Lane> get_lanes()
	{
		return d_lanes;
	}

	public uint mylane
	{
		get	{ return d_mylane; }
		set
		{
			d_mylane = value;
			update_lane_tag();
		}
	}

	public Lane lane
	{
		get { return d_lanes.nth_data(d_mylane); }
	}

	public unowned SList<Lane> insert_lane(Lane lane, int idx)
	{
		d_lanes.insert(lane, idx);
		return d_lanes;
	}

	public unowned SList<Lane> remove_lane(Lane lane)
	{
		d_lanes.remove(lane);
		return d_lanes;
	}

	private void update_lane_tag()
	{
		unowned Lane? lane = d_lanes.nth_data(d_mylane);

		if (lane == null)
		{
			return;
		}

		lane.tag &= ~(LaneTag.SIGN_STASH |
		              LaneTag.SIGN_STAGED |
		              LaneTag.SIGN_UNSTAGED) | tag;
	}

	public void update_lanes(owned SList<Lane> lanes, int mylane)
	{
		d_lanes = (owned)lanes;

		if (mylane >= 0)
		{
			d_mylane = (ushort)mylane;
		}

		update_lane_tag();
	}

	public string format_patch_name
	{
		owned get
		{
			return get_subject().replace(" ", "-").replace("/", "-");
		}
	}

	public string committer_date_for_display
	{
		owned get
		{
			var dt = get_committer().get_time();
			return (new Date.for_date_time(dt)).for_display();
		}
	}

	public string author_date_for_display
	{
		owned get
		{
			var dt = get_author().get_time();
			return (new Date.for_date_time(dt)).for_display();
		}
	}

	public Ggit.Diff get_diff(Ggit.DiffOptions? options)
	{
		Ggit.Diff? diff = null;

		var repo = get_owner();

		try
		{
			var parents = get_parents();

			// Create a new diff from the parents to the commit tree
			if (parents.size() == 0)
			{
				diff = new Ggit.Diff.tree_to_tree(repo,
				                                  null,
				                                  get_tree(),
				                                  options);
			}
			else
			{
				for (var i = 0; i < parents.size(); ++i)
				{
					var parent = parents.get(0);

					if (i == 0)
					{
						diff = new Ggit.Diff.tree_to_tree(repo,
						                                  parent.get_tree(),
						                                  get_tree(),
						                                  options);
					}
					else
					{
						var d = new Ggit.Diff.tree_to_tree(repo,
						                                   parent.get_tree(),
						                                   get_tree(),
						                                   options);

						diff.merge(d);
					}
				}
			}
		}
		catch {}

		return diff;
	}
}

}

// ex:set ts=4 noet
