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

	private string date_for_display(DateTime dt, TimeZone time_zone)
	{
		TimeSpan t = (new DateTime.now_local()).difference(dt);
		
		float time_in_seconds = (float) t / TimeSpan.SECOND;
		float time_in_hours = (float) t / TimeSpan.HOUR;
		
		if (time_in_seconds < 60)
		{
			return "A minute ago";
		}
		else if (time_in_seconds < 60 * 30)
		{
			return "%d minutes ago".printf((int) Math.round(time_in_seconds / 60));
		}
		else if (time_in_seconds < 60 * 45)
		{
			return "Half an hour ago";
		}
		else if (time_in_hours < 23.5)
		{
			int rounded_hours = (int) Math.round(time_in_hours);
			return rounded_hours == 1 ? "An hour ago" : "%d hours ago".printf(rounded_hours);
		}
		else if (time_in_hours < 24 * 7)
		{
			int rounded_days = (int) Math.round(time_in_hours / 24);
			return rounded_days == 1 ? "A day ago" : "%d days ago".printf(rounded_days);
		}
		// FIXME: Localize these date formats, Bug 699196
		else if (dt.get_year() == new DateTime.now_local().get_year())
		{
			return dt.to_timezone(time_zone).format("%h %e, %I:%M %P");
		}
		return dt.to_timezone(time_zone).format("%h %e %Y, %I:%M %P");
	}

	public string committer_date_for_display
	{
		owned get
		{
			return date_for_display(get_committer().get_time(), get_committer().get_time_zone());
		}
	}

	public string author_date_for_display
	{
		owned get
		{
			return date_for_display(get_author().get_time(), get_author().get_time_zone());
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
		catch {}

		return diff;
	}
}

}

// ex:set ts=4 noet
