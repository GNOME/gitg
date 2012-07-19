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
 * Panel interfaces implemented to show additional details of a particular view.
 *
 * The panel interface can be implemented to show additional details of a
 * {@link View}. The panel will be shown in a split view below the main view
 * when activated. Panels should implement the {@link is_available} method to
 * indicate for which state of the application the panel is active. This usually
 * involves checking which view is currently active using
 * {@link Application.current_view}.
 *
 * Each panel should have a unique id, a display name and an icon which will
 * be used in the interface to activate the panel. The {@link widget} is
 * displayed when the panel is activated.
 *
 */
public interface Panel : Object, UIElement
{
}

}

// ex: ts=4 noet
