namespace GitgExt
{

public abstract class Message : Object
{
	private MessageId d_id;

	public MessageId id
	{
		construct set
		{
			d_id = value.copy();
		}
		get
		{
			return d_id;
		}
	}

	public bool has(string propname)
	{
		return get_class().find_property(propname) != null;
	}

	public static bool type_has(Type type, string propname)
	{
		return ((ObjectClass)type.class_ref()).find_property(propname) != null;
	}

	public static bool type_check(Type type, string propname, Type value_type)
	{
		ParamSpec? spec = ((ObjectClass)type.class_ref()).find_property(propname);

		return (spec != null && spec.value_type == value_type);
	}
}

}

// ex:set ts=4 noet:
