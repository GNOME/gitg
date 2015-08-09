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

[GtkTemplate ( ui = "/org/gnome/gitg/ui/diff-view/diff-view-options.ui" )]
public class DiffViewOptions : Gtk.Grid
{
	[GtkChild (name = "switch_changes_inline")]
	private Gtk.Switch d_switch_changes_inline;

	[GtkChild (name = "label_changes_inline")]
	private Gtk.Label d_label_changes_inline;

	[GtkChild (name = "switch_ignore_whitespace")]
	private Gtk.Switch d_switch_ignore_whitespace;

	[GtkChild (name = "label_ignore_whitespace")]
	private Gtk.Label d_label_ignore_whitespace;

	[GtkChild (name = "wrap")]
	private Gtk.Switch d_switch_wrap;

	[GtkChild (name = "adjustment_context")]
	private Gtk.Adjustment d_adjustment_context;

	[GtkChild (name = "adjustment_tab_width")]
	private Gtk.Adjustment d_adjustment_tab_width;

	[GtkChild (name = "button_developer_tools")]
	private Gtk.Button d_button_developer_tools;

	[GtkChild (name = "separator_developer_tools")]
	private Gtk.Separator d_separator_developer_tools;

	[GtkChild (name = "separator_first_options")]
	private Gtk.Separator d_separator_first_options;

	public bool changes_inline { get; set; }
	public bool ignore_whitespace { get; set; }
	public bool wrap { get; set; }
	public int context_lines { get; set; }
	public int tab_width { get; set; }

	public DiffView view { get; construct set; }

	public DiffViewOptions(DiffView view)
	{
		Object(view: view);
	}

	private bool transform_double_to_int(Binding binding,
	                                     Value source_value,
	                                     ref Value target_value)
	{
		target_value.set_int((int)source_value.get_double());
		return true;
	}

	private bool transform_int_to_double(Binding binding,
	                                     Value source_value,
	                                     ref Value target_value)
	{
		target_value.set_double((double)source_value.get_int());
		return true;
	}

	protected override void constructed()
	{
		view.bind_property("changes-inline",
		                   this,
		                   "changes-inline",
		                   BindingFlags.BIDIRECTIONAL |
		                   BindingFlags.SYNC_CREATE);

		view.bind_property("ignore-whitespace",
		                   this,
		                   "ignore-whitespace",
		                   BindingFlags.BIDIRECTIONAL |
		                   BindingFlags.SYNC_CREATE);

		view.bind_property("wrap",
		                   this,
		                   "wrap",
		                   BindingFlags.BIDIRECTIONAL |
		                   BindingFlags.SYNC_CREATE);

		view.bind_property("context-lines",
		                   this,
		                   "context-lines",
		                   BindingFlags.BIDIRECTIONAL |
		                   BindingFlags.SYNC_CREATE);

		view.bind_property("tab-width",
		                   this,
		                   "tab-width",
		                   BindingFlags.BIDIRECTIONAL |
		                   BindingFlags.SYNC_CREATE);

		bind_property("changes-inline",
		              d_switch_changes_inline,
		              "active",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE);

		bind_property("ignore-whitespace",
		              d_switch_ignore_whitespace,
		              "active",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE);

		bind_property("wrap",
		              d_switch_wrap,
		              "active",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE);

		bind_property("context-lines",
		              d_adjustment_context,
		              "value",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE,
		              transform_int_to_double,
		              transform_double_to_int);

		bind_property("tab-width",
		              d_adjustment_tab_width,
		              "value",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE,
		              transform_int_to_double,
		              transform_double_to_int);

		var dbg = (Environment.get_variable("GITG_GTK_DIFF_VIEW_DEBUG") != null);

		d_separator_developer_tools.visible = dbg;
		d_button_developer_tools.visible = dbg;

		if (view.commit == null)
		{
			d_label_changes_inline.visible = false;
			d_switch_changes_inline.visible = false;

			d_label_ignore_whitespace.visible = false;
			d_switch_ignore_whitespace.visible = false;

			d_separator_first_options.visible = false;
		}
	}

	[GtkCallback]
	private void on_button_developer_tools_clicked()
	{
		view.get_inspector().show();
		hide();
	}
}

}
