namespace Gitg
{

public class Color : Object
{
	private struct Rgb
	{
		ushort r;
		ushort g;
		ushort b;
	}

	private static const Rgb[] palette = {
		{196, 160, 0},
		{78, 154, 6},
		{206, 92, 0},
		{32, 74, 135},
		{46, 52, 54},
		{108, 53, 102},
		{164, 0, 0},

		{138, 226, 52},
		{252, 175, 62},
		{114, 159, 207},
		{252, 233, 79},
		{136, 138, 133},
		{173, 127, 168},
		{233, 185, 110},
		{239, 41, 41}
	};

	private static uint current_index;

	public uint idx = 0;

	public static void reset()
	{
		current_index = 0;
	}

	public void components(out double r, out double g, out double b)
	{
		r = palette[idx].r / 255.0;
		g = palette[idx].g / 255.0;
		b = palette[idx].b / 255.0;
	}

	private static uint inc_index()
	{
		uint next = current_index++;

		if (current_index == palette.length)
		{
			current_index = 0;
		}

		return next;
	}

	public static Color next()
	{
		Color ret = new Color();
		ret.idx = inc_index();

		return ret;
	}

	public Color next_index()
	{
		this.idx = inc_index();
		return this;
	}

	public Color copy()
	{
		Color ret = new Color();
		ret.idx = idx;

		return ret;
	}
}

}

// ex:set ts=4 noet
