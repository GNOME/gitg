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
	private class ActiveUIElement
	{
		public GitgExt.UIElement element;
		public Gtk.RadioToolButton? navigation_button;

		public ActiveUIElement(GitgExt.UIElement e)
		{
			element = e;
		}
	}

	private Peas.ExtensionSet d_extensions;
	private HashTable<string, ActiveUIElement> d_available_elements;
	private HashTable<string, GitgExt.UIElement> d_elements;
	private Gtk.Toolbar? d_toolbar;
	private ActiveUIElement? d_current;
	private Gtk.Bin d_container;

	public signal void activated(GitgExt.UIElement element);

	private Gtk.RadioToolButton? create_toolbar_button(GitgExt.UIElement e)
	{
		if (d_toolbar == null)
		{
			return null;
		}

		Icon? icon = e.icon;

		if (icon == null)
		{
			return null;
		}

		var img = new Gtk.Image.from_gicon(icon, d_toolbar.get_icon_size());
		img.show();

		Gtk.RadioToolButton button;

		if (d_toolbar.get_n_items() != 0)
		{
			var ic = d_toolbar.get_nth_item(0);
			button = new Gtk.RadioToolButton.from_widget(ic as Gtk.RadioToolButton);
		}
		else
		{
			button = new Gtk.RadioToolButton(null);
		}

		button.set_icon_widget(img);
		button.set_label(e.display_name);

		button.show();

		return button;
	}

	public T? current
	{
		get
		{
			if (d_current != null)
			{
				return (T)d_current.element;
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
			bool isavail = elem.is_available();

			if (wasavail != null && !isavail)
			{
				remove_available(elem);
			}
			else if (wasavail == null && isavail)
			{
				// Note that this will also set elem to current if needed
				add_available(elem);
			}
			else if (wasavail != null && wasavail.navigation_button != null)
			{
				if (!wasavail.element.is_enabled() && d_current == wasavail)
				{
					d_current = null;
				}
				else if (wasavail.element.is_enabled() && d_current == null)
				{
					set_current_impl(wasavail.element);
				}

				wasavail.navigation_button.set_sensitive(wasavail.element.is_enabled());
			}
		});
	}

	public T? lookup(string id)
	{
		return (T)d_elements.lookup(id);
	}

	private void set_current_impl(GitgExt.UIElement element)
	{
		if (!element.is_available() ||
		    !element.is_enabled() ||
		    (d_current != null && d_current.element == element))
		{
			return;
		}

		ActiveUIElement? el = d_available_elements.lookup(element.id);

		if (el != null)
		{
			if (d_current != null)
			{
				if (d_current.navigation_button != null)
				{
					d_current.navigation_button.active = false;
				}
			}

			d_current = el;

			if (el.navigation_button != null)
			{
				el.navigation_button.active = true;
			}

			if (d_container != null)
			{
				var child = d_container.get_child();

				if (child != null)
				{
					d_container.remove(child);
				}

				var widget = el.element.widget;

				if (widget != null)
				{
					widget.show();
				}

				d_container.add(widget);
				d_container.show();
			}

			activated(el.element);
		}
	}

	private void remove_available(GitgExt.UIElement e)
	{
		ActiveUIElement ae;

		if (d_available_elements.lookup_extended(e.id, null, out ae))
		{
			if (ae.navigation_button != null)
			{
				ae.navigation_button.destroy();
			}

			if (ae == d_current)
			{
				d_current = null;
			}

			d_available_elements.remove(e.id);
		}
	}

	private void add_available(GitgExt.UIElement e)
	{
		Gtk.RadioToolButton? button = create_toolbar_button(e);
		ActiveUIElement ae = new ActiveUIElement(e);

		ae.navigation_button = button;

		if (button != null)
		{
			button.set_sensitive(e.is_enabled());

			d_toolbar.add(button);
		}

		button.toggled.connect((b) => {
			if (b.active)
			{
				set_current_impl(ae.element);
			}
		});

		d_available_elements.insert(e.id, ae);

		if (d_current == null && e.is_enabled())
		{
			set_current_impl(ae.element);
		}
	}

	private void add_ui_element(GitgExt.UIElement e)
	{
		d_elements.insert(e.id, e);

		if (e.is_available())
		{
			add_available(e);
		}
	}

	private void remove_ui_element(GitgExt.UIElement e)
	{
		remove_available(e);
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

	private void on_toolbar_add_remove(Gtk.Widget toolbar,
	                                   Gtk.Widget item)
	{
		update_visibility();
	}

	private void update_visibility()
	{
		d_toolbar.visible = (d_toolbar.get_n_items() > 1);
	}

	public delegate bool ForeachUIElementFunc(GitgExt.UIElement element);

	public void foreach(ForeachUIElementFunc func)
	{
		var vals = d_available_elements.get_values();

		foreach (var val in vals)
		{
			if (!func(val.element))
			{
				break;
			}
		}
	}

	public UIElements(Peas.ExtensionSet extensions,
	                  Gtk.Bin? container = null,
	                  Gtk.Toolbar? toolbar = null)
	{
		d_extensions = extensions;
		d_toolbar = toolbar;
		d_container = container;

		d_available_elements = new HashTable<string, ActiveUIElement>(str_hash, str_equal);
		d_elements = new HashTable<string, GitgExt.UIElement>(str_hash, str_equal);

		if (d_toolbar != null)
		{
			d_toolbar.add.connect(on_toolbar_add_remove);
			d_toolbar.remove.connect(on_toolbar_add_remove);

			update_visibility();
		}

		// Add all the extensions
		d_extensions.foreach(extension_added);
		d_extensions.extension_added.connect(extension_added);
		d_extensions.extension_removed.connect(extension_removed);
	}
}

}

// ex:ts=4 noet
