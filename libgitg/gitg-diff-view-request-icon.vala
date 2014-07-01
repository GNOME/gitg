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
		private File? d_icon;
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

		private File ensure_icon() throws DiffViewRequestIconError
		{
			if (d_icon != null)
			{
				return d_icon;
			}

			var name = Soup.URI.decode(d_uri.get_path());
			name = name[1:name.length];

			var sizes = parameter("size");

			int size = 60;

			if (sizes != null)
			{
				size = int.parse(sizes);
			}

			var info = d_theme.lookup_icon(name, size, 0);

			if (info == null)
			{
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			var path = info.get_filename();

			if (path != null)
			{
				d_icon = File.new_for_path(path);
			}
			else
			{
				throw new DiffViewRequestIconError.ICON_NOT_FOUND("icon not found");
			}

			return d_icon;
		}

		public override InputStream? run_async(Cancellable? cancellable) throws GLib.Error
		{
			var f = ensure_icon();

			var stream = f.read(cancellable);

			try
			{
				var info = f.query_info(FileAttribute.STANDARD_CONTENT_TYPE +
				                        "," +
				                        FileAttribute.STANDARD_SIZE,
				                        0,
				                        cancellable);

				d_size = info.get_size();

				var ctype = info.get_content_type();

				if (ctype != null)
				{
					d_mimetype = ContentType.get_mime_type(ctype);
				}
			} catch {}

			return stream;
		}
	}
}

// ex:ts=4 noet
