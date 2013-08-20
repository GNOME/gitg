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

namespace Gitg
{
	public class DiffViewRequest
	{
		protected DiffView? d_view;
		protected Soup.URI d_uri;
		protected string? d_mimetype;
		protected int64 d_size;
		protected WebKit.URISchemeRequest d_request;
		private HashTable<string, string>? d_form;
		protected bool d_hasView;

		public DiffViewRequest(DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
		{
			d_view = view;
			d_request = request;
			d_uri = uri;
			d_size = -1;
			d_mimetype = null;
			d_form = null;
			d_hasView = view != null;
		}

		public Soup.URI uri
		{
			get { return d_uri; }
		}

		public bool has_view
		{
			get { return d_hasView; }
		}

		public void finish_empty()
		{
			d_request.finish(new MemoryInputStream(),
			                 get_content_length(),
			                 get_content_type());
		}

		public string? parameter(string v)
		{
			if (d_form == null)
			{
				var q = d_uri.get_query();

				if (q != null)
				{
					d_form = Soup.Form.decode(q);
				}
				else
				{
					d_form = new HashTable<string, string>(str_hash, str_equal);
				}
			}

			return d_form.lookup(v);
		}

		public DiffView? view
		{
			get { return d_view; }
		}

		protected virtual InputStream? run_async(Cancellable? cancellable) throws GLib.Error
		{
			return null;
		}

		protected virtual void run_after_async()
		{}

		private async InputStream? run_impl(Cancellable? cancellable) throws GLib.Error
		{
			SourceFunc callback = run_impl.callback;
			InputStream? ret = null;

			new Thread<void*>("gitg-gtk-diff-view", () => {
				// Actually do it
				try
				{
					ret = run_async(cancellable);
				}
				catch {}

				// Schedule the callback in idle
				Idle.add((owned)callback);
				return null;
			});

			run_after_async();

			// Wait for it to finish, yield to caller
			yield;

			// Return the input stream
			return ret;
		}

		public void run(Cancellable? cancellable)
		{
			run_impl.begin(cancellable, (obj, res) => {
				InputStream? stream = null;

				try
				{
					stream = run_impl.end(res);
				}
				catch {}

				if (stream == null)
				{
					stream = new MemoryInputStream();
				}

				d_request.finish(stream,
				                 get_content_length(),
				                 get_content_type());
			});
		}

		public virtual int64 get_content_length()
		{
			return d_size;
		}

		public virtual string get_content_type()
		{
			if (d_mimetype != null)
			{
				return d_mimetype;
			}
			else
			{
				return "application/octet-stream";
			}
		}
	}
}

// ex:ts=4 noet
