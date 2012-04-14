namespace Gitg
{

public class Commit : Ggit.Commit
{
	public Lane.Tag tag { get; set; }
	public unowned SList<Lane> lanes { get; set; }

	private ushort d_mylane;

	public ushort mylane
	{
		get	{ return d_mylane; }
		set
		{
			d_mylane = value;
			update_lane_tag();
		}
	}

	public unowned Lane lane
	{
		get { return lanes.nth_data(d_mylane); }
	}

	public unowned SList<Lane> remove_lane(Lane lane)
	{
		lanes.remove(lane);
		return lanes;
	}

	private void update_lane_tag()
	{
		unowned Lane? lane = lanes.nth_data(d_mylane);

		if (lane == null)
		{
			return;
		}

		lane.tag &= ~(Lane.Tag.SIGN_STASH |
		              Lane.Tag.SIGN_STAGED |
		              Lane.Tag.SIGN_UNSTAGED) | tag;
	}

	public void update_lanes(SList<Lane> lanes, int mylane)
	{
		this.lanes = lanes;

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
