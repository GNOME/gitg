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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file-renderer-image.ui")]
class Gitg.DiffViewFileRendererImage : Gtk.Grid, DiffViewFileRenderer
{
	public Ggit.DiffDelta? delta { get; construct set; }
	public Repository repository { get; construct set; }

	[GtkChild( name = "diff_image_side_by_side" )]
	private Gitg.DiffImageSideBySide d_diff_image_side_by_side;

	[GtkChild( name = "diff_image_slider" )]
	private Gitg.DiffImageSlider d_diff_image_slider;

	[GtkChild( name = "scale_slider_adjustment" )]
	private Gtk.Adjustment d_scale_slider_adjustment;

	[GtkChild( name = "diff_image_overlay" )]
	private Gitg.DiffImageOverlay d_diff_image_overlay;

	[GtkChild( name = "scale_overlay_adjustment" )]
	private Gtk.Adjustment d_scale_overlay_adjustment;

	[GtkChild( name = "diff_image_difference" )]
	private Gitg.DiffImageDifference d_diff_image_difference;

	[GtkChild( name = "stack_switcher" )]
	private Gtk.StackSwitcher d_stack_switcher;

	private SurfaceCache d_cache;

	public DiffViewFileRendererImage(Repository repository, Ggit.DiffDelta delta)
	{
		Object(repository: repository, delta: delta);
	}

	construct
	{
		d_cache = new SurfaceCache(pixbuf_for_file(delta.get_old_file()),
		                           pixbuf_for_file(delta.get_new_file()));

		d_diff_image_side_by_side.cache = d_cache;
		d_diff_image_slider.cache = d_cache;
		d_diff_image_overlay.cache = d_cache;
		d_diff_image_difference.cache = d_cache;

		if (d_cache.old_pixbuf == null || d_cache.new_pixbuf == null ||
		    d_cache.old_pixbuf.get_width() != d_cache.new_pixbuf.get_width() ||
		    d_cache.old_pixbuf.get_height() != d_cache.new_pixbuf.get_height())
		{
			d_stack_switcher.sensitive = false;
		}

		d_scale_slider_adjustment.bind_property("value", d_diff_image_slider, "position", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
		d_scale_overlay_adjustment.bind_property("value", d_diff_image_overlay, "alpha", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE);
	}

	private Gdk.Pixbuf? pixbuf_for_file(Ggit.DiffFile file)
	{
		if ((file.get_flags() & Ggit.DiffFlag.VALID_ID) == 0 || file.get_oid().is_zero())
		{
			return null;
		}

		Ggit.Blob blob;

		try
		{
			blob = repository.lookup<Ggit.Blob>(file.get_oid());
		}
		catch (Error e)
		{
			stderr.printf(@"ERROR: failed to load image blob: $(e.message)\n");
			return null;
		}

		var stream = new MemoryInputStream.from_data(blob.get_raw_content(), null);

		try
		{
			return new Gdk.Pixbuf.from_stream(stream);
		}
		catch (Error e)
		{
			stderr.printf(@"ERROR: failed to create pixbuf: $(e.message)\n");
			return null;
		}
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
	}

	private class SurfaceCache : Object, Gitg.DiffImageSurfaceCache {
		private Cairo.Surface? d_old_surface;
		private Cairo.Surface? d_new_surface;

		public Gdk.Pixbuf? old_pixbuf { get; construct set; }
		public Gdk.Pixbuf? new_pixbuf { get; construct set; }

		public Gdk.Window window { get; construct set; }

		public SurfaceCache(Gdk.Pixbuf? old_pixbuf, Gdk.Pixbuf? new_pixbuf)
		{
			Object(old_pixbuf: old_pixbuf, new_pixbuf: new_pixbuf);
		}

		public Cairo.Surface? get_old_surface(Gdk.Window window)
		{
			return get_cached_surface(window, old_pixbuf, ref d_old_surface);
		}

		public Cairo.Surface? get_new_surface(Gdk.Window window)
		{
			return get_cached_surface(window, new_pixbuf, ref d_new_surface);
		}

		private Cairo.Surface? get_cached_surface(Gdk.Window window, Gdk.Pixbuf? pixbuf, ref Cairo.Surface? cached)
		{
			if (pixbuf == null)
			{
				return null;
			}

			if (cached == null)
			{
				cached = Gdk.cairo_surface_create_from_pixbuf(pixbuf, 0, window);
			}

			return cached;
		}
	}
}

// ex:ts=4 noet
