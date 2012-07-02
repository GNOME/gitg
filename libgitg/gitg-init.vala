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

public void init()
{
	Ggit.init();

	var factory = Ggit.ObjectFactory.get_default();

	factory.register(typeof(Ggit.Repository),
	                 typeof(Gitg.Repository));

	factory.register(typeof(Ggit.Ref),
	                 typeof(Gitg.Ref));

	factory.register(typeof(Ggit.Commit),
	                 typeof(Gitg.Commit));
}

}

// ex:set ts=4 noet
