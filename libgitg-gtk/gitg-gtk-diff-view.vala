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

			settings.javascript_can_access_clipboard = true;
			set_settings(settings);

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
			if (!d_loaded || d_diff == null)
			{
				return;
			}

			execute_script("update_diff();");
		}
	}
}

// vi:ts=4
