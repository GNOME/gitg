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

	private string pango_font_description_to_css(Pango.FontDescription fd)
	{
		string font_to_css = "";
		var family = fd.get_family();
		font_to_css += @"font-family:\"$family\";";

		var style = fd.get_style();
		var style_txt = "";
		switch(style)
		{
			case Pango.Style.NORMAL:
				style_txt = "normal";
				break;
			case Pango.Style.OBLIQUE:
				style_txt = "oblique";
				break;
			case Pango.Style.ITALIC:
				style_txt = "italic";
				break;
			default:
				break;
		}

		if (style_txt != "")
			font_to_css += @"font-style:$style_txt;";

		var variant = fd.get_variant();
		var variant_txt = "";
		switch(variant)
		{
			case Pango.Variant.NORMAL:
				variant_txt = "normal";
				break;
			case Pango.Variant.SMALL_CAPS:
				variant_txt = "small-caps";
				break;
			default:
				break;
		}

		if (variant_txt != "")
		font_to_css += @"font-variant:$variant_txt;";

		var weight = fd.get_weight();
		var weight_txt = "";
		switch(weight)
		{
			case Pango.Weight.SEMILIGHT:
			case Pango.Weight.NORMAL:
				weight_txt = "normal";
				break;
			case Pango.Weight.BOLD:
				weight_txt = "bold";
				break;
			default:
				weight_txt = @"$((weight / 100) * 100)";
				break;
		}

		if (weight_txt != "")
			font_to_css += @"font-weight:$weight_txt;";

		var stretch = fd.get_stretch();
		var stretch_txt = "";
		switch(stretch)
		{
			case Pango.Stretch.ULTRA_CONDENSED:
				stretch_txt = "ultra-condensed";
				break;
			case Pango.Stretch.CONDENSED:
				stretch_txt = "condensed";
				break;
			case Pango.Stretch.SEMI_CONDENSED:
				stretch_txt = "semi-condensed";
				break;
			case Pango.Stretch.NORMAL:
				stretch_txt = "normal";
				break;
			case Pango.Stretch.SEMI_EXPANDED:
				stretch_txt = "semi-expanded";
				break;
			case Pango.Stretch.EXPANDED:
				stretch_txt = "expanded";
				break;
			case Pango.Stretch.EXTRA_EXPANDED:
				stretch_txt = "extra-expanded";
				break;
			case Pango.Stretch.ULTRA_EXPANDED:
				stretch_txt = "ultra-expanded";
				break;
			default:
				break;
		}

		if (stretch_txt != "")
			font_to_css += @"font-stretch:$stretch_txt;";

		var size_txt = (fd.get_size()/Pango.SCALE).to_string();
		font_to_css += @"font-size:$(size_txt)pt;";

		return font_to_css;
	}

	private void update_font_settings()
	{
		var fname = d_font_settings.get_string("monospace-font-name");
		if (d_font_settings.get_boolean("use-default-font") && d_global_settings != null) {
			fname = d_global_settings.get_string("monospace-font-name");
		}

		var font_desc = Pango.FontDescription.from_string(fname);
		var css = "textview { %s }".printf(pango_font_description_to_css(font_desc));
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
