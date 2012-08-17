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
	public class DiffView : WebKit.WebView
	{
		private Ggit.Diff? d_diff;
		private Ggit.Commit? d_commit;
		private Settings d_fontsettings;

		private static Gee.HashMap<string, GitgGtk.DiffView> s_diffmap;
		private static uint64 s_diff_id;

		public File? custom_css { get; construct; }
		public File? custom_js { get; construct; }
		public Ggit.DiffOptions? options { get; construct set; }

		private Cancellable d_cancellable;
		private bool d_loaded;

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

		public Ggit.Commit? commit
		{
			get { return d_commit; }
			set
			{
				d_commit = value;
				d_diff = null;

				update();
			}
		}

		static construct
		{
			s_diffmap = new Gee.HashMap<string, GitgGtk.DiffView>();

			var context = WebKit.WebContext.get_default();
			context.register_uri_scheme("gitg-diff", gitg_diff_request);
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
			}
		}

		public void request(DiffViewRequest request)
		{
			request.run(d_cancellable);
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

			var dbg = Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != "";

			if (dbg)
			{
				settings.enable_developer_extras = true;
			}

			settings.javascript_can_access_clipboard = true;

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
			var uri = "gitg-diff:///resource/org/gnome/gitg/gtk/diff-view/base.html?viewid=" + s_diff_id.to_string();

			// Add custom js as a query parameter
			if (custom_js != null)
			{
				uri += "&js=" + Soup.URI.encode(custom_js.get_uri(), null);
			}

			// Add custom css as a query parameter
			if (custom_css != null)
			{
				uri += "&css=" + Soup.URI.encode(custom_css.get_uri(), null);
			}

			d_loaded = false;

			load_uri(uri);
		}

		public DiffView(File? custom_js)
		{
			Object(custom_js: custom_js);
		}

		private void update()
		{
			if (!d_loaded || (d_diff == null && d_commit == null))
			{
				return;
			}

			// Cancel running operations
			d_cancellable.cancel();
			d_cancellable = new Cancellable();

			if (d_commit != null)
			{
				d_diff = null;

				var repo = d_commit.get_owner();

				try
				{
					var parents = d_commit.get_parents();

					// Create a new diff from the parents to the commit tree
					for (var i = 0; i < parents.size(); ++i)
					{
						var parent = parents.get(0);

						if (i == 0)
						{
							d_diff = new Ggit.Diff.tree_to_tree(repo,
							                                    options,
							                                    parent.get_tree(),
							                                    d_commit.get_tree());
						}
						else
						{
							var d = new Ggit.Diff.tree_to_tree(repo,
							                                   options,
							                                   parent.get_tree(),
							                                   d_commit.get_tree());

							d_diff.merge(d);
						}
					}
				}
				catch {}
			}

			if (d_diff != null)
			{
				run_javascript.begin("update_diff();", d_cancellable, (obj, res) => {
					try
					{
						run_javascript.end(res);
					} catch {}
				});
			}
		}
	}
}

// vi:ts=4
