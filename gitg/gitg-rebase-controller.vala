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
		private string output;
		private string repo_path;
		public RebaseController(string repository_path)
		{
			repo_path = repository_path;
			output = "";
		}

		private static string process_line (IOChannel channel, IOCondition condition, string stream_name)
		{
			string streamoutput = "";
			if (condition == IOCondition.HUP) {
				streamoutput += "%s: The fd has been closed.\n".printf(stream_name);
				return "";
			}

			try {
				string line;
				channel.read_line (out line, null, null);
				streamoutput += "%s: %s".printf(stream_name, line);
			} catch (IOChannelError e) {
				streamoutput += "%s: IOChannelError: %s\n".printf(stream_name, e.message);
				return "";
			} catch (ConvertError e) {
				streamoutput += "%s: ConvertError: %s\n".printf(stream_name, e.message);
				return "";
			}
			return streamoutput;
		}

		public void start_rebase(string range)
		{
			string gitg_path = "";
			string git_path = "";

			gitg_path = Environment.find_program_in_path("gitg");
			git_path = Environment.find_program_in_path("git");
			stdout.printf("gitg path: %s\n", gitg_path);
			stdout.printf("git path: %s\n", git_path);

			string[] spawn_args = {"/usr/bin/git", "rebase", "-i", range};
			string[] spawn_env = Environ.get ();
			spawn_env = Environ.set_variable(spawn_env, "GIT_SEQUENCE_EDITOR", "%s --rebase".printf(gitg_path), true);
			spawn_env = Environ.set_variable(spawn_env, "GIT_EDITOR", "%s --rebase-commit-editor".printf(gitg_path), true);
			Pid child_pid;

			int standard_input;
			int standard_output;
			int standard_error;

			Process.spawn_async_with_pipes (repo_path,
				spawn_args,
				spawn_env,
				SpawnFlags.SEARCH_PATH|SpawnFlags.DO_NOT_REAP_CHILD,
				null,
				out child_pid,
				out standard_input,
				out standard_output,
				out standard_error
			);
		
			// stdout:
			IOChannel iooutput = new IOChannel.unix_new (standard_output);
			iooutput.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
				string line = "";
				line = process_line (channel, condition, "stdout");
				output += line;
				return line != ""; 
			});

			// stderr:
			IOChannel error = new IOChannel.unix_new (standard_error);
			error.add_watch (IOCondition.IN | IOCondition.HUP, (channel, condition) => {
				string line = "";
				line = process_line (channel, condition, "stderr");
				output +=line;
				return line != "";
			});

			ChildWatch.add (child_pid, (pid, status) => {
				// Triggered when the child indicated by child_pid exits
				Process.close_pid (pid);
				stdout.printf("Rebase output: %s", output);
				var rebase_result_dialog = new RebaseResultDialog();
				rebase_result_dialog.set_rebase_output(output);
				rebase_result_dialog.show_all();

				if (status != 0)
				{
					this.abort_rebase();
				}
			});
		}

		public void abort_rebase()
		{
			string[] spawn_args = {"git", "rebase", "--abort"};
			string[] spawn_env = Environ.get ();
			string ls_stdout;
			string ls_stderr;
			int ls_status;

			Process.spawn_sync (repo_path,
								spawn_args,
								spawn_env,
								SpawnFlags.SEARCH_PATH,
								null,
								out ls_stdout,
								out ls_stderr,
								out ls_status);

			// Output: <File list>
			stdout.printf ("stdout:\n");
			// Output: ````
			stdout.puts (ls_stdout);
			stdout.printf ("stderr:\n");
			stdout.puts (ls_stderr);
			// Output: ``0``
			stdout.printf ("status: %d\n", ls_status);

		}
	}
}