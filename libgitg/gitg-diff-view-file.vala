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
	private Gtk.Expander d_expander;

	[GtkChild( name = "label_file_header" )]
	private Gtk.Label d_label_file_header;

	[GtkChild( name = "diff_stat_file" )]
	private DiffStat d_diff_stat_file;

	[GtkChild( name = "revealer_content" )]
	private Gtk.Revealer d_revealer_content;

	[GtkChild( name = "box_file_renderer" )]
	private Gtk.Box d_box_file_renderer;

	[GtkChild( name = "split_button" )]
	private Gtk.RadioButton split_button;

	[GtkChild( name = "unif_button" )]
	private Gtk.RadioButton unif_button;

	private Gtk.ScrolledWindow d_scrolledwindow;
	private Gtk.ScrolledWindow d_scrolledwindow_left;
	private Gtk.ScrolledWindow d_scrolledwindow_right;

	private bool d_expanded;

	private Binding? d_vexpand_binding;
	private Binding? d_vexpand_binding_l;
	private Binding? d_vexpand_binding_r;

	private bool d_split { get; set; default = false; }

	private DiffViewFileRenderer? d_renderer;
	private DiffViewFileRenderer? d_renderer_left;
	private DiffViewFileRenderer? d_renderer_right;

	public DiffViewFileRenderer? renderer
	{
		owned get
		{
			return d_renderer;
		}

		construct set
		{
			var current = this.renderer;

			if (current != value)
			{
				if (d_vexpand_binding != null)
				{
					d_vexpand_binding.unbind();
					d_vexpand_binding = null;
				}

				if (current != null)
				{
					d_scrolledwindow.remove(current);
					d_box_file_renderer.remove(d_scrolledwindow);
				}

				d_renderer = value;
				d_scrolledwindow.add(value);
				d_scrolledwindow.show();

				if (!d_split)
				{
					d_box_file_renderer.pack_start(d_scrolledwindow, true, true, 0);
				}

				d_vexpand_binding = this.bind_property("vexpand", value, "vexpand", BindingFlags.SYNC_CREATE);
			}
		}
	}

	public DiffViewFileRenderer? renderer_left
	{
		owned get
		{
			return d_renderer_left;
		}

		construct set
		{
			var current = this.renderer_left;

			if (current != value)
			{
				if (d_vexpand_binding_l != null)
				{
					d_vexpand_binding_l.unbind();
					d_vexpand_binding_l = null;
				}

				if (current != null)
				{
					d_scrolledwindow_left.remove(current);
					d_box_file_renderer.remove(d_scrolledwindow_left);
				}

				d_renderer_left = value;
				d_scrolledwindow_left.add(value);
				d_scrolledwindow_left.show();

				if (d_split)
				{
					d_box_file_renderer.pack_start(d_scrolledwindow_left, true, true, 0);
				}

				d_vexpand_binding_l = this.bind_property("vexpand", value, "vexpand", BindingFlags.SYNC_CREATE);
			}
		}
	}

	public DiffViewFileRenderer? renderer_right
	{
		owned get
		{
			return d_renderer_right;
		}

		construct set
		{
			var current = this.renderer_right;

			if (current != value)
			{
				if (d_vexpand_binding_r != null)
				{
					d_vexpand_binding_r.unbind();
					d_vexpand_binding_r = null;
				}

				if (current != null)
				{
					d_scrolledwindow_right.remove(current);
					d_box_file_renderer.remove(d_scrolledwindow_right);
				}

				d_renderer_right = value;
				d_scrolledwindow_right.add(value);
				d_scrolledwindow_right.show();

				if (d_split)
				{
					d_box_file_renderer.pack_start(d_scrolledwindow_right, true, true, 0);
				}

				d_vexpand_binding_r = this.bind_property("vexpand", value, "vexpand", BindingFlags.SYNC_CREATE);
			}
		}
	}

	[GtkCallback]
	private void split_button_toggled(Gtk.ToggleButton button)
	{
		d_split = !d_split;
		if (d_split)
		{
			d_box_file_renderer.remove(d_scrolledwindow);
			d_box_file_renderer.pack_start(d_scrolledwindow_left, true, true, 0);
			d_box_file_renderer.pack_end(d_scrolledwindow_right, true, true, 0);
		}
		else
		{
			d_box_file_renderer.remove(d_scrolledwindow_left);
			d_box_file_renderer.remove(d_scrolledwindow_right);
			d_box_file_renderer.pack_start(d_scrolledwindow, true, true, 0);
		}
	}

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

	public Ggit.DiffDelta? delta { get; construct set; }
	public Repository? repository { get; construct set; }

	public DiffViewFile(Repository? repository, Ggit.DiffDelta delta)
	{
		Object(repository: repository, delta: delta);
	}

	construct
	{
		d_scrolledwindow = new Gtk.ScrolledWindow(null, null);
		d_scrolledwindow_left = new Gtk.ScrolledWindow(null, null);
		d_scrolledwindow_right = new Gtk.ScrolledWindow(null, null);

		d_scrolledwindow.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
		d_scrolledwindow_left.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
		d_scrolledwindow_right.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.NEVER);
	}

	public DiffViewFile.text(DiffViewFileInfo info, bool handle_selection)
	{
		this(info.repository, info.delta);

		this.renderer = new DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.ONE);
		this.renderer.show();

		this.renderer.bind_property("added", d_diff_stat_file, "added");
		this.renderer.bind_property("removed", d_diff_stat_file, "removed");

		this.renderer_left = new DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.OLD);
		this.renderer_left.show();

		this.renderer_left.bind_property("added", d_diff_stat_file, "added");
		this.renderer_left.bind_property("removed", d_diff_stat_file, "removed");

		this.renderer_right = new DiffViewFileRendererText(info, handle_selection, DiffViewFileRendererText.Style.NEW);
		this.renderer_right.show();

		this.renderer_right.bind_property("added", d_diff_stat_file, "added");
		this.renderer_right.bind_property("removed", d_diff_stat_file, "removed");
	}

	public DiffViewFile.binary(Repository? repository, Ggit.DiffDelta delta)
	{
		this(repository, delta);

		this.renderer = new DiffViewFileRendererBinary();
		this.renderer.show();
		unif_button.hide();
		split_button.hide();
		d_diff_stat_file.hide();
	}

	public DiffViewFile.image(Repository? repository, Ggit.DiffDelta delta)
	{
		this(repository, delta);

		this.renderer = new DiffViewFileRendererImage(repository, delta);
		this.renderer.show();
		unif_button.hide();
		split_button.hide();
		d_diff_stat_file.hide();
	}

	protected override void constructed()
	{
		base.constructed();

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

		if (repository != null && !repository.is_bare)
		{
			d_expander.popup_menu.connect(expander_popup_menu);
			d_expander.button_press_event.connect(expander_button_press_event);
		}
	}

	private void show_popup(Gdk.EventButton? event)
	{
		var menu = new Gtk.Menu();

		var oldpath = delta.get_old_file().get_path();
		var newpath = delta.get_new_file().get_path();

		var open_file = new Gtk.MenuItem.with_mnemonic(_("_Open file"));
		open_file.show();

		File? location = null;

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

		open_file.activate.connect(() => {
			try
			{
				Gtk.show_uri(d_expander.get_screen(), location.get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open file: $(e.message)\n");
			}
		});

		menu.add(open_file);

		var open_folder = new Gtk.MenuItem.with_mnemonic(_("Open containing _folder"));
		open_folder.show();

		open_folder.activate.connect(() => {
			try
			{
				Gtk.show_uri(d_expander.get_screen(), location.get_parent().get_uri(), Gdk.CURRENT_TIME);
			}
			catch (Error e)
			{
				stderr.printf(@"Failed to open folder: $(e.message)\n");
			}
		});

		menu.add(open_folder);

		var separator = new Gtk.SeparatorMenuItem();
		separator.show();
		menu.add(separator);

		var copy_file_path = new Gtk.MenuItem.with_mnemonic(_("_Copy file path"));
		copy_file_path.show();

		copy_file_path.activate.connect(() => {
			var clip = d_expander.get_clipboard(Gdk.SELECTION_CLIPBOARD);
			clip.set_text(location.get_path(), -1);
		});

		menu.add(copy_file_path);

		menu.attach_to_widget(d_expander, null);
		menu.popup_at_pointer(event);
	}

	private bool expander_button_press_event(Gtk.Widget widget, Gdk.EventButton? event)
	{
		if (event.triggers_context_menu())
		{
			show_popup(event);
			return true;
		}

		return false;
	}

	private bool expander_popup_menu(Gtk.Widget widget)
	{
		show_popup(null);
		return true;
	}

	public void add_hunk(Ggit.DiffHunk hunk, Gee.ArrayList<Ggit.DiffLine> lines)
	{
		this.renderer.add_hunk(hunk, lines);
		if (this.renderer_left != null && this.renderer_right !=null)
		{
			this.renderer_left.add_hunk(hunk, lines);
			this.renderer_right.add_hunk(hunk, lines);
		}
	}
}

// ex:ts=4 noet
