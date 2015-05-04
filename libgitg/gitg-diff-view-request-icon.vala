/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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
	public errordomain DiffViewRequestIconError
	{
		ICON_NOT_FOUND
	}

	class DiffViewRequestIcon : DiffViewRequest
	{
		private Gtk.IconTheme d_theme;

		public DiffViewRequestIcon(DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
		{
			base(view, request, uri);

			if (view == null)
			{
				d_theme = Gtk.IconTheme.get_default();
			}
			else
			{
				d_theme = Gtk.IconTheme.get_for_screen(view.get_screen());
			}

			d_view = null;
			d_hasView = false;
		}

		private InputStream ensure_icon(Cancellable? cancellable, out ulong size) throws DiffViewRequestIconError
		{
			var name = Soup.URI.decode(d_uri.get_path());
			name = name[1:name.length];

			var sizes = parameter("size");

			int s = 60;

			if (sizes != null)
			{
				s = int.parse(sizes);
			}

			Gdk.Pixbuf? icon = null;

			try
			{
				icon = d_theme.load_icon(name, s, 0);
			}
			catch (Error e) {
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			if (icon == null)
			{
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			var stream = new MemoryOutputStream.resizable();

			try
			{
				icon.save_to_stream(stream, "png", cancellable);
			}
			catch (Error e)
			{
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			try
			{
				stream.close();
			}
			catch (Error e)
			{
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			var b = stream.steal_as_bytes();

			size = b.length;

			var istream = new MemoryInputStream.from_bytes(b);
			return istream;
		}

		public override InputStream? run_async(Cancellable? cancellable) throws GLib.Error
		{
			ulong size;
			var stream = ensure_icon(cancellable, out size);

			d_size = size;
			d_mimetype = "image/png";

			return stream;
		}
	}
}

// ex:ts=4 noet
