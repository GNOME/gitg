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

class RecursiveMonitor : Object
{
	class Monitor : Object
	{
		public File location;
		public RecursiveMonitor monitor;

		public Monitor(File location, RecursiveMonitor monitor)
		{
			this.location = location;
			this.monitor = monitor;
		}
	}

	public delegate bool FilterFunc(File file);

	private FileMonitor? d_monitor;
	private Gee.List<Monitor> d_sub_monitors;
	private uint d_monitor_changed_timeout_id;
	private FilterFunc? d_filter_func;
	private Cancellable d_cancellable;
	private File[] d_changed_files;

	public signal void changed(File[] files);

	public RecursiveMonitor(File location, owned FilterFunc? filter_func = null)
	{
		d_filter_func = (owned)filter_func;
		d_sub_monitors = new Gee.LinkedList<Monitor>();

		try
		{
			d_monitor = location.monitor_directory(FileMonitorFlags.NONE);
		}
		catch {}

		if (d_monitor != null)
		{
			d_monitor.changed.connect(monitor_changed_timeout);
		}

		d_cancellable = new Cancellable();

		enumerate.begin(location, (obj, res) => {
			try
			{
				enumerate.end(res);
			} catch {}
		});
	}

	private async void enumerate(File location) throws Error
	{
		var e = yield location.enumerate_children_async(FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, Priority.DEFAULT, d_cancellable);
		File[] allfiles = new File[0];

		while (true)
		{
			var files = yield e.next_files_async(10, Priority.DEFAULT);

			if (files == null)
			{
				break;
			}

			foreach (var f in files)
			{
				if (f.get_file_type() == FileType.DIRECTORY)
				{
					allfiles += location.get_child(f.get_name());
				}
			}
		}

		yield e.close_async(Priority.DEFAULT, d_cancellable);

		foreach (var f in allfiles)
		{
			add_submonitor(f);
		}
	}

	private void add_submonitor(File location)
	{
		if (d_filter_func != null && !d_filter_func(location))
		{
			return;
		}

		var mon = new RecursiveMonitor(location, (l) => {
			return d_filter_func(l);
		});

		d_sub_monitors.add(new Monitor(location, mon));
		mon.changed.connect((files) => { changed_timeout(files); });
	}

	private void add_submonitor_if_directory(File location)
	{
		try
		{
			var info = location.query_info(FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE);

			if (info.get_file_type() == FileType.DIRECTORY)
			{
				add_submonitor(location);
			}
		}
		catch {}
	}

	public override void dispose()
	{
		cancel();
		base.dispose();
	}

	private void remove_submonitor(File location)
	{
		foreach (var monitor in d_sub_monitors)
		{
			if (location.equal(monitor.location))
			{
				d_sub_monitors.remove(monitor);
				return;
			}
		}
	}

	private void monitor_changed_timeout(File file, File? other_file, FileMonitorEvent event)
	{
		if (event == FileMonitorEvent.CREATED)
		{
			add_submonitor_if_directory(file);
		}
		else if (event == FileMonitorEvent.DELETED)
		{
			remove_submonitor(file);
		}
		else if (event == FileMonitorEvent.MOVED)
		{
			remove_submonitor(file);

			if (other_file != null)
			{
				add_submonitor_if_directory(other_file);
			}
		}

		changed_timeout(new File[] { file, other_file });
	}

	private void changed_timeout(File?[] files)
	{
		foreach (var f in files)
		{
			if (f != null && (d_filter_func == null || d_filter_func(f)))
			{
				d_changed_files += f;
			}
		}

		if (d_monitor_changed_timeout_id != 0)
		{
			return;
		}

		if (d_changed_files.length > 0)
		{
			d_monitor_changed_timeout_id = Timeout.add_seconds(1, () => {
				d_monitor_changed_timeout_id = 0;

				changed(d_changed_files);
				d_changed_files = new File[0];

				return false;
			});
		}
	}

	public void cancel()
	{
		d_cancellable.cancel();

		if (d_monitor_changed_timeout_id != 0)
		{
			Source.remove(d_monitor_changed_timeout_id);
			d_monitor_changed_timeout_id = 0;
		}

		foreach (var monitor in d_sub_monitors)
		{
			monitor.monitor.cancel();
		}

		d_sub_monitors.clear();

		if (d_monitor != null)
		{
			d_monitor.cancel();
			d_monitor = null;
		}
	}
}

}

// ex:ts=4 noet
