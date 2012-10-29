/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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
namespace GitgGtk
{
	class DiffViewRequestResource : DiffViewRequest
	{
		private File? d_resource;

		public DiffViewRequestResource(DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
		{
			base(view, request, uri);
		}

		private File ensure_resource()
		{
			if (d_resource != null)
			{
				return d_resource;
			}

			var path = Soup.URI.decode(d_uri.get_path());

			d_resource = File.new_for_uri("resource://" + path);

			// For debugging
			if (Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") == "local")
			{
				var pre = "/org/gnome/gitg/gtk/diff-view";

				if (path.has_prefix(pre))
				{
					path = path.substring(pre.length);
				}

				d_resource = File.new_for_path("resources" + path);
			}

			return d_resource;
		}

		public override InputStream? run_async(Cancellable? cancellable) throws GLib.Error
		{
			var f = ensure_resource();

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

// vi:ts=4
