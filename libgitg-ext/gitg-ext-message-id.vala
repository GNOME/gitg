namespace GitgExt
{

public class MessageId : Object
{
	public string object_path { construct set; get; }
	public string method { construct set; get; }

	public string id
	{
		owned get { return object_path + "." + method; }
	}

	public uint hash()
	{
		return id.hash();
	}

	public bool equal(MessageId other)
	{
		return id == other.id;
	}

	public MessageId(string object_path, string method)
	{
		Object(object_path: object_path, method: method);
	}

	public MessageId copy()
	{
		return new MessageId(object_path, method);
	}

	public static bool valid_object_path(string path)
	{
		if (path == null)
		{
			return false;
		}

		if (path[0] != '/')
		{
			return false;
		}

		int i = 0;

		while (i < path.length)
		{
			var c = path[i];

			if (c == '/')
			{
				++i;

				if (i == path.length || !(c.isalpha() || c == '_'))
				{
					return false;
				}
			}
			else if (!(c.isalnum() || c == '_'))
			{
				return false;
			}

			++i;
		}

		return true;
	}
}

}

// ex:set ts=4 noet:
