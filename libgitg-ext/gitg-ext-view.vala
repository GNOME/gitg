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
 * A view action.
 *
 * A view action indicates a user preference to open gitg in a particular view.
 */
public enum ViewAction
{
	/**
	 * Open gitg in the History view.
	 */
	HISTORY,

	/**
	 * Open gitg in the Commit view.
	 */
	COMMIT,

	/**
	 * Open gitg in the default view.
	 */
	DEFAULT = HISTORY
}

/**
 * gitg View interface.
 *
 * The GitgExtView interface can be implemented to provide a main view in
 * gitg. An example of such views are the builtin Dashboard, History and
 * Commit views.
 *
 * Implementations of the GitgExtView interface will be integrated
 * automatically in the gitg interface according to the various interface
 * methods and properties that need to be implemented.
 *
 * To provide a default navigation when the view is active, the
 * #GitgExtView::navigation property should be implemented and should return a
 * non-null #GitgExtNavigation. This navigation section will always be present
 * at the top of the navigation menu. Note that you should normally ''not''
 * export this type to Peas because you will end up having the navigation
 * shown twice in the UI.
 */
public interface View : Object, UIElement
{
	/**
	 * Main navigation for the view.
	 *
	 * When provided, the corresponding navigation
	 * section will be added in the navigation panel when the view is activated.
	 */
	public abstract Navigation? navigation { owned get; }

	/**
	 * Check whether the view is the default view for a particular action.
	 *
	 * Implement this method when a view should be the preferred default view
	 * for a particular action. The first available view indicating to be
	 * a default view will be used as the default activated view when launching
	 * gitg (or when opening a repository).
	 *
	 * @param action the action
	 *
	 * @return ``true`` if the view is a default for @action, ``false`` otherwise.
	 *
	 */
	public abstract bool is_default_for(string action);
}

}

// ex: ts=4 noet
