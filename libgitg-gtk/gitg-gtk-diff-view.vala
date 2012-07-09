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
	class ResourceRequest : Soup.Request
	{
		private File? d_resource;
		private string? d_mimetype;
		private int64 d_size;

		static construct
		{
			schemes = new string[] {"resource"};
		}

		private File ensure_resource()
		{
			if (d_resource != null)
			{
				return d_resource;
			}

			var path = Soup.URI.decode(uri.get_path());

			d_resource = File.new_for_uri("resource://" + path);
			return d_resource;
		}

		public override InputStream? send(Cancellable? cancellable) throws GLib.Error
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

		public override bool check_uri(Soup.URI uri)
		{
			return true;
		}

		public override int64 get_content_length()
		{
			return d_size;
		}

		public override unowned string? get_content_type()
		{
			if (d_mimetype == null)
			{
				return "application/octet-stream";
			}
			else
			{
				return d_mimetype;
			}
		}
	}

	class DiffRequest : Soup.Request
	{
		static construct
		{
			schemes = new string[] {"diff"};
		}

		private string parse_id()
		{
			var path = uri.get_path();
			return path[1:path.length];
		}

		private void file_to_json(Json.Builder builder, Ggit.DiffFile file)
		{
			builder.begin_object();
			{
				builder.set_member_name("path").add_string_value(file.get_path());
				builder.set_member_name("mode").add_int_value(file.get_mode());
				builder.set_member_name("size").add_int_value(file.get_size());
				builder.set_member_name("flags").add_int_value(file.get_flags());
			}
			builder.end_object();
		}

		private void range_to_json(Json.Builder builder, int start, int lines)
		{
			builder.begin_object();
			{
				builder.set_member_name("start").add_int_value(start);
				builder.set_member_name("lines").add_int_value(lines);
			}
			builder.end_object();
		}

		private class DiffState
		{
			public bool in_file;
			public bool in_hunk;
		}

		private void file_cb(Json.Builder   builder,
		                     DiffState      state,
		                     Ggit.DiffDelta delta,
		                     float          progress)
		{
			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();

				state.in_hunk = false;
			}

			if (state.in_file)
			{
				builder.end_array();
				builder.end_object();

				state.in_file = false;
			}

			builder.begin_object();

			builder.set_member_name("file");

			builder.begin_object();
			{
				file_to_json(builder.set_member_name("old"), delta.get_old_file());
				file_to_json(builder.set_member_name("new"), delta.get_new_file());
			}
			builder.end_object();

			builder.set_member_name("status").add_int_value(delta.get_status());
			builder.set_member_name("similarity").add_int_value(delta.get_similarity());
			builder.set_member_name("binary").add_int_value(delta.get_binary());

			builder.set_member_name("hunks").begin_array();

			state.in_file = true;
		}

		private void hunk_cb(Json.Builder builder,
		                     DiffState    state,
		                     Ggit.DiffDelta delta,
		                     Ggit.DiffRange range,
		                     string header)
		{
			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();

				state.in_hunk = false;
			}

			builder.begin_object();

			builder.set_member_name("range");

			builder.begin_object();
			{
				range_to_json(builder.set_member_name("old"),
				              range.get_old_start(),
				              range.get_old_lines());

				range_to_json(builder.set_member_name("new"),
				              range.get_new_start(),
				              range.get_new_lines());
			}
			builder.end_object();

			builder.set_member_name("header").add_string_value(header);
			builder.set_member_name("lines");

			builder.begin_array();

			state.in_hunk = true;
		}

		private void line_cb(Json.Builder builder,
		                     Ggit.DiffDelta delta,
		                     Ggit.DiffRange range,
		                     Ggit.DiffLineType line_type,
		                     string content)
		{
			builder.begin_object();
			{
				builder.set_member_name("type").add_int_value(line_type);
				builder.set_member_name("content").add_string_value(content);
			}
			builder.end_object();
		}

		private InputStream? run_diff(Ggit.Diff? diff, Cancellable? cancellable) throws GLib.Error
		{
			if (diff == null)
			{
				return null;
			}

			// create memory output stream
			var builder = new Json.Builder();
			DiffState state = new DiffState();

			builder.begin_array();

			diff.foreach(
				(delta, progress) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					file_cb(builder, state, delta, progress);
					return 0;
				},

				(delta, range, header) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					hunk_cb(builder, state, delta, range, ((string)header).substring(0, header.length));
					return 0;
				},

				(delta, range, line_type, content) => {
					if (cancellable != null && cancellable.is_cancelled())
					{
						return 1;
					}

					line_cb(builder, delta, range, line_type, ((string)content).substring(0, content.length));
					return 0;
				}
			);

			if (cancellable != null && cancellable.is_cancelled())
			{
				throw new IOError.CANCELLED("Cancelled");
			}

			if (state.in_hunk)
			{
				builder.end_array();
				builder.end_object();
			}

			if (state.in_file)
			{
				builder.end_array();
				builder.end_object();
			}

			builder.end_array();

			var gen = new Json.Generator();
			gen.set_root(builder.get_root());

			var stream = new MemoryOutputStream(null, realloc, free);
			gen.to_stream(stream, cancellable);

			if (cancellable != null && cancellable.is_cancelled())
			{
				throw new IOError.CANCELLED("Cancelled");
			}

			stream.close();

			uint8[] data = stream.steal_data();
			data = data[0:stream.get_data_size()];

			return new MemoryInputStream.from_data(data, stream.destroy_function);
		}

		public override InputStream? send(Cancellable? cancellable) throws GLib.Error
		{
			var map = diffmap;
			var id = parse_id();

			if (!map.has_key(id))
			{
				throw new IOError.NOT_FOUND("Diff identifier does not exist");
			}

			var view = map[id];
			return run_diff(view.diff, cancellable);
		}

		private async InputStream? run_diff_async(Ggit.Diff?   diff,
		                                          Cancellable? cancellable)
		{
			SourceFunc callback = run_diff_async.callback;
			InputStream? ret = null;

			new Thread<void*>("gitg-gtk-diff-view-diff", () => {
				// Actually do it
				try
				{
					ret = run_diff(diff, cancellable);
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
		}

		public override InputStream? send_finish(AsyncResult result) throws GLib.Error
		{
			var res = result as SendResult;

			return res.stream;
		}

		public override void send_async(Cancellable? cancellable,
		                                AsyncReadyCallback callback) throws GLib.Error
		{
			var map = diffmap;
			var id = parse_id();

			if (!map.has_key(id))
			{
				throw new IOError.NOT_FOUND("Diff identifier does not exist");
			}

			var view = map[id];

			// run the diff in a thread
			run_diff_async.begin(view.diff, cancellable, (obj, res) => {
				var r = new SendResult(obj, run_diff_async.end(res));

				callback(this, r);
			});
		}

		private Gee.HashMap<string, GitgGtk.DiffView> diffmap
		{
			get
			{
				return session.get_data<Gee.HashMap<string, GitgGtk.DiffView>>("GitgGtkDiffViewMap");
			}
		}

		public override bool check_uri(Soup.URI uri)
		{
			return diffmap.has_key(parse_id());
		}

		public override unowned string? get_content_type()
		{
			return "application/json";
		}

		public override int64 get_content_length()
		{
			return 0;
		}
	}

	public class DiffView : WebKit.WebView
	{
		private Ggit.Diff? d_diff;

		private static Gee.HashMap<string, GitgGtk.DiffView> s_diffmap;
		private static uint64 s_diff_id;

		public File? custom_css { get; construct; }
		public File? custom_js { get; construct; }

		private bool d_loaded;

		public Ggit.Diff? diff
		{
			get { return d_diff; }
			set
			{
				d_diff = value;
				update();
			}
		}

		static construct
		{
			var r = new Soup.Requester();

			r.add_feature(typeof(ResourceRequest));
			r.add_feature(typeof(DiffRequest));

			var session = WebKit.get_default_session();

			session.add_feature(r);

			s_diffmap = new Gee.HashMap<string, GitgGtk.DiffView>();
			session.set_data("GitgGtkDiffViewMap", s_diffmap);
		}

		construct
		{
			var settings = new WebKit.WebSettings();

			if (custom_css != null)
			{
				settings.user_stylesheet_uri = custom_css.get_uri();
			}

			settings.javascript_can_access_clipboard = true;
			set_settings(settings);

			++s_diff_id;
			s_diffmap[s_diff_id.to_string()] = this;

			// Load the diff base html
			var uri = "resource:///org/gnome/gitg/gtk/diff-view/base.html?id=" + s_diff_id.to_string();

			// Add custom js as a query parameter
			if (custom_js != null)
			{
				uri += "&js=" + Soup.URI.encode(custom_js.get_uri(), null);
			}

			document_load_finished.connect((v, fr) => {
				d_loaded = true;
				update();
			});

			load_uri(uri);
		}

		public DiffView(File? custom_js)
		{
			Object(custom_js: custom_js);
		}

		private void update()
		{
			if (!d_loaded || d_diff == null)
			{
				return;
			}

			execute_script("update_diff();");
		}
	}
}

// vi:ts=4
