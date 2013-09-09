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
//			string[,] rebase_array = {};

			try
			{
				FileUtils.get_contents(filename, out contents);
			}
			catch(Glib.Error e)
			{
				stdout.printf("The file does not exist!");
			}

			var file_lines = contents.split("\n");
			while (file_lines[line_number][0] != '#' && file_lines[line_number] != "")
			{
				string[] temp_array = new string [3];
				string current_line = file_lines[line_number];
				var line_words = current_line.split(" ");
				temp_array[0] = line_words[0];
				temp_array[1] = line_words[1];
				temp_array[2] = string.joinv(" ", line_words[2:line_words.length-1]);
//				rebase_array += temp_array;
				stdout.printf("\naction: %s sha: %s msg: %s\n", temp_array[0], temp_array[1], temp_array[2]);
				line_number++;
			}


		}
	}
}
