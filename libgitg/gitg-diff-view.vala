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
	public class DiffView : WebKit.WebView
	{
		private Ggit.Diff? d_diff;
		private Commit? d_commit;
		private Settings d_fontsettings;

		private static Gee.HashMap<string, DiffView> s_diffmap;
		private static uint64 s_diff_id;

		public File? custom_css { get; construct; }
		public File? custom_js { get; construct; }
		public Ggit.DiffOptions? options { get; construct set; }

		private Cancellable d_cancellable;
		private bool d_loaded;
		private ulong d_diffid;

		public Ggit.Diff? diff
		{
			get { return d_diff; }
			set
			{
				d_diff = value;
				d_commit = null;

				update();
			}
		}

		public Commit? commit
		{
			get { return d_commit; }
			set
			{
				d_commit = value;
				d_diff = null;

				update();
			}
		}

		public bool wrap { get; set; default = true; }
		public bool staged { get; set; default = false; }
		public bool unstaged { get; set; default = false; }
		public int tab_width { get; set; default = 4; }

		static construct
		{
			s_diffmap = new Gee.HashMap<string, DiffView>();

			var context = WebKit.WebContext.get_default();
			context.register_uri_scheme("gitg-diff", gitg_diff_request);
			context.set_cache_model(WebKit.CacheModel.DOCUMENT_VIEWER);
		}

		private string json_settings()
		{
			var o = new Json.Object();

			o.set_boolean_member("wrap", wrap);
			o.set_int_member("tab_width", tab_width);
			o.set_boolean_member("staged", staged);
			o.set_boolean_member("unstaged", unstaged);
			o.set_boolean_member("debug", Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != null);

			var strings = new Json.Object();

			strings.set_string_member("stage", _("stage"));
			strings.set_string_member("unstage", _("unstage"));
			strings.set_string_member("loading_diff", _("Loading diff..."));

			o.set_object_member("strings", strings);

			var gen = new Json.Generator();

			var node = new Json.Node(Json.NodeType.OBJECT);
			node.set_object(o);

			gen.set_root(node);

			size_t l;
			var ret = gen.to_data(out l);
			return ret[0:(long)l];
		}

		private static DiffViewRequest? parse_request(WebKit.URISchemeRequest request)
		{
			var uri = new Soup.URI(request.get_uri());
			var path = uri.get_path();
			var parts = path.split("/", 3);

			if (parts.length != 3)
			{
				return null;
			}

			uri.set_scheme(parts[1]);
			uri.set_path("/" + parts[2]);

			DiffView? view = null;

			var q = uri.get_query();

			if (q != null)
			{
				var f = Soup.Form.decode(q);
				var vid = f.lookup("viewid");

				if (vid != null && s_diffmap.has_key(vid))
				{
					view = s_diffmap[vid];
				}
			}

			switch (parts[1])
			{
				case "resource":
					return new DiffViewRequestResource(view, request, uri);
				case "diff":
					return new DiffViewRequestDiff(view, request, uri);
				case "patch":
					return new DiffViewRequestPatch(view, request, uri);
			}

			return null;
		}

		private static void gitg_diff_request(WebKit.URISchemeRequest request)
		{
			var req = parse_request(request);

			if (req.view != null)
			{
				req.view.request(req);
			}
			else
			{
				req.run(null);
			}
		}

		private void parse_font(string val, ref string family, ref uint size)
		{
			var fdesc = Pango.FontDescription.from_string(val);

			var f = fdesc.get_family();
			var s = fdesc.get_size();

			if (f != null && f != "")
			{
				family = f;
			}

			if (s != 0)
			{
				if (fdesc.get_size_is_absolute())
				{
					size = s;
				}
				else
				{
					size = s / Pango.SCALE;
				}

				size = (uint)(size * get_screen().get_resolution() / 72.0);
			}
		}

		public void request(DiffViewRequest request)
		{
			var did = request.parameter("diffid");

			if (did != null)
			{
				uint64 i = uint64.parse(did);

				if (i == d_diffid)
				{
					request.run(d_cancellable);
					return;
				}
			}

			// Still finish request, but with something bogus
			request.finish_empty();
		}

		private void update_font_settings()
		{
			var settings = get_settings();

			var fname = settings.default_font_family;
			var fsize = settings.default_font_size;

			parse_font(d_fontsettings.get_string("font-name"), ref fname, ref fsize);

			settings.default_font_family = fname;
			settings.default_font_size = fsize;

			fname = settings.monospace_font_family;
			fsize = settings.default_monospace_font_size;

			parse_font(d_fontsettings.get_string("monospace-font-name"), ref fname, ref fsize);

			settings.monospace_font_family = fname;
			settings.default_monospace_font_size = fsize;
		}

		protected override void constructed()
		{
			base.constructed();

			var settings = new WebKit.Settings();

			var dbg = Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != null;

			if (dbg)
			{
				settings.enable_developer_extras = true;

				Timeout.add(500, () => {
					get_inspector().show();
					return false;
				});
			}

			settings.javascript_can_access_clipboard = true;
			settings.enable_page_cache = false;

			d_fontsettings = new Settings("org.gnome.desktop.interface");
			set_settings(settings);

			update_font_settings();

			d_fontsettings.changed["monospace-font-name"].connect((s, k) => {
				update_font_settings();
			});

			d_fontsettings.changed["font-name"].connect((s, k) => {
				update_font_settings();
			});

			++s_diff_id;
			s_diffmap[s_diff_id.to_string()] = this;

			d_cancellable = new Cancellable();

			load_changed.connect((v, ev) => {
				if (ev == WebKit.LoadEvent.FINISHED)
				{
					d_loaded = true;
					update();
				}
			});

			// Load the diff base html
			var uri = "gitg-diff:///resource/org/gnome/gitg/gtk/diff-view/diff-view.html?viewid=" + s_diff_id.to_string();

			uri += "&settings=" + Soup.URI.encode(json_settings(), null);

			d_loaded = false;

			load_uri(uri);
		}

		public DiffView()
		{
			Object();
		}

		private void update()
		{
			if (!d_loaded)
			{
				return;
			}

			if (d_diff == null && d_commit == null)
			{
				run_javascript.begin("update_diff();", d_cancellable, (obj, res) => {
					try
					{
						run_javascript.end(res);
					} catch {}
				});

				return;
			}

			// Cancel running operations
			d_cancellable.cancel();
			d_cancellable = new Cancellable();

			++d_diffid;

			if (d_commit != null)
			{
				d_diff = d_commit.get_diff(options);
			}

			if (d_diff != null)
			{
				run_javascript.begin("update_diff(%lu, %s);".printf(d_diffid, json_settings()), d_cancellable, (obj, res) => {
					try
					{
						run_javascript.end(res);
					} catch {}
				});
			}
		}
	}
}

// ex:ts=4 noet
