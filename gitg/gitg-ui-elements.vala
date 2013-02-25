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

public class UIElements<T>
{
	private Peas.ExtensionSet d_extensions;
	private HashTable<string, GitgExt.UIElement> d_available_elements;
	private HashTable<string, GitgExt.UIElement> d_elements;
	private GitgExt.UIElement? d_current;
	private Gd.Stack d_stack;

	public signal void activated(GitgExt.UIElement element);

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

	public void update()
	{
		// Update active elements based on availability
		d_extensions.foreach((extset, info, obj) => {
			var elem = obj as GitgExt.UIElement;

			var wasavail = d_available_elements.lookup(elem.id);
			bool isavail = elem.available;

			if (wasavail != null && !isavail)
			{
				remove_available(elem);
			}
			else if (wasavail == null && isavail)
			{
				// Note that this will also set elem to current if needed
				add_available(elem);
			}
			else if (wasavail != null)
			{
				if (!wasavail.enabled && d_current == wasavail)
				{
					d_current = null;
				}
				else if (wasavail.enabled && d_current == null)
				{
					set_current_impl(wasavail);
				}
			}
		});
	}

	public T? lookup(string id)
	{
		return (T)d_elements.lookup(id);
	}

	private void set_current_impl(GitgExt.UIElement element)
	{
		if (!element.available ||
		    !element.enabled ||
		    (d_current != null && d_current == element))
		{
			return;
		}

		GitgExt.UIElement? el = d_available_elements.lookup(element.id);

		if (el != null)
		{
			d_current = el;

			if (d_stack != null)
			{
				d_stack.set_visible_child(el.widget);
			}

			activated(el);
		}
	}

	private void remove_available(GitgExt.UIElement e)
	{
		GitgExt.UIElement ae;

		if (d_available_elements.lookup_extended(e.id, null, out ae))
		{
			if (ae == d_current)
			{
				d_current = null;
			}

			d_stack.remove(ae.widget);
			d_available_elements.remove(e.id);
		}
	}

	private void add_available(GitgExt.UIElement e)
	{
		d_stack.add_with_properties(e.widget,
		                            "title", e.display_name,
		                            "symbolic-icon-name", e.icon);
		d_available_elements.insert(e.id, e);
	}

	private void available_changed(Object o, ParamSpec spec)
	{
		update();
	}

	private void add_ui_element(GitgExt.UIElement e)
	{
		d_elements.insert(e.id, e);

		if (e.available)
		{
			add_available(e);
		}

		e.notify["available"].connect(available_changed);
	}

	private void remove_ui_element(GitgExt.UIElement e)
	{
		remove_available(e);

		e.notify["available"].disconnect(available_changed);

		d_elements.remove(e.id);
	}

	private void extension_added(Peas.ExtensionSet s,
	                             Peas.PluginInfo info,
	                             Object obj)
	{
		add_ui_element(obj as GitgExt.UIElement);
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
		var vals = d_available_elements.get_values();

		foreach (var val in vals)
		{
			if (!func(val))
			{
				break;
			}
		}
	}

	public UIElements(Peas.ExtensionSet extensions,
	                  Gd.Stack? stack = null)
	{
		d_extensions = extensions;
		d_stack = stack;

		d_available_elements = new HashTable<string, GitgExt.UIElement>(str_hash, str_equal);
		d_elements = new HashTable<string, GitgExt.UIElement>(str_hash, str_equal);

		// Add all the extensions
		d_extensions.foreach(extension_added);
		d_extensions.extension_added.connect(extension_added);
		d_extensions.extension_removed.connect(extension_removed);
	}
}

}

// ex:ts=4 noet
