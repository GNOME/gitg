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

[GtkTemplate( ui = "/org/gnome/gitg/ui/gitg-diff-view.ui" )]
public class Gitg.DiffView : Gtk.Grid
{
	[GtkChild( name = "commit_details" )]
	private Gitg.DiffViewCommitDetails d_commit_details;

	[GtkChild( name = "grid_files" )]
	private Gtk.Grid d_grid_files;

	private Ggit.Diff? d_diff;
	private Commit? d_commit;

	private Ggit.DiffOptions? d_options;
	private Ggit.OId? d_parent;

	public Ggit.DiffOptions options
	{
		get
		{
			if (d_options == null)
			{
				d_options = new Ggit.DiffOptions();
			}

			return d_options;
		}
	}

	// TODO
	public bool has_selection
	{
		get { return false; }
	}

	private Cancellable d_cancellable;

	public Ggit.Diff? diff
	{
		get { return d_diff; }
		set
		{
			d_diff = value;

			d_commit = null;
			d_parent = null;

			update();
		}
	}

	public Commit? commit
	{
		get { return d_commit; }
		set
		{
			if (d_commit != value)
			{
				d_commit = value;
				d_diff = null;
				d_parent = null;
			}

			update();
		}
	}

	public virtual signal void options_changed()
	{
		if (d_commit != null)
		{
			update();
		}
	}

	private bool d_wrap;

	public bool wrap
	{
		get { return d_wrap; }
		construct set
		{
			if (d_wrap != value)
			{
				d_wrap = value;
				update_wrap();
			}
		}
		default = true;
	}

	public bool staged { get; set; default = false; }
	public bool unstaged { get; set; default = false; }
	public bool show_parents { get; set; default = false; }
	public bool default_collapse_all { get; set; default = true; }

	public bool use_gravatar
	{
		get;
		construct set;
		default = true;
	}

	int d_tab_width;

	public int tab_width
	{
		get { return d_tab_width; }
		construct set
		{
			if (d_tab_width != value)
			{
				d_tab_width = value;
				update_tab_width();
			}
		}
		default = 4;
	}

	private bool flag_get(Ggit.DiffOption f)
	{
		return (options.flags & f) != 0;
	}

	private void flag_set(Ggit.DiffOption f, bool val)
	{
		var flags = options.flags;

		if (val)
		{
			flags |= f;
		}
		else
		{
			flags &= ~f;
		}

		if (flags != options.flags)
		{
			options.flags = flags;
			options_changed();
		}
	}

	public bool ignore_whitespace
	{
		get { return flag_get(Ggit.DiffOption.IGNORE_WHITESPACE); }
		set { flag_set(Ggit.DiffOption.IGNORE_WHITESPACE, value); }
	}

	private bool d_changes_inline;

	public bool changes_inline
	{
		get { return d_changes_inline; }
		set
		{
			if (d_changes_inline != value)
			{
				d_changes_inline = value;

				// TODO
				//options_changed();
			}
		}
	}

	public int context_lines
	{
		get { return options.n_context_lines; }

		construct set
		{
			if (options.n_context_lines != value)
			{
				options.n_context_lines = value;
				options.n_interhunk_lines = value;

				options_changed();
			}
		}

		default = 3;
	}

	private ulong d_expanded_notify;

	protected override void constructed()
	{
		d_expanded_notify = d_commit_details.notify["expanded"].connect(update_expanded_files);
	}

	private void update_expanded_files()
	{
		var expanded = d_commit_details.expanded;

		foreach (var file in d_grid_files.get_children())
		{
			(file as Gitg.DiffViewFile).expanded = expanded;
		}
	}

	private void update_wrap()
	{
	}

	private void update_tab_width()
	{
	}

	private void update()
	{
		// If both `d_diff` and `d_commit` are null, clear
		// the diff content
		if (d_diff == null && d_commit == null)
		{
			hide();
			return;
		}

		show();

		// Cancel running operations
		d_cancellable.cancel();
		d_cancellable = new Cancellable();

		if (d_commit != null)
		{
			int parent = 0;
			var parents = d_commit.get_parents();

			if (d_parent != null)
			{
				for (var i = 0; i < parents.size; i++)
				{
					var id = parents.get_id(i);

					if (id.equal(d_parent))
					{
						parent = i;
						break;
					}
				}
			}

			d_diff = d_commit.get_diff(options, parent);
			d_commit_details.commit = d_commit;
			d_commit_details.show();
		}
		else
		{
			d_commit_details.commit = null;
			d_commit_details.hide();
		}

		if (d_diff != null)
		{
			update_diff(d_diff, d_cancellable);
		}
	}

	private delegate void Anon();

	private void auto_change_expanded(bool expanded)
	{
		SignalHandler.block(d_commit_details, d_expanded_notify);
		d_commit_details.expanded = expanded;
		SignalHandler.unblock(d_commit_details, d_expanded_notify);
	}

	private void update_diff(Ggit.Diff diff, Cancellable? cancellable)
	{
		var files = new Gee.ArrayList<Gitg.DiffViewFile>();
		Gitg.DiffViewFile? current_file = null;
		Ggit.DiffHunk? current_hunk = null;
		Gee.ArrayList<Ggit.DiffLine>? current_lines = null;

		var maxlines = 0;

		Anon add_hunk = () => {
			if (current_hunk != null)
			{
				current_file.add_hunk(current_hunk, current_lines);

				current_lines = null;
				current_hunk = null;
			}
		};

		Anon add_file = () => {
			add_hunk();

			if (current_file != null)
			{
				current_file.show();

				files.add(current_file);

				current_file = null;
			}
		};

		try
		{
			diff.foreach(
				(delta, progress) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					add_file();

					current_file = new Gitg.DiffViewFile(delta);
					return 0;
				},

				(delta, binary) => {
					// FIXME: do we want to handle binary data?
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					return 0;
				},

				(delta, hunk) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					maxlines = int.max(maxlines, hunk.get_old_start() + hunk.get_old_lines());
					maxlines = int.max(maxlines, hunk.get_new_start() + hunk.get_new_lines());

					add_hunk();

					current_hunk = hunk;
					current_lines = new Gee.ArrayList<Ggit.DiffLine>();

					return 0;
				},

				(delta, hunk, line) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					if ((delta.get_flags() & Ggit.DiffFlag.BINARY) == 0)
					{
						current_lines.add(line);
					}

					return 0;
				}
			);
		} catch {}

		add_hunk();
		add_file();

		d_commit_details.expanded = (files.size <= 1);

		foreach (var file in files)
		{
			file.expanded = d_commit_details.expanded;
			file.maxlines = maxlines;

			d_grid_files.add(file);

			file.notify["expanded"].connect(auto_update_expanded);
		}
	}

	private void auto_update_expanded()
	{
		foreach (var file in d_grid_files.get_children())
		{
			if (!(file as Gitg.DiffViewFile).expanded)
			{
				auto_change_expanded(false);
				return;
			}
		}

		auto_change_expanded(true);
	}

	public async PatchSet[] get_selection()
	{
		// TODO
		return new PatchSet[] {};
	}
}

// ex:ts=4 noet
