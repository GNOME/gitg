namespace GitgExt
{

public enum NavigationSide
{
	LEFT = 0,
	TOP = 1
}

public interface Navigation : Object
{
	public abstract Application? application { owned get; construct; }

	public abstract void populate(GitgExt.NavigationTreeModel model);
	public abstract bool available { get; }

	public abstract NavigationSide navigation_side { get; }
}

}

// ex:set ts=4 noet:
