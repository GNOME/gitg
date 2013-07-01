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
 * Panel interfaces implemented to show additional details of selections in
 * the history.
 *
 * The panel interface can be implemented to show additional details of the
 * history activity. The panel will be shown in a split view below the history
 * when activated. Panels should implement the {@link UIElement.available} property to
 * indicate for which state of the application the panel is active.
 *
 * Each panel should have a unique id, a display name and an icon which will
 * be used in the interface to activate the panel. The {@link UIElement.widget} is
 * displayed when the panel is activated.
 *
 */
public interface HistoryPanel : Object, UIElement
{
	/**
	 * The history to which the panel belongs. This property is a construct
	 * property and will be automatically set when an instance of the panel
	 * is created.
	 */
	public abstract GitgExt.History? history { owned get; construct set; }
}

}

// ex: ts=4 noet
