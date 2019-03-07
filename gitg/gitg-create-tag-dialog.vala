/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-create-tag-dialog.ui")]
class CreateTagDialog : Gtk.Dialog
{
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	[GtkChild]
	private Gtk.Button d_button_create;

	[GtkChild]
	private Gtk.Entry d_entry_tag_name;

	[GtkChild]
	private Gtk.TextView d_text_view_message;

	private Gtk.TextTag d_info_tag;
	private bool d_is_showing_user_info;
	private Settings d_font_settings;
	private Gtk.CssProvider css_provider;

	construct
	{
		d_font_settings = new Settings("org.gnome.desktop.interface");
		css_provider = new Gtk.CssProvider();
		d_text_view_message.get_style_context().add_provider(css_provider, Gtk.STYLE_PROVIDER_PRIORITY_SETTINGS);

		update_font_settings();

		d_font_settings.changed["monospace-font-name"].connect((s, k) => {
			update_font_settings();
		});

		d_entry_tag_name.changed.connect(() => {
			d_button_create.sensitive = (new_tag_name.length != 0);
		});

		set_default(d_button_create);

		var buf = d_text_view_message.buffer;
		d_info_tag = buf.create_tag("info");

		d_text_view_message.style_updated.connect(() => {
			update_info_tag();
		});

		d_text_view_message.focus_in_event.connect(() => {
			if (d_is_showing_user_info)
			{
				Gtk.TextIter start, end;
				buf.get_bounds(out start, out end);

				buf.delete(ref start, ref end);
			}

			return false;
		});

		d_text_view_message.focus_out_event.connect(() => {
			show_user_info();
			return false;
		});

		update_info_tag();
		show_user_info();

		set_default_response(Gtk.ResponseType.OK);
	}

	private void update_font_settings()
	{
		var fname = d_font_settings.get_string("monospace-font-name");
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

	private void show_user_info()
	{
		var buf = d_text_view_message.buffer;

		Gtk.TextIter start, end;
		buf.get_bounds(out start, out end);

		if (start.compare(end) == 0 && !d_text_view_message.has_focus)
		{
#if VALA_0_28
			buf.insert_with_tags(ref start,
#else
			buf.insert_with_tags(start,
#endif
			                     _("Provide a message to create an annotated tag"),
			                     -1,
			                     d_info_tag);

			d_is_showing_user_info = true;
		}
		else
		{
			d_is_showing_user_info = false;
		}
	}

	private void update_info_tag()
	{
		var ctx = d_text_view_message.get_style_context();
		d_info_tag.foreground_rgba = ctx.get_color(Gtk.StateFlags.INSENSITIVE);
	}

	public CreateTagDialog(Gtk.Window? parent)
	{
		Object(use_header_bar : 1);

		if (parent != null)
		{
			set_transient_for(parent);
		}
	}

	public string new_tag_name
	{
		owned get
		{
			return d_entry_tag_name.text.strip();
		}
	}

	public string new_tag_message
	{
		owned get
		{
			if (d_is_showing_user_info)
			{
				return "";
			}

			var buf = d_text_view_message.buffer;

			Gtk.TextIter start, end;
			buf.get_bounds(out start, out end);

			return buf.get_text(start, end, false);
		}
	}
}

}

// ex: ts=4 noet
