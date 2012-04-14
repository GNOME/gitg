namespace GitgExt
{

public interface Application : Object
{
	public abstract Gitg.Repository? repository { owned get; }
	public abstract GitgExt.MessageBus message_bus { owned get; }
	public abstract GitgExt.View? current_view { owned get; }

	public abstract GitgExt.View? view(string id);

	public abstract void open(File repository);
	public abstract void create(File repository);
	public abstract void close();
}

}

// ex:set ts=4 noet:
