/*
 * This file is part of gitg
 *
 * Copyright (C) 2016 - Jesse van den Kieboom
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

interface Gitg.DiffViewFileRendererTextable : DiffSelectable, DiffViewFileRenderer
{
	public abstract bool wrap_lines { get; set; }
	public abstract new int tab_width { get; set; }
	public abstract int maxlines { get; set; }
	public abstract bool highlight { get; construct set; }
}

// ex:ts=4 noet
