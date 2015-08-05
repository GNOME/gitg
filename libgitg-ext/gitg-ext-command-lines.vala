/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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
	public class CommandLines : Object
	{
		private CommandLine[] d_command_lines;

		public CommandLines(CommandLine[] command_lines)
		{
			d_command_lines = command_lines;
		}

		public T? get_for<T>()
		{
			foreach (var cmd in d_command_lines)
			{
				if (cmd.get_type() == typeof(T))
				{
					return (T)cmd;
				}
			}

			return null;
		}

		public void parse_finished()
		{
			foreach (var cmd in d_command_lines)
			{
				cmd.parse_finished();
			}
		}

		public void apply(Application application)
		{
			foreach (var cmd in d_command_lines)
			{
				cmd.apply(application);
			}
		}
	}
}

// vi:ts=4
