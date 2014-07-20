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

/**
 * gitg UIElement interface.
 *
 */
public interface UIElement : Object
{
	/**
	 * The main gitg application interface.
	 *
	 * This property is a "construct"
	 * property and will be automatically set when an instance of the ui element
	 * object is created.
	 */
	public abstract GitgExt.Application? application { owned get; construct set; }

	/**
	 * A unique id for the ui element.
	 *
	 * Ids in gitg are normally of the form /org/gnome/gitg/...
	 */
	public abstract string id { owned get; }

	/**
	 * The display name of the ui element.
	 *
	 * This should result in a string which can
	 * be displayed in the gitg UI to identify the element.
	 */
	public abstract string display_name { owned get; }

	/**
	 * The description of the ui element.
	 *
	 * This should result in a string which can
	 * be displayed in the gitg UI to describe the element.
	 */
	public abstract string description { owned get; }

	/**
	 * The ui element icon.
	 *
	 * If provided, the icon will be used in navigation toolbars
	 * so that users can switch to the ui element.
	 */
	public virtual string? icon
	{
		owned get { return null; }
	}

	/**
	 * The ui element widget.
	 *
	 * This widget will be embedded in the gitg UI when
	 * the element is activated.
	 */
	public virtual Gtk.Widget? widget
	{
		owned get { return null; }
	}

	/**
	 * Check whether the ui element is available in the current application state.
	 *
	 * This method is used by gitg to verify whether or not a particular ui
	 * element is available given the current state of the application. If the
	 * element is not available, it will not be shown.
	 *
	 */
	public virtual bool available
	{
		get { return true; }
	}

	/**
	 * Check whether the ui element is enabled in the current application state.
	 *
	 * This method is used by gitg to verify whether or not a particular ui
	 * element is enabled (sensitive) given the current state of the application.
	 *
	 */
	public virtual bool enabled
	{
		get { return true; }
	}

	/**
	 * Negotiate the order with another UIElement.
	 *
	 * This method is used to determine the order in which elements need to
	 * appear in the UI.
	 *
	 * @return -1 if the element should appear before @other, 1 if the
	 *          element should appear after @other and 0 if the order is
	 *          unimportant.
	 *
	 */
	public virtual int negotiate_order(UIElement other)
	{
		return 0;
	}

	/**
	 * Activate the UIELement.
	 *
	 * This signal is emitted when the UIElement has been activated.
	 * Implementations can override the default handler to do any necessary
	 * setup when the ui element is activated.
	 */
	public virtual signal void activate()
	{
	}
}

}

// ex: ts=4 noet
