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

public class Hook : Object
{
	public Gee.HashMap<string, string> environment { get; set; }
	public string name { get; set; }
	public string[] arguments { get; set; }
	public File? working_directory { get; set; }

	private string[] d_output;

	public string[] output
	{
		owned get { return d_output; }
	}

	construct
	{
		environment = new Gee.HashMap<string, string>();
	}

	public Hook(string name)
	{
		Object(name: name);
	}

	private string[]? flat_environment()
	{
		if (environment.size == 0)
		{
			return null;
		}

		var env = Environment.list_variables();

		var ret = new string[env.length + environment.size];
		ret.length = 0;

		foreach (var e in env)
		{
			if (!environment.has_key(e))
			{
				ret += "%s=%s".printf(e, Environment.get_variable(e));
			}
		}

		foreach (var e in environment.keys)
		{
			ret += "%s=%s".printf(e, environment[e]);
		}

		return ret;
	}

	private void stream_read_async(DataInputStream stream)
	{
		stream.read_line_async.begin(Priority.HIGH_IDLE, null, (obj, res) => {
			try
			{
				var s = stream.read_line_async.end(res);

				if (s.length != 0)
				{
					d_output += s;

					// Continue reading
					stream_read_async(stream);
				}
			}
			catch {}
		});
	}

	private void read_from_fd(int fd)
	{
		var stream = new UnixInputStream(fd, true);
		var dstream = new DataInputStream(stream);

		stream_read_async(dstream);
	}

	public async int run(Ggit.Repository repository) throws SpawnError
	{
		File? wd = working_directory;
		SourceFunc callback = run.callback;

		d_output = new string[256];
		d_output.length = 0;

		if (wd == null)
		{
			wd = repository.get_workdir();
		}

		var hooksdir = repository.get_location().get_child("hooks");
		var script = hooksdir.resolve_relative_path(name);
		var args = new string[arguments.length + 1];

		args.length = 0;

		args += script.get_path();

		foreach (var a in arguments)
		{
			args += a;
		}

		Pid pid;
		int pstdout;
		int pstderr;

		Process.spawn_async_with_pipes(wd.get_path(),
		                               args,
		                               flat_environment(),
		                               SpawnFlags.DO_NOT_REAP_CHILD,
		                               null,
		                               out pid,
		                               null,
		                               out pstdout,
		                               out pstderr);

		read_from_fd(pstdout);
		read_from_fd(pstderr);

		int status = 0;

		ChildWatch.add(pid, (p, st) => {
			status = st;

			Process.close_pid(p);
			callback();
		}, Priority.LOW);

		yield;

		return status;
	}
}

}

// ex: ts=4 noet
