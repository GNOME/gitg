/*
 * This file is part of gitg
 *
 * Copyright (C) 2015 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-diff-view-file.ui")]
class Gitg.DiffViewFile : Gtk.Grid
{
	[GtkChild( name = "expander" )]
	private unowned Gtk.Expander d_expander;

	[GtkChild( name = "label_file_header" )]
	private unowned Gtk.Label d_label_file_header;

	[GtkChild( name = "diff_stat_file" )]
	private unowned DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_content" )]
	private unowned Gtk.Revealer d_revealer_content;

	[GtkChild( name = "stack_switcher" )]
	private unowned Gtk.StackSwitcher? d_stack_switcher;

	[GtkChild( name = "stack_file_renderer" )]
	private unowned Gtk.Stack? d_stack_file_renderer;

	private bool d_expanded;

	public Gee.ArrayList<DiffViewFileRenderer> renderer_list {get; private set;}

	public bool new_is_workdir { get; construct set; }

	public bool expanded
	{
		get
		{
			return d_expanded;
		}

		set
		{
			if (d_expanded != value)
			{
				d_expanded = value;
				d_revealer_content.reveal_child = d_expanded;
				bool visible = false;
				if (d_expanded)
				{
					visible = d_stack_file_renderer.get_children().length() > 1;
				}
				d_stack_switcher.set_visible(visible);


				var ctx = get_style_context();

				if (d_expanded)
				{
					ctx.add_class("expanded");
				}
				else
				{
					ctx.remove_class("expanded");
				}
			}
		}
	}

	public DiffViewFileInfo? info {get; construct set;}
	private Gee.HashMap<Gtk.Widget, bool> d_diff_stat_visible_map = new Gee.HashMap<Gtk.Widget, bool>();

	public bool has_selection()
	{
		bool has_selection = false;
		foreach (DiffViewFileRenderer renderer in renderer_list)
		{
			var selectable = renderer as DiffSelectable;
			if (selectable != null)
				has_selection = selectable.has_selection;
			if (has_selection)
				break;
		}
		return has_selection;
	}

	public void clear_selection()
	{
		foreach (var renderer in renderer_list)
		{
			var sel = renderer as DiffSelectable;
			sel.clear_selection();
		}
	}

	public PatchSet get_selection()
	{
		var ret = new PatchSet();

		foreach (var renderer in renderer_list)
		{
			var sel = renderer as DiffSelectable;

			if (sel != null && sel.has_selection && sel.selection.patches.length != 0)
			{
				ret = sel.selection;
				break;
			}
		}

		return ret;
	}

	public DiffViewFile(DiffViewFileInfo? info)
	{
		Object(info: info);
		bind_property("vexpand", d_stack_file_renderer, "vexpand", BindingFlags.SYNC_CREATE);
		d_stack_file_renderer.notify["visible-child"].connect(page_changed);
		renderer_list = new Gee.ArrayList<DiffViewFileRenderer>();
	}

	private void page_changed()
	{
		var visible_child = d_stack_file_renderer.get_visible_child();
		var visible = d_diff_stat_visible_map.get(visible_child);
		d_diff_stat_file.set_visible(visible);
	}

	public void add_renderer(DiffViewFileRenderer renderer, Gtk.Widget widget, string name, string title, bool show_stats)
	{
		d_diff_stat_visible_map.set(widget, show_stats);
		renderer_list.add(renderer);
		d_stack_file_renderer.add_titled(widget, name, title);
	}

	private void setup_hscrollbar_margins(Gtk.ScrolledWindow sw, Gtk.TextView view)
	{
		view.realize.connect(() => {
			Idle.add(() => update_hscrollbar_margin(sw, view));
		});

		view.style_updated.connect(() => {
			Idle.add(() => update_hscrollbar_margin(sw, view));
		});

		view.size_allocate.connect((allocation) => {
			Idle.add(() => update_hscrollbar_margin(sw, view));
		});
	}

	private bool update_hscrollbar_margin(Gtk.ScrolledWindow sw, Gtk.TextView view)
	{
		var hbar = sw.get_hscrollbar();
		if (hbar == null || !view.get_realized())
		{
			return false;
		}

		var win = view.get_window(Gtk.TextWindowType.LEFT);
		if (win == null)
		{
			return false;
		}

		int gutter_width = win.get_width();
		if (gutter_width >= 0)
		{
			hbar.margin_start = gutter_width;
		}

		return false;
	}

	public void add_text_renderer(bool handle_selection)
	{
		var renderer = new DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.ONE);
		renderer.show();
		var scrolled_window = new Gtk.ScrolledWindow (null, null);
		scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
		scrolled_window.add(renderer);
		setup_hscrollbar_margins(scrolled_window, renderer);
		scrolled_window.show();

		renderer.bind_property("added", d_diff_stat_file, "added");
		renderer.bind_property("removed", d_diff_stat_file, "removed");
		// Translators: Unif stands for unified diff format
		add_renderer(renderer, scrolled_window, "unified", _("Unif"), true);

		var renderer_split = new DiffViewFileRendererTextSplit(info, handle_selection);
		renderer_split.show();
		// Translators: Split stands for the noun
		add_renderer(renderer_split, renderer_split, "split", _("Split"), true);

		// Set default view based on user preference
		var settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");
		d_stack_file_renderer.set_visible_child_name(settings.get_string("text-diff-mode"));
	}

	public void add_binary_renderer()
	{
		var renderer = new DiffViewFileRendererBinary();
		renderer.show();
		add_renderer(renderer, renderer, "binary", _("Binary"), false);
	}

	public void add_image_renderer()
	{
		var renderer = new DiffViewFileRendererImage(info.repository, info.delta);
		renderer.show();
		add_renderer(renderer, renderer, "image", _("Image"), false);
	}

	protected override void constructed()
	{
		base.constructed();

		var delta = info.delta;
		var oldfile = delta.get_old_file();
		var newfile = delta.get_new_file();

		var oldpath = (oldfile != null ? oldfile.get_path() : null);
		var newpath = (newfile != null ? newfile.get_path() : null);

		if (delta.get_similarity() > 0)
		{
			d_label_file_header.label = @"$(newfile.get_path()) ← $(oldfile.get_path())";
		}
		else if (newpath != null)
		{
			d_label_file_header.label = newpath;
		}
		else
		{
			d_label_file_header.label = oldpath;
		}

		d_expander.bind_property("expanded", this, "expanded", BindingFlags.BIDIRECTIONAL);

		var repository = info.repository;
		if (repository != null && !repository.is_bare)
		{
			var gesture = new Gtk.GestureClick();
			gesture.set_button(0);
			gesture.pressed.connect((npress, x, y) => {
				var event = gesture.get_current_event();
				if (event.triggers_context_menu())
				{
					show_popup(x, y);
					gesture.set_state(Gtk.EventSequenceState.CLAIMED);
				}
			});

			var key_controller = new Gtk.EventControllerKey();
			key_controller.key_pressed.connect((keyval, keycode, state) => {
				if (keyval == Gdk.Key.Menu ||
					(keyval == Gdk.Key.F10 && (state & Gdk.ModifierType.SHIFT_MASK) != 0))
				{
					show_popup(0, 0);
					return true;
				}
				return false;
			});
			d_expander.add_controller(gesture);
			d_expander.add_controller(key_controller);
		}
	}

	private void show_popup(double x, double y)
	{
		var menu = new GLib.Menu();

		var delta  = info.delta;
		var oldpath = delta.get_old_file().get_path();
		var newpath = delta.get_new_file().get_path();

		var action_group = new GLib.SimpleActionGroup();
		var open_file_action = new GLib.SimpleAction("open-file", null);

		File? location = null;

		var repository = info.repository;
		if (newpath != null && newpath != "")
		{
			location = repository.get_workdir().get_child(newpath);
		}
		else if (oldpath != null && oldpath != "")
		{
			location = repository.get_workdir().get_child(oldpath);
		}

		if (location == null)
		{
			return;
		}

		open_file_action.activate.connect(() => {
			try
			{
				Gtk.show_uri_on_window((Gtk.Window)d_expander.get_toplevel(), location.get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open file: $(e.message)\n");
			}
		});
		action_group.add_action(open_file_action);

		var open_folder_action = new GLib.SimpleAction("open-folder", null);

		open_folder_action.activate.connect(() => {
			try
			{
				Gtk.show_uri_on_window((Gtk.Window)d_expander.get_toplevel(), location.get_parent().get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open folder: $(e.message)\n");
			}
		});

		action_group.add_action(open_folder_action);

		menu.append(_("_Open file"), "popup.open-file");
		menu.append(_("Open containing _folder"), "popup.open-folder");

		var copy_path_action = new GLib.SimpleAction("copy-path", null);
		copy_path_action.activate.connect(() => {
			var clip = d_expander.get_clipboard();
			clip.set_text(location.get_path());
		});

		action_group.add_action(copy_path_action);
		var copy_section = new GLib.Menu();
		copy_section.append(_("_Copy file path"), "popup.copy-path");
		menu.append_section(null, copy_section);

		var popover = new Gtk.PopoverMenu.from_model(menu);
		popover.set_parent(d_expander);
		popover.insert_action_group("popup", action_group);

		var rect = Gdk.Rectangle() {
			x = (int)x,
			y = (int)y
		};
		popover.set_pointing_to(rect);

		popover.closed.connect(popover.unparent);
		popover.popup();
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		foreach (DiffViewFileRenderer renderer in renderer_list)
		{
			renderer.add_hunk(hunk, lines);
		}
	}
}

// ex:ts=4 noet
