/*
 * This file is part of gitg
 *
 * Copyright (C) 2013 - Sindhu S
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
	public class RebaseParser
	{
		public RebaseParser()
		{
		}

		public void parse_rebase_todo(string filename)
		{
			string contents;
			int line_number=0;

			try
			{
				FileUtils.get_contents(filename, out contents);
			}
			catch{}

			var file_lines = contents.split("\n");
			while (file_lines[line_number][0] != '#')
			{
				stdout.printf("\n" + file_lines[line_number]);
				line_number++;
			}
		}
	}
}
