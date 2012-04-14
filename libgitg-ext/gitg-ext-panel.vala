namespace GitgExt
{

public interface Panel : Object
{
	public abstract Application? application { owned get; construct; }

	public abstract string id { owned get; }
	public abstract string display_name { owned get; }
	public abstract Icon? icon { owned get; }

	public abstract bool supported { get; }
	public abstract Gtk.Widget? widget { owned get; }
}

}

// ex: ts=4 noet
