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
	public class RebaseController
	{
		public RebaseController()
		{}

		public void start_rebase()
		{
			string gitg_path = "";
			string git_path = "";

			gitg_path = Environment.find_program_in_path("gitg");
			git_path = Environment.find_program_in_path("git");
			stdout.printf("gitg path: %s\n", gitg_path);
			stdout.printf("git path: %s\n", git_path);
		}
	}
}