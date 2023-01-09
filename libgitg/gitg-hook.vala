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
	private const string CONFIG_HOOKS_PATH = "core.hooksPath";

	public Gee.HashMap<string, string> environment { get; set; }
	public string name { get; set; }
	private string[] d_arguments;
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

	public void add_argument(string arg)
	{
		d_arguments += arg;
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

				if (s != null)
				{
					if (s.validate())
					{
						d_output += s;
					}

					// Continue reading
					stream_read_async(stream);
				}
			}
			catch {}
		});
	}

	private void read_from_fd(int fd)
	{
		var stream = PlatformSupport.new_input_stream_from_fd(fd, true);
		var dstream = new DataInputStream(stream);

		stream_read_async(dstream);
	}

	private File hook_file(Ggit.Repository repository)
	{
		var config = repository.get_config().snapshot();
		string? hooks_path = null;
		try {
			hooks_path = config.get_string(CONFIG_HOOKS_PATH);
		} catch {
			hooks_path = "%s/hooks".printf(repository.get_location().get_path());
		}
		var hooksdir = File.new_for_path(hooks_path);
		var script = hooksdir.resolve_relative_path(name);

		return script;
	}

	public bool exists_in(Ggit.Repository repository)
	{
		var script = hook_file(repository);

		try
		{
			var info = script.query_info(FileAttribute.ACCESS_CAN_EXECUTE,
			                             FileQueryInfoFlags.NONE);

			return info.get_attribute_boolean(FileAttribute.ACCESS_CAN_EXECUTE);
		}
		catch
		{
			return false;
		}
	}

	public int run_sync(Ggit.Repository repository) throws SpawnError
	{
		var m = new MainLoop();
		SpawnError? e = null;
		int status = 0;

		run.begin(repository, (obj, res) => {
			try
			{
				status = run.end(res);
			}
			catch (SpawnError err)
			{
				e = err;
			}

			m.quit();
		});

		m.run();

		if (e != null)
		{
			throw e;
		}

		return status;
	}

	public async int run(Ggit.Repository repository) throws SpawnError
	{
		SourceFunc callback = run.callback;

		d_output = new string[256];
		d_output.length = 0;

		File wd;

		if (working_directory == null)
		{
			wd = working_directory;
		}
		else
		{
			wd = repository.get_workdir();
		}

		var script = hook_file(repository);
		var args = new string[d_arguments.length + 1];

		args.length = 0;

		args += script.get_path();

		foreach (var a in d_arguments)
		{
			args += a;
		}

		var env = flat_environment();

		Pid pid;

		int pstdout;
		int pstderr;

		Process.spawn_async_with_pipes(wd.get_path(),
		                               args,
		                               env,
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
