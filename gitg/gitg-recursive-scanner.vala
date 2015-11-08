/*
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

namespace Gitg
{

interface RecursiveScanner : Object
{
	protected async virtual void scan_visit_file(File file, Cancellable? cancellable)
	{
	}

	protected bool scan_visit_directory_default(File file)
	{
		return !file.get_basename().has_prefix(".");
	}

	protected async virtual bool scan_visit_directory(File file, Cancellable? cancellable)
	{
		return scan_visit_directory_default(file);
	}

	public async void scan(File location, Cancellable? cancellable = null)
	{
		yield scan_real(location, cancellable, new Gee.HashSet<File>((file) => { return file.hash(); }, (file, other) => { return file.equal(other); }));
	}

	private async void scan_real(File location, Cancellable? cancellable, Gee.HashSet<File> seen)
	{
		if (cancellable != null && cancellable.is_cancelled())
		{
			return;
		}

		FileEnumerator? e;

		try
		{
			e = yield location.enumerate_children_async(FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE,
		                                                FileQueryInfoFlags.NONE,
		                                                Priority.DEFAULT,
		                                                cancellable);
		} catch { return; }

		while (cancellable == null || !cancellable.is_cancelled())
		{
			List<FileInfo>? files = null;

			try
			{
				files = yield e.next_files_async(10, Priority.DEFAULT);
			} catch {}

			if (files == null) {
				break;
			}

			foreach (var f in files)
			{
				var file = location.get_child(f.get_name());

				if (seen.contains(file))
				{
					continue;
				}

				seen.add(file);

				yield scan_visit_file(file, cancellable);

				if (f.get_file_type() == FileType.DIRECTORY)
				{
					if (!(yield scan_visit_directory(file, cancellable)))
					{
						continue;
					}

					yield scan_real(file, cancellable, seen);
				}
			}
		}

		try {
			yield e.close_async(Priority.DEFAULT, cancellable);
		} catch {}
	}
}

}

// ex:ts=4 noet
