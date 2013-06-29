/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Jesse van den Kieboom
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

public class Stage : Object
{
	private Repository d_repository;
	private StageStatusEnumerator ?d_enumerator;

	internal Stage(Repository repository)
	{
		d_repository = repository;
	}

	public StageStatusEnumerator file_status()
	{
		if (d_enumerator == null)
		{
			d_enumerator = new StageStatusEnumerator(d_repository);
		}

		return d_enumerator;
	}
}

}

// ex:set ts=4 noet
