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

		private static bool process_line (IOChannel channel, IOCondition condition, string stream_name) {
			if (condition == IOCondition.HUP) {
				stdout.printf ("%s: The fd has been closed.\n", stream_name);
				return false;
			}

			try {
				string line;
				channel.read_line (out line, null, null);
				stdout.printf ("%s: %s", stream_name, line);
			} catch (IOChannelError e) {
				stdout.printf ("%s: IOChannelError: %s\n", stream_name, e.message);
				return false;
			} catch (ConvertError e) {
				stdout.printf ("%s: ConvertError: %s\n", stream_name, e.message);
				return false;
			}

			return true;
		}

		public void start_rebase(Gtk.Window parent, Gitg.Repository repository)
		{
			string gitg_path = "";
			string git_path = "";

			gitg_path = Environment.find_program_in_path("gitg");
			git_path = Environment.find_program_in_path("git");
			stdout.printf("gitg path: %s\n", gitg_path);
			stdout.printf("git path: %s\n", git_path);

			File? workdir = repository.get_workdir();
			string repo_path = workdir.get_path();

			string[] spawn_args = {"/usr/bin/git", "rebase", "-i", "HEAD~5"};
			string[] spawn_env = Environ.get ();
			Environ.set_variable(spawn_env, "GIT_SEQUENCE_EDITOR", "jhbuild run gitg --rebase");
			Environ.set_variable(spawn_env, "GIT_EDITOR", "jhbuild run gitg --rebase-commit-editor");
			Pid child_pid;

			int standard_input;
			int standard_output;
			int standard_error;

			Process.spawn_async_with_pipes (repo_path,
				spawn_args,
				spawn_env,
				SpawnFlags.SEARCH_PATH,
				null,
				out child_pid,
				out standard_input,
				out standard_output,
				out standard_error
			);

// stdout:
		IOChannel output = new IOChannel.unix_new (standard_output);
		output.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
			return process_line (channel, condition, "stdout");
		});

		// stderr:
		IOChannel error = new IOChannel.unix_new (standard_error);
		error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
			return process_line (channel, condition, "stderr");
		});

		}
	}
}