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

[GtkTemplate ( ui = "/org/gnome/gitg/ui/gitg-diff-view-options.ui" )]
public class Gitg.DiffViewOptions : Gtk.Toolbar
{
	[GtkChild (name = "adjustment_context")]
	private Gtk.Adjustment d_adjustment_context;

	[GtkChild (name = "tool_button_spacing")]
	private Gtk.ToolButton d_tool_button_spacing;

	public int context_lines { get; set; }

	private Gee.List<Binding> d_bindings;
	private DiffView? d_view;
	private ulong d_notify_commit_id;

	private DiffViewOptionsSpacing d_popover_spacing;

	public DiffView? view
	{
		get { return d_view; }

		construct set
		{
			if (d_view == value)
			{
				return;
			}

			var old_view = d_view;
			d_view = value;

			view_changed(old_view);
		}
	}

	public DiffViewOptions(DiffView? view = null)
	{
		Object(view: view);
	}

	construct
	{
		d_bindings = new Gee.LinkedList<Binding>();

		d_popover_spacing = new DiffViewOptionsSpacing();
		d_popover_spacing.relative_to = d_tool_button_spacing;
	}

	public override void dispose()
	{
		this.view = null;
		base.dispose();
	}

	private void view_changed(DiffView? old_view)
	{
		foreach (var binding in d_bindings)
		{
			binding.unbind();
		}

		d_bindings.clear();

		if (d_notify_commit_id != 0)
		{
			old_view.disconnect(d_notify_commit_id);
			d_notify_commit_id = 0;
		}

		if (d_view == null)
		{
			update_commit();
			return;
		}

		d_bindings.add(
			d_view.bind_property("ignore-whitespace",
			                     d_popover_spacing,
			                     "ignore-whitespace",
			                     BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE)
		);
		
		d_bindings.add(
			d_view.bind_property("wrap-lines",
		    	                 d_popover_spacing,
			                     "wrap-lines",
			                     BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE)
		);

		d_bindings.add(
			d_view.bind_property("tab-width",
			                     d_popover_spacing,
			                     "tab-width",
			                     BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE)
		);

		d_bindings.add(
			d_view.bind_property("context-lines",
			                     this,
			                     "context-lines",
			                     BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE)
		);

		d_notify_commit_id = d_view.notify["commit"].connect(update_commit);

		update_commit();
	}

	private void update_commit()
	{
		var iscommit = d_view != null && d_view.commit != null;
		d_popover_spacing.ignore_whitespace_visible = iscommit;
	}

	protected override void constructed()
	{
		bind_property("context-lines",
		              d_adjustment_context,
		              "value",
		              BindingFlags.BIDIRECTIONAL |
		              BindingFlags.SYNC_CREATE,
		              Transforms.int_to_double,
		              Transforms.double_to_int);
	}

	[GtkCallback]
	private void clicked_on_tool_button_spacing(Gtk.Widget widget)
	{
		d_popover_spacing.show();
	}
}

[GtkTemplate ( ui = "/org/gnome/gitg/ui/gitg-diff-view-options-spacing.ui" )]
private class Gitg.DiffViewOptionsSpacing : Gtk.Popover
{
	[GtkChild (name = "switch_ignore_whitespace")]
	private Gtk.Switch d_switch_ignore_whitespace;

	[GtkChild (name = "label_ignore_whitespace")]
	private Gtk.Label d_label_ignore_whitespace;

	[GtkChild (name = "switch_wrap_lines")]
	private Gtk.Switch d_switch_wrap_lines;

	[GtkChild (name = "adjustment_tab_width")]
	private Gtk.Adjustment d_adjustment_tab_width;

	public bool ignore_whitespace { get; set; }
	public bool wrap_lines { get; set; }
	public int tab_width { get; set; }

	public bool ignore_whitespace_visible { get; set; }

	protected override void constructed()
	{
		bind_property("ignore-whitespace",
		              d_switch_ignore_whitespace,
		              "active",
		              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

		bind_property("wrap-lines",
		              d_switch_wrap_lines,
		              "active",
		              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

		bind_property("tab-width",
		              d_adjustment_tab_width,
		              "value",
		              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE,
		              Transforms.int_to_double,
		              Transforms.double_to_int);

		bind_property("ignore-whitespace-visible",
		              d_switch_ignore_whitespace,
		              "visible",
		              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);

		bind_property("ignore-whitespace-visible",
		              d_label_ignore_whitespace,
		              "visible",
		              BindingFlags.BIDIRECTIONAL | BindingFlags.SYNC_CREATE);
	}
}

private class Gitg.Transforms
{
	public static bool double_to_int(Binding binding,
	                                 Value source_value,
	                                 ref Value target_value)
	{
		target_value.set_int((int)source_value.get_double());
		return true;
	}

	public static bool int_to_double(Binding binding,
	                                 Value source_value,
	                                 ref Value target_value)
	{
		target_value.set_double((double)source_value.get_int());
		return true;
	}
}
