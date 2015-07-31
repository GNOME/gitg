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
		private class DiffViewRequestInternal : DiffViewRequest
		{
			public DiffViewRequestInternal(DiffView? view, WebKit.URISchemeRequest request, Soup.URI uri)
			{
				base(view, request, uri);
			}

			protected override InputStream? run_async(Cancellable? cancellable) throws Error
			{
				Idle.add(() => {
					switch (parameter("action"))
					{
						case "selection-changed":
							d_view.update_has_selection(parameter("value") == "yes");
							break;
						case "loaded":
							d_view.loaded();
							break;
						case "load-parent":
							d_view.load_parent(parameter("value"));
							break;
						case "select-parent":
							d_view.select_parent(parameter("value"));
							break;
						case "open-url":
							d_view.open_url(parameter("url"));
							break;
					}

					return false;
				});

				return null;
			}
		}

		public signal void request_select_commit(string id);

		private Ggit.Diff? d_diff;
		private Commit? d_commit;
		private Settings? d_fontsettings;
		private bool d_has_selection;
		private Ggit.DiffOptions? d_options;
		private string? d_parent;

		private static Gee.HashMap<string, DiffView> s_diff_map;
		private static uint64 s_diff_id;

		public File? custom_css { get; construct; }
		public File? custom_js { get; construct; }

		public virtual signal void options_changed()
		{
			if (d_commit != null)
			{
				update();
			}
		}

		public Ggit.DiffOptions options
		{
			get
			{
				if (d_options == null)
				{
					d_options = new Ggit.DiffOptions();
				}

				return d_options;
			}
		}

		public bool has_selection
		{
			get { return d_has_selection; }
		}

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
				d_parent = null;

				update();
			}
		}

		public Commit? commit
		{
			get { return d_commit; }
			set
			{
				if (d_commit != value)
				{
					d_commit = value;
					d_diff = null;
					d_parent = null;
				}

				update();
			}
		}

		public bool wrap { get; set; default = true; }
		public bool staged { get; set; default = false; }
		public bool unstaged { get; set; default = false; }
		public bool show_parents { get; set; default = false; }

		private bool d_use_gravatar;

		public bool use_gravatar
		{
			get { return d_use_gravatar; }
			construct set
			{
				if (d_use_gravatar != value)
				{
					d_use_gravatar = value;
					options_changed();
				}
			}
			default = true;
		}

		int d_tab_width;

		public int tab_width
		{
			get { return d_tab_width; }
			construct set
			{
				if (d_tab_width != value)
				{
					d_tab_width = value;
					update_tab_width();
				}
			}
			default = 4;
		}

		private bool flag_get(Ggit.DiffOption f)
		{
			return (options.flags & f) != 0;
		}

		private void flag_set(Ggit.DiffOption f, bool val)
		{
			var flags = options.flags;

			if (val)
			{
				flags |= f;
			}
			else
			{
				flags &= ~f;
			}

			if (flags != options.flags)
			{
				options.flags = flags;

				options_changed();
			}
		}

		public bool ignore_whitespace
		{
			get { return flag_get(Ggit.DiffOption.IGNORE_WHITESPACE); }
			set { flag_set(Ggit.DiffOption.IGNORE_WHITESPACE, value); }
		}

		private bool d_changes_inline;

		public bool changes_inline
		{
			get { return d_changes_inline; }
			set
			{
				if (d_changes_inline != value)
				{
					d_changes_inline = value;

					options_changed();
				}
			}
		}

		public int context_lines
		{
			get { return options.n_context_lines; }

			construct set
			{
				if (options.n_context_lines != value)
				{
					options.n_context_lines = value;
					options.n_interhunk_lines = value;

					options_changed();
				}
			}

			default = 3;
		}

		static construct
		{
			s_diff_map = new Gee.HashMap<string, DiffView>();

			var context = WebKit.WebContext.get_default();

			context.register_uri_scheme("gitg-diff", gitg_diff_request);
			context.register_uri_scheme("mailto", gitg_diff_mailto_request);

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
			o.set_boolean_member("changes_inline", changes_inline);
			o.set_boolean_member("show_parents", show_parents);
			o.set_string_member("parent", d_parent);
			o.set_boolean_member("use_gravatar", use_gravatar);

			var strings = new Json.Object();

			strings.set_string_member("stage", _("stage"));
			strings.set_string_member("unstage", _("unstage"));
			strings.set_string_member("loading_diff", _("Loading diff…"));
			strings.set_string_member("notes", _("Notes:"));
			strings.set_string_member("parents", _("Parents:"));
			strings.set_string_member("diff_against", _("Diff against:"));
			strings.set_string_member("committed_by", _("Committed by:"));

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

				if (vid != null && s_diff_map.has_key(vid))
				{
					view = s_diff_map[vid];
				}
			}

			switch (parts[1])
			{
				case "resource":
					return new DiffViewRequestResource(view, request, uri);
				case "icon":
					return new DiffViewRequestIcon(view, request, uri);
				case "diff":
					return new DiffViewRequestDiff(view, request, uri);
				case "internal":
					return new DiffViewRequestInternal(view, request, uri);
			}

			return null;
		}

		private static void gitg_diff_mailto_request(WebKit.URISchemeRequest request)
		{
			try
			{
				Gtk.show_uri(null, request.get_uri(), 0);
			} catch {}
		}

		private static void gitg_diff_request(WebKit.URISchemeRequest request)
		{
			var req = parse_request(request);

			if (req == null)
			{
				return;
			}

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

		private Settings? try_settings(string schema_id)
		{
			var source = SettingsSchemaSource.get_default();

			if (source == null)
			{
				return null;
			}

			if (source.lookup(schema_id, true) != null)
			{
				return new Settings(schema_id);
			}

			return null;
		}

		protected override void constructed()
		{
			base.constructed();

			var settings = new WebKit.Settings();

			var dbg = Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != null;

			if (dbg)
			{
				settings.enable_developer_extras = true;
				settings.enable_write_console_messages_to_stdout = true;
			}

			settings.javascript_can_access_clipboard = true;
			settings.enable_page_cache = false;

			set_settings(settings);

			d_fontsettings = try_settings("org.gnome.desktop.interface");

			if (d_fontsettings != null)
			{
				update_font_settings();

				d_fontsettings.changed["monospace-font-name"].connect((s, k) => {
					update_font_settings();
				});

				d_fontsettings.changed["font-name"].connect((s, k) => {
					update_font_settings();
				});
			}

			++s_diff_id;
			s_diff_map[s_diff_id.to_string()] = this;

			d_cancellable = new Cancellable();

			d_loaded = false;

			// Load the diff base html
			var uri = "gitg-diff:///resource/org/gnome/gitg/ui/diff-view/diff-view.html?viewid=" + s_diff_id.to_string();

			uri += "&settings=" + Soup.URI.encode(json_settings(), null);

			load_uri(uri);
		}

		public DiffView()
		{
			Object();
		}

		public void loaded()
		{
			d_loaded = true;
			update();
		}

		private void update_tab_width()
		{
			if (!d_loaded)
			{
				return;
			}

			run_javascript.begin(@"update_tab_width($d_tab_width);", null, (obj, res) => {
				try
				{
					run_javascript.end(res);
				} catch {}
			});
		}

		private void update()
		{
			if (!d_loaded)
			{
				return;
			}

			// If both `d_diff` and `d_commit` are null, clear
			// the diff content
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
				int parent = 0;
				var parents = d_commit.get_parents();

				if (d_parent != null)
				{
					for (var i = 0; i < parents.size; i++)
					{
						var id = parents.get_id(i);

						if (id.to_string() == d_parent)
						{
							parent = i;
							break;
						}
					}
				}

				d_diff = d_commit.get_diff(options, parent);
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

		public void update_has_selection(bool hs)
		{
			if (d_has_selection != hs)
			{
				d_has_selection = hs;
				notify_property("has-selection");
			}
		}

		public void load_parent(string id)
		{
			request_select_commit(id);
		}

		public void select_parent(string id)
		{
			d_parent = id;
			update();
		}

		public void open_url(string url)
		{
			try
			{
				Gtk.show_uri(null, url, 0);
			} catch {}
		}

		private PatchSet parse_patchset(Json.Node node)
		{
			PatchSet ret = new PatchSet();

			var elems = node.get_array();
			ret.filename = elems.get_element(0).get_string();

			var ps = elems.get_element(1).get_array();

			var l = ps.get_length();
			ret.patches = new PatchSet.Patch[l];

			for (uint i = 0; i < l; i++)
			{
				var p = ps.get_element(i).get_array();

				ret.patches[i] = PatchSet.Patch() {
					type = (PatchSet.Type)p.get_element(0).get_int(),
					old_offset = (size_t)p.get_element(1).get_int(),
					new_offset = (size_t)p.get_element(2).get_int(),
					length = (size_t)p.get_element(3).get_int()
				};
			}

			return ret;
		}

		public async PatchSet[] get_selection()
		{
			WebKit.JavascriptResult jsret;

			try
			{
				jsret = yield run_javascript("get_selection();", d_cancellable);
			}
			catch (Error e)
			{
				stderr.printf("Error running get_selection(): %s\n", e.message);
				return new PatchSet[] {};
			}

			var json = GitgJsUtils.get_json(jsret);
			var parser = new Json.Parser();

			try
			{
				parser.load_from_data(json, -1);
			}
			catch (Error e)
			{
				stderr.printf("Error parsing json: %s\n", e.message);
				return new PatchSet[] {};
			}

			var root = parser.get_root();

			var elems = root.get_array();
			var l = elems.get_length();

			var ret = new PatchSet[l];

			for (uint i = 0; i < l; i++)
			{
				ret[i] = parse_patchset(elems.get_element(i));
			}

			return ret;
		}

		protected override bool context_menu(WebKit.ContextMenu   menu,
		                                     Gdk.Event            event,
		                                     WebKit.HitTestResult hit_test_result)
		{
			var m = new Gtk.Popover(this);
			var opts = new DiffViewOptions(this);

			m.add(opts);

			if (event.type == Gdk.EventType.BUTTON_PRESS ||
			    event.type == Gdk.EventType.BUTTON_RELEASE)
			{
				var r = Gdk.Rectangle() {
					x = (int)event.button.x,
					y = (int)event.button.y,
					width = 1,
					height = 1
				};

				m.set_pointing_to(r);
			}

			opts.show();
			m.show();

			opts.notify["visible"].connect(() => {
				m.destroy();
			});

			return true;
		}
	}
}

// ex:ts=4 noet
