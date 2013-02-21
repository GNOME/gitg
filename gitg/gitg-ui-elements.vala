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
		public Gtk.RadioButton? navigation_button;

		public ActiveUIElement(GitgExt.UIElement e)
		{
			element = e;
		}
	}

	private Peas.ExtensionSet d_extensions;
	private HashTable<string, ActiveUIElement> d_available_elements;
	private HashTable<string, GitgExt.UIElement> d_elements;
	private List<ActiveUIElement> d_available_sorted;
	private Gtk.Box? d_box;
	private ActiveUIElement? d_current;
	private Gd.Stack d_stack;

	public signal void activated(GitgExt.UIElement element);

	private Gtk.RadioButton? create_header_button(GitgExt.UIElement e)
	{
		if (d_box == null)
		{
			return null;
		}

		Icon? icon = e.icon;

		if (icon == null)
		{
			return null;
		}

		var img = new Gtk.Image.from_gicon(icon, Gtk.IconSize.MENU);
		img.show();

		Gtk.RadioButton button;

		if (d_box.get_children().length() != 0)
		{
			var ic = d_box.get_children();
			button = new Gtk.RadioButton.from_widget(ic.data as Gtk.RadioButton);
		}
		else
		{
			button = new Gtk.RadioButton(null);
		}

		e.bind_property("enabled", button, "sensitive", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);

		button.set_mode(false);
		button.set_image(img);

		var context = button.get_style_context();
		context.add_class("image-button");

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
			else if (wasavail != null && wasavail.navigation_button != null)
			{
				if (!wasavail.element.enabled && d_current == wasavail)
				{
					d_current = null;
				}
				else if (wasavail.element.enabled && d_current == null)
				{
					set_current_impl(wasavail.element);
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

			if (d_stack != null)
			{
				d_stack.set_visible_child(el.element.widget);
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
				d_available_sorted.remove(ae);
				ae.navigation_button.destroy();
			}

			if (ae == d_current)
			{
				d_current = null;
			}

			d_stack.remove(ae.element.widget);
			d_available_elements.remove(e.id);
		}
	}

	private void add_available(GitgExt.UIElement e)
	{
		Gtk.RadioButton? button = create_header_button(e);
		ActiveUIElement ae = new ActiveUIElement(e);

		ae.navigation_button = button;

		if (button != null)
		{
			d_available_sorted.insert_sorted(ae, (a, b) => {
				return a.element.negotiate_order(b.element);
			});

			d_box.pack_start(button);
			d_box.reorder_child(button, d_available_sorted.index(ae));
			update_visibility();

			button.toggled.connect((b) => {
				if (b.active)
				{
					set_current_impl(ae.element);
				}
			});
		}

		d_stack.add(ae.element.widget);
		d_available_elements.insert(e.id, ae);
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

	private void on_box_add_remove(Gtk.Widget box,
	                               Gtk.Widget item)
	{
		update_visibility();
	}

	private void update_visibility()
	{
		d_box.visible = (d_box.get_children().length() > 1);
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
	                  Gd.Stack? stack = null,
	                  Gtk.Box? box = null)
	{
		d_extensions = extensions;
		d_box = box;
		d_stack = stack;

		d_available_elements = new HashTable<string, ActiveUIElement>(str_hash, str_equal);
		d_elements = new HashTable<string, GitgExt.UIElement>(str_hash, str_equal);

		if (d_box != null)
		{
			var context = d_box.get_style_context();
			context.add_class("linked");
			context.add_class("raised");

			d_box.add.connect(on_box_add_remove);
			d_box.remove.connect(on_box_add_remove);

			update_visibility();
		}

		// Add all the extensions
		d_extensions.foreach(extension_added);
		d_extensions.extension_added.connect(extension_added);
		d_extensions.extension_removed.connect(extension_removed);

		if (d_current == null && d_available_sorted != null)
		{
			set_current_impl(d_available_sorted.data.element);
		}
	}
}

}

// ex:ts=4 noet
