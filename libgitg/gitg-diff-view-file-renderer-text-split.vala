/*
 * This file is part of gitg
 *
 * Copyright (C) 2016 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file-renderer-text-split.ui")]
class Gitg.DiffViewFileRendererTextSplit : Gtk.Box, DiffSelectable, DiffViewFileRenderer, DiffViewFileRendererTextable
{
	[GtkChild( name = "scroll_left" )]
	private unowned Gtk.ScrolledWindow d_scroll_left;
	[GtkChild( name = "scroll_right" )]
	private unowned Gtk.ScrolledWindow d_scroll_right;

	private Gitg.DiffViewFileRendererText d_renderer_left;
	private Gitg.DiffViewFileRendererText d_renderer_right;

	public DiffViewFileInfo info { get; construct set; }

	public Ggit.DiffDelta? delta
	{
		get { return info.delta; }
	}

	public Repository? repository
	{
		get { return info.repository; }
	}

	public bool wrap_lines
	{
		get { return d_renderer_left.wrap_mode != Gtk.WrapMode.NONE; }
		set
		{
			if (value)
			{
				d_renderer_left.wrap_mode = Gtk.WrapMode.WORD_CHAR;
				d_renderer_right.wrap_mode = Gtk.WrapMode.WORD_CHAR;
			}
			else
			{
				d_renderer_left.wrap_mode = Gtk.WrapMode.NONE;
				d_renderer_right.wrap_mode = Gtk.WrapMode.NONE;
			}
		}
	}

	public new int tab_width
	{
		get
		{
			return (int)d_renderer_left.get_tab_width();
		}
		set
		{
			d_renderer_left.set_tab_width((uint)value);
			d_renderer_right.set_tab_width((uint)value);
		}
	}

	public int maxlines
	{
		get
		{
			return (int)d_renderer_left.maxlines;
		}
		set
		{
			d_renderer_left.maxlines = value;
			d_renderer_right.maxlines = value;
		}
	}

	public bool highlight
	{
		get { return d_renderer_left != null && d_renderer_left.highlight; }

		construct set
		{
			if (highlight != value)
			{
				d_renderer_left.highlight = value;
				d_renderer_right.highlight = value;
			}
		}
	}

	public DiffViewFileRendererTextSplit(DiffViewFileInfo info, bool handle_selection)
	{
		Object(info: info);
		d_renderer_left = new Gitg.DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.OLD);
		d_renderer_right = new Gitg.DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.NEW);
		d_scroll_left.add(d_renderer_left);
		d_scroll_right.add(d_renderer_right);
	}

	construct
	{
		//can_select = d_renderer_left.can_select() || d_renderer_right.can_select();
		can_select = false;
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		d_renderer_left.add_hunk(hunk, lines);
		d_renderer_right.add_hunk(hunk, lines);
	}

	public bool has_selection
	{
		get
		{
			//return d_renderer_left.has_selection() || d_renderer_right.has_selection();
			return false;
		}
	}

	public void clear_selection()
	{
	}

	public bool can_select { get; construct set; }

	public PatchSet selection
	{
		owned get
		{
			/*if (d_renderer_left.has_selection())
				return d_renderer_left.get_selection();
			if (d_renderer_right.has_selection())
				return d_renderer_right.get_selection();
			*/
			return new PatchSet();
		}
	}
}
