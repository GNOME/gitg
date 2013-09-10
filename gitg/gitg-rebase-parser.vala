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

		public Gee.ArrayList<Gee.ArrayList<string>> parse_rebase_todo(string filename)
		{
			string contents;
			int line_number=0;
			Gee.ArrayList<Gee.ArrayList<string>> rebase_array = new Gee.ArrayList<Gee.ArrayList<string>> ();
			try
			{
				FileUtils.get_contents(filename, out contents);
			}
			catch {}

			var file_lines = contents.split("\n");
			while (file_lines[line_number][0] != '#' && file_lines[line_number] != "")
			{
				string current_line = file_lines[line_number];
				var line_words = current_line.split(" ");
				Gee.ArrayList<string> rebase_row = new Gee.ArrayList<string>();
				rebase_row.add(line_words[0]);
				rebase_row.add(line_words[1]);
				rebase_row.add(string.joinv(" ", line_words[2:line_words.length-1]));
				rebase_array.add(rebase_row);
				line_number++;
			}

			return rebase_array;
		}

		public string generate_rebase_todo(string[,] rebase_array)
		{
			// Write function to generate rebase todo file back again
			return "";
		}
	}
}
