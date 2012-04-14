namespace Gitg
{

[Compact]
public class Lane
{
	[Flags]
	public enum Tag
	{
		NONE = 0,
		START = 1 << 0,
		END = 1 << 1,
		SIGN_STASH = 1 << 2,
		SIGN_STAGED = 1 << 3,
		SIGN_UNSTAGED = 1 << 4
	}

	public Color color;
	public SList<int> from;
	public Tag tag;
	public Ggit.OId? boundary_id;

	public Lane()
	{
		this.with_color(null);
	}

	public Lane.with_color(Color? color)
	{
		if (color != null)
		{
			this.color = color;
		}
		else
		{
			this.color = Color.next();
		}
	}

	public Lane copy()
	{
		Lane ret = new Lane.with_color(color);
		ret.from = from.copy();
		ret.tag = tag;
		ret.boundary_id = boundary_id;

		return ret;
	}

	public Lane dup()
	{
		Lane ret = new Lane.with_color(color.copy());
		ret.from = from.copy();
		ret.tag = tag;
		ret.boundary_id = boundary_id;

		return ret;
	}
}

}

// ex:set ts=4 noet
