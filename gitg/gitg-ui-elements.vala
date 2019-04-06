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

namespace Gitg
{

public class UIElements<T> : Object
{
	private Peas.ExtensionSet d_extensions;
	private Gee.HashMap<string, GitgExt.UIElement> d_elements;
	private List<GitgExt.UIElement> d_available_elements;
	private GitgExt.UIElement? d_current;
	private Gtk.Stack d_stack;
	private Gee.HashMap<string, int> d_builtin_elements;

	public T? current
	{
		get
		{
			if (d_current != null)
			{
				return (T)d_current;
			}
			else
			{
				return null;
			}
		}
		set
		{
			if (value != null)
			{
				set_current_impl((GitgExt.UIElement)value);
			}
		}
	}

	public T[] get_available_elements()
	{
		var ret = new T[0];

		foreach (var elem in d_available_elements)
		{
			ret += (T)elem;
		}

		return ret;
	}

	public void update()
	{
		// Update active elements based on availability
		foreach (var elem in d_elements.values)
		{
			bool wasavail = is_available(elem);
			bool isavail = elem.available;

			if (wasavail && !isavail)
			{
				remove_available(elem);
			}
			else if (!wasavail && isavail)
			{
				add_available(elem);
			}
			else if (wasavail)
			{
				if (!elem.enabled && d_current == elem)
				{
					d_current = null;
				}
			}
		}

		set_first_enabled_current();
	}

	private void set_first_enabled_current()
	{
		if (d_current != null)
		{
			return;
		}

		foreach (var item in d_available_elements)
		{
			if (item.enabled)
			{
				set_current_impl(item);
				break;
			}
		}
	}

	public T? lookup(string id)
	{
		return (T)d_elements[id];
	}

	private bool is_available(GitgExt.UIElement element)
	{
		return d_available_elements.find(element) != null;
	}

	private void set_current_impl(GitgExt.UIElement element)
	{
		if (!element.available ||
		    !element.enabled ||
		    (d_current != null && d_current == element) ||
		    !is_available(element))
		{
			return;
		}

		if (d_current == element)
		{
			return;
		}

		d_current = element;

		if (d_stack != null)
		{
			d_stack.set_visible_child(element.widget);
		}

		notify_property("current");
		element.activate();
	}

	private void remove_available(GitgExt.UIElement e)
	{
		if (!is_available(e))
		{
			return;
		}

		if (e == d_current)
		{
			d_current = null;
		}

		d_stack.remove(e.widget);
		d_available_elements.remove(e);
	}

	private bool order_after(GitgExt.UIElement a, GitgExt.UIElement b)
	{
		var ab = d_builtin_elements.has_key(a.id);
		var bb = d_builtin_elements.has_key(b.id);

		if (ab != bb)
		{
			return ab ? false : true;
		}

		if (ab && bb)
		{
			int ai = d_builtin_elements[a.id];
			int bi = d_builtin_elements[b.id];

			return ai > bi;
		}

		return a.negotiate_order(b) > 0;
	}

	private void add_available(GitgExt.UIElement e)
	{
		int insert_position = 0;
		unowned List<GitgExt.UIElement> item = d_available_elements;

		while (item != null && order_after(e, item.data))
		{
			item = item.next;
			insert_position++;
		}

		d_available_elements.insert(e, insert_position);

		d_stack.add_with_properties(e.widget,
		                            "name", e.id,
		                            "title", e.description,
		                            "icon-name", e.icon,
		                            "position", insert_position);
	}

	private void available_changed(Object o, ParamSpec spec)
	{
		update();
	}

	private void enabled_changed(Object o, ParamSpec spec)
	{
		var e = o as GitgExt.UIElement;
		e.widget.sensitive = e.enabled;
	}

	private void on_element_activate(GitgExt.UIElement e)
	{
		set_current_impl(e);
	}

	private void add_ui_element(GitgExt.UIElement e)
	{
		d_elements[e.id] = e;

		if (e.available)
		{
			add_available(e);
		}

		e.notify["available"].connect(available_changed);
		e.notify["enabled"].connect(enabled_changed);
		
		e.activate.connect(on_element_activate);
	}

	private void remove_ui_element(GitgExt.UIElement e)
	{
		remove_available(e);

		e.notify["available"].disconnect(available_changed);
		e.activate.disconnect(on_element_activate);

		d_elements.unset(e.id);
	}

	private void extension_initial(Peas.ExtensionSet s,
	                               Peas.PluginInfo info,
	                               Object obj)
	{
		add_ui_element(obj as GitgExt.UIElement);
	}

	private void extension_added(Peas.ExtensionSet s,
	                             Peas.PluginInfo info,
	                             Object obj)
	{
		add_ui_element(obj as GitgExt.UIElement);
		set_first_enabled_current();
	}

	private void extension_removed(Peas.ExtensionSet s,
	                               Peas.PluginInfo info,
	                               Object obj)
	{
		remove_ui_element(obj as GitgExt.UIElement);
	}

	public delegate bool ForeachUIElementFunc(GitgExt.UIElement element);

	public void foreach(ForeachUIElementFunc func)
	{
		var vals = d_available_elements.copy();

		foreach (var val in vals)
		{
			if (!func(val))
			{
				break;
			}
		}
	}

	private void on_visible_child_changed(Object obj, ParamSpec pspec)
	{
		string? name = d_stack.get_visible_child_name();

		if (name != null)
		{
			set_current_impl(d_elements[name]);
		}
	}

	public UIElements.with_builtin(T[] builtin,
	                               Peas.ExtensionSet extensions,
	                               Gtk.Stack? stack = null)
	{
		d_extensions = extensions;
		d_stack = stack;
		d_builtin_elements = new Gee.HashMap<string, int>();

		d_elements = new Gee.HashMap<string, GitgExt.UIElement>();

		int i = 0;

		foreach (var b in builtin)
		{
			GitgExt.UIElement elem = (GitgExt.UIElement)b;

			d_builtin_elements[elem.id] = i++;
			add_ui_element(elem);
		}

		// Add all the extensions
		d_extensions.foreach(extension_initial);
		set_first_enabled_current();

		d_extensions.extension_added.connect(extension_added);
		d_extensions.extension_removed.connect(extension_removed);

		if (d_stack != null)
		{
			d_stack.notify["visible-child"].connect(on_visible_child_changed);
		}
	}

	public UIElements(Peas.ExtensionSet extensions,
	                  Gtk.Stack? stack = null)
	{
		this.with_builtin(new T[] {}, extensions, stack);
	}
}

}

// ex:ts=4 noet
