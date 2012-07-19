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

namespace GitgExt
{

public delegate void MessageCallback(GitgExt.Message message);

public class MessageBus : Object
{
	class Listener
	{
		public uint id;
		public bool blocked;

		public MessageCallback callback;

		public Listener(uint id, owned MessageCallback callback)
		{
			this.id = id;

			// TODO: destroy notify is lost...
			this.callback = (owned)callback;
			this.blocked = false;
		}
	}

	class Message
	{
		public MessageId id;
		public List<Listener> listeners;

		public Message(MessageId id)
		{
			this.id = id.copy();
			this.listeners = new List<Listener>();
		}
	}

	class IdMap
	{
		public Message message;
		public unowned List<Listener> listener;

		public IdMap(Message message)
		{
			this.message = message;
		}
	}

	private HashTable<MessageId, Message> d_messages;
	private HashTable<uint, IdMap> d_idmap;
	private HashTable<MessageId, Type> d_types;
	private static MessageBus? s_instance;
	private static uint s_next_id;

	public signal void registered(MessageId id);
	public signal void unregistered(MessageId id);

	public virtual signal void dispatch(GitgExt.Message message)
	{
		Message? msg = lookup_message(message.id, false);

		if (msg != null)
		{
			dispatch_message_real(msg, message);
		}
	}

	public MessageBus()
	{
		d_messages = new HashTable<MessageId, Message>(MessageId.hash, MessageId.equal);
		d_idmap = new HashTable<uint, IdMap>(direct_hash, direct_equal);
		d_types = new HashTable<MessageId, Type>(MessageId.hash, MessageId.equal);
	}

	public static MessageBus get_default()
	{
		if (s_instance == null)
		{
			s_instance = new MessageBus();
			s_instance.add_weak_pointer(&s_instance);
		}

		return s_instance;
	}

	private void dispatch_message_real(Message msg, GitgExt.Message message)
	{
		foreach (Listener l in msg.listeners)
		{
			if (!l.blocked)
			{
				l.callback(message);
			}
		}
	}

	public Type lookup(MessageId id)
	{
		Type ret;

		if (!d_types.lookup_extended(id, null, out ret))
		{
			return Type.INVALID;
		}
		else
		{
			return ret;
		}
	}

	public void register(Type message_type, MessageId id)
	{
		if (is_registered(id))
		{
			warning("Message type for `%s' is already registered", id.id);
			return;
		}

		var cp = id.copy();

		d_types.insert(cp, message_type);

		registered(cp);
	}

	private void unregister_real(MessageId id, bool remove_from_store)
	{
		var cp = id;

		if (!remove_from_store || d_types.remove(cp))
		{
			unregistered(cp);
		}
	}

	public void unregister(MessageId id)
	{
		unregister_real(id, true);
	}

	public void unregister_all(string object_path)
	{
		d_types.foreach_remove((key, val) => {
			if (key.object_path == object_path)
			{
				unregister_real(key, true);
				return true;
			}
			else
			{
				return false;
			}
		});
	}

	public bool is_registered(MessageId id)
	{
		return d_types.lookup_extended(id, null, null);
	}

	private Message new_message(MessageId id)
	{
		var ret = new Message(id);

		d_messages.insert(id, ret);
		return ret;
	}

	private Message? lookup_message(MessageId id, bool create)
	{
		var message = d_messages.lookup(id);

		if (message == null && !create)
		{
			return null;
		}

		if (message == null)
		{
			message = new_message(id);
		}

		return message;
	}

	private uint add_listener(Message message, owned MessageCallback callback)
	{
		var listener = new Listener(++s_next_id, (owned)callback);

		message.listeners.append(listener);

		var idmap = new IdMap(message);
		idmap.listener = message.listeners.last();

		d_idmap.insert(listener.id, idmap);
		return listener.id;
	}

	private void remove_listener(Message message, List<Listener> listener)
	{
		unowned Listener lst = listener.data;

		d_idmap.remove(lst.id);

		message.listeners.delete_link(listener);

		if (message.listeners == null)
		{
			d_messages.remove(message.id);
		}
	}

	private void block_listener(Message message, List<Listener> listener)
	{
		listener.data.blocked = true;
	}

	private void unblock_listener(Message message, List<Listener> listener)
	{
		listener.data.blocked = false;
	}

	public new uint connect(MessageId id, owned MessageCallback callback)
	{
		var message = lookup_message(id, true);

		return add_listener(message, (owned)callback);
	}

	private delegate void MatchCallback(Message message, List<Listener> listeners);

	private void process_by_id(uint id, MatchCallback processor)
	{
		IdMap? idmap = d_idmap.lookup(id);

		if (idmap == null)
		{
			return;
		}

		processor(idmap.message, idmap.listener);
	}

	public new void disconnect(uint id)
	{
		process_by_id(id, remove_listener);
	}

	public void block(uint id)
	{
		process_by_id(id, block_listener);
	}

	public void unblock(uint id)
	{
		process_by_id(id, unblock_listener);
	}

	private void dispatch_message(GitgExt.Message message)
	{
		dispatch(message);
	}

	public GitgExt.Message send_message(GitgExt.Message message)
	{
		dispatch_message(message);
		return message;
	}

	public GitgExt.Message? send(MessageId id, string? firstprop, ...)
	{
		Type type = lookup(id);

		if (type == Type.INVALID)
		{
			warning("Could not find message type for `%s'", id.id);
			return null;
		}

		GitgExt.Message? msg = (GitgExt.Message?)Object.new_valist(type, firstprop, va_list());

		if (msg != null)
		{
			msg.id = id;
		}

		dispatch_message(msg);

		return msg;
	}
}

}

// ex:set ts=4 noet:
