/*
 * This file is part of gitg
 *
 * Copyright (C) 2019 - Alberto Fanjul
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

namespace Gitg
{

public class FontManager: Object
{
	private Settings d_font_settings;
	private Settings d_global_settings;
	private Gtk.CssProvider css_provider;

	public FontManager (Gtk.TextView text_view, bool plugin) {
		if (plugin) {
			d_font_settings = try_settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
			d_global_settings = try_settings("org.gnome.desktop.interface");
		} else {
			d_font_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
			d_global_settings = new Settings("org.gnome.desktop.interface");
		}
		css_provider = new Gtk.CssProvider();
		if (d_font_settings != null) {
			d_font_settings.changed["use-default-font"].connect((s, k) => {
				update_font_settings();
			});
			d_font_settings.changed["monospace-font-name"].connect((s, k) => {
				update_font_settings();
			});
		}
		if (d_global_settings != null) {
			d_global_settings.changed["monospace-font-name"].connect((s, k) => {
				update_font_settings();
			});
		}
		text_view.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS);
		update_font_settings();
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

	private void update_font_settings()
	{
		var fname = d_font_settings.get_string("monospace-font-name");
		if (d_font_settings.get_boolean("use-default-font") && d_global_settings != null) {
			fname = d_global_settings.get_string("monospace-font-name");
		}

		var font_desc = Pango.FontDescription.from_string(fname);
		var css = "textview { %s }".printf(Dazzle.pango_font_description_to_css(font_desc));
		try
		{
			css_provider.load_from_data(css);
		}
		catch(Error e)
		{
			warning("Error applying font: %s", e.message);
		}
	}
}
}
