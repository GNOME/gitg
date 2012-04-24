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
			return get_subject().replace(" ", "-").replace("/", "-");;
		}
	}

	private string date_for_display(DateTime dt)
	{
		return dt.format("%c");
	}

	public string committer_date_for_display
	{
		owned get
		{
			return date_for_display(get_committer().get_time());
		}
	}

	public string author_date_for_display
	{
		owned get
		{
			return date_for_display(get_author().get_time());
		}
	}
}

}

// ex:set ts=4 noet
