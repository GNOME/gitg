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

		private static Gee.HashMap<string, GitgGtk.DiffView> s_diffmap;
		private static uint64 s_diff_id;

		public File? custom_css { get; construct; }
		public File? custom_js { get; construct; }
		public Ggit.DiffOptions? options { get; construct set; }

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
			var r = new Soup.Requester();

			r.add_feature(typeof(DiffViewRequest));

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

			var dbg = Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != "";

			if (dbg)
			{
				settings.enable_developer_extras = true;
			}

			settings.javascript_can_access_clipboard = true;
			set_settings(settings);

			if (dbg)
			{
				var inspector = get_inspector();

				inspector.inspect_web_view.connect((insp, view) => {
					var wnd = new Gtk.Window();
					wnd.set_default_size(400, 300);

					var nvw = new WebKit.WebView();
					nvw.show();

					wnd.add(nvw);
					wnd.show();

					return wnd.get_child() as WebKit.WebView;
				});
			}

			++s_diff_id;
			s_diffmap[s_diff_id.to_string()] = this;

			document_load_finished.connect((v, fr) => {
				d_loaded = true;
				update();
			});

			// Load the diff base html
			var uri = "gitg-internal:///resource/org/gnome/gitg/gtk/diff-view/base.html?viewid=" + s_diff_id.to_string();

			// Add custom js as a query parameter
			if (custom_js != null)
			{
				uri += "&js=" + Soup.URI.encode(custom_js.get_uri(), null);
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
				execute_script("update_diff();");
			}
		}
	}
}

// vi:ts=4
