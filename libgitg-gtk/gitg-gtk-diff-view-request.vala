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
	class DiffViewRequestHandler
	{
		protected DiffView? d_view;
		protected Soup.URI d_uri;
		protected string? d_mimetype;
		protected int64 d_size;

		public DiffViewRequestHandler(DiffView? view, Soup.URI uri)
		{
			d_view = view;
			d_uri = uri;
		}

		public virtual InputStream? send(Cancellable? cancellable) throws GLib.Error
		{
			return null;
		}

		public virtual InputStream? send_async(Cancellable? cancellable) throws GLib.Error
		{
			return send(cancellable);
		}

		public virtual int64 get_content_length()
		{
			return d_size;
		}

		public virtual string get_content_type()
		{
			return d_mimetype;
		}
	}

	class DiffViewRequest : Soup.Request
	{
		private DiffViewRequestHandler? d_handler;
		private string? d_contenttype;

		static construct
		{
			schemes = new string[] {"gitg-internal"};
		}

		public override InputStream? send(Cancellable? cancellable) throws GLib.Error
		{
			return d_handler.send(cancellable);
		}

		private class SendResult : Object, AsyncResult
		{
			public InputStream? stream;
			public Object source;

			public SendResult(Object source, InputStream? stream)
			{
				this.source = source;
				this.stream = stream;
			}

			public Object get_source_object()
			{
				return source;
			}

			public void *get_user_data()
			{
				return (void *)stream;
			}

			public bool is_tagged(void *source_tag)
			{
				// FIXME: is this right?
				return false;
			}
		}

		public override InputStream? send_finish(AsyncResult result) throws GLib.Error
		{
			var res = result as SendResult;

			return res.stream;
		}

		private async InputStream? run_async(Cancellable? cancellable)
		{
			SourceFunc callback = run_async.callback;
			InputStream? ret = null;

			new Thread<void*>("gitg-gtk-diff-view", () => {
				// Actually do it
				try
				{
					ret = d_handler.send_async(cancellable);
				}
				catch {}

				// Schedule the callback in idle
				Idle.add((owned)callback);

				return null;
			});

			// Wait for it to finish, yield to caller
			yield;

			// Return the input stream
			return ret;
		}

		public override void send_async(Cancellable? cancellable,
		                                AsyncReadyCallback callback) throws GLib.Error
		{
			// run the diff in a thread
			run_async.begin(cancellable, (obj, res) => {
				var r = new SendResult(obj, run_async.end(res));

				callback(this, r);
			});
		}

		private Gee.HashMap<string, DiffView> diffmap
		{
			get
			{
				return session.get_data<Gee.HashMap<string, DiffView>>("GitgGtkDiffViewMap");
			}
		}

		public override bool check_uri(Soup.URI uri)
		{
			var path = uri.get_path();
			var parts = path.split("/", 3);

			if (parts.length != 3)
			{
				return false;
			}

			uri.set_scheme(parts[1]);
			uri.set_path("/" + parts[2]);
			d_handler = null;

			DiffView? view = null;

			var q = uri.get_query();

			if (q != null)
			{
				var f = Soup.Form.decode(q);
				var vid = f.lookup("viewid");

				if (vid != null && diffmap.has_key(vid))
				{
					view = diffmap[vid];
				}
			}

			switch (parts[1])
			{
				case "resource":
					d_handler = new DiffViewRequestResource(view, uri);
				break;
				case "diff":
					d_handler = new DiffViewRequestDiff(view, uri);
				break;
			}

			return d_handler != null;
		}

		public override int64 get_content_length()
		{
			if (d_handler != null)
			{
				return d_handler.get_content_length();
			}

			return 0;
		}

		public override unowned string? get_content_type()
		{
			if (d_handler != null)
			{
				d_contenttype = d_handler.get_content_type();
			}

			if (d_contenttype == null)
			{
				d_contenttype = "application/octet-stream";
			}

			return d_contenttype;
		}
	}
}

// vi:ts=4
