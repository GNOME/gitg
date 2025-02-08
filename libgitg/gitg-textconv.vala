/*
 *
 * Copyright (C) 2021 - Alberto Fanjul
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

using Ggit;

namespace Gitg
{

public class TextConv
{
	public static bool has_textconv_command(Repository repository, DiffFile file)
	{
		return get_textconv_command(repository, file) != null;
	}

	private static string? get_textconv_command(Repository repository, DiffFile file)
	{
		string? command = null;
		var path = file.get_path();
		string? diffattr = null;
		try
		{
			diffattr = repository.get_attribute(path, "diff", Ggit.AttributeCheckFlags.FILE_THEN_INDEX);
		} catch {}
		if (diffattr != null)
		{
			var textconv_key = "diff.%s.textconv".printf(diffattr);
			try
			{
				var config = repository.get_config().snapshot();
				command = config.get_string(textconv_key);
			}
			catch (GLib.Error e)
			{
				warning("error getting textconv command: %s\n", e.message);
			}
		}
		return command;
	}

	public static uint8[] get_textconv_content(Repository repository, DiffFile file)
	{
		uint8[] content = "".data;
		if (file != null)
		{
			var oid = file.get_oid();
			if (!oid.is_zero()) {
				try
				{
					var blob = repository.lookup<Ggit.Blob>(oid);
					uint8[]? raw_content = blob.get_raw_content();
					content = get_textconv_content_from_raw(repository, file, raw_content);
				} catch {}
			}
		}
		return content;
	}

	public static uint8[] get_textconv_content_from_raw(Repository repository, DiffFile file, uint8[]? raw_content)
	{
		uint8[] content = "".data;
		if (raw_content != null)
		{
			var command = get_textconv_command(repository, file);
			if (command != null)
			{
				content = textconv(command, raw_content);
			}
		}
		return content;
	}

	private static uint8[] textconv(string command, uint8[]? data)
	{
		string lines = "";
		try
		{
			string[] command_array = command.split(" ");
			for (int i = 0; i < command_array.length; i++) {
				command_array[i] = command_array[i].replace("\"", "");
			}
			command_array += "/dev/stdin";

			var subproc = new Subprocess.newv(command_array, STDIN_PIPE | STDOUT_PIPE | STDERR_PIPE);

			var input = new MemoryInputStream.from_data(data, GLib.free);
			subproc.get_stdin_pipe ().splice (input, CLOSE_TARGET);

			var end_pipe = subproc.get_stdout_pipe ();
			var output = new DataInputStream (end_pipe);
			string? line = null;
			do {
				line = output.read_line();
				if (line != null) {
					lines += line+"\n";
				}
			} while (line != null);

			var err_pipe = subproc.get_stderr_pipe ();
			var err = new DataInputStream (err_pipe);
			string? lineerr = null;
			do {
				lineerr = err.read_line();
				if (lineerr != null) {
					stderr.printf(": %s\n", lineerr);
				}
			} while (lineerr != null);
		} catch (GLib.Error e) {
			stderr.printf("Failed to apply texconv: %s\n", e.message);
		}
		return lines.data;
	}
}

}

// ex:ts=4 noet
