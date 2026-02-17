/*
 * This file is part of gitg
 *
 * Copyright (C) 2026 - Alberto Fanjul
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

using Gtk;

namespace GitgHistory
{

const TargetEntry[] entries = {
	{ "GTK_LIST_BOX_ROW", Gtk.TargetFlags.SAME_APP, 0}
};

class ListRow: Object {
	public string name {get; set;}
	public Gtk.TreeViewColumn col {get; set;}

	public ListRow(string name, Gtk.TreeViewColumn col) {
		Object(name: name, col: col);
	}
}

public class DragListBox : ListBox {
	private GLib.ListStore model;

	private ListBoxRow? hover_row;
	public ListBoxRow? drag_row;
	private bool top = false;
	private int hover_top;
	private int hover_bottom;
	private bool should_scroll = false;
	private bool scrolling = false;
	private bool scroll_up;

	private const int SCROLL_STEP_SIZE = 8;
	private const int SCROLL_DISTANCE = 30;
	private const int SCROLL_DELAY = 50;

	public signal void row_reorder(int from, int to);

	public Adjustment? vadjustment {
		public set {
			_vadjustment = value;
			if (_vadjustment == null) {
				should_scroll = false;
			}
		}
		public get {
			return _vadjustment;
		}
	}

	private Adjustment? _vadjustment;

	public DragListBox (GLib.ListStore model) {
		this.model = model;
		bind_model(model, (i) => {
		   var row = i as ListRow;
		   var w = new ListBoxRowDnD(row.name, row.col.visible);
		   w.switch_changed.connect((state) => {
			   row.col.visible = state;
		   });
		   return w;
		});
		drag_dest_set (this, Gtk.DestDefaults.ALL, entries, Gdk.DragAction.MOVE);
	}

	public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time) {
			//print("%d\n", y);
		if (y > hover_top || y < hover_bottom) {
			Allocation alloc;
			var row = get_row_at_y (y);
			bool old_top = top;

			row.get_allocation (out alloc);
			int hover_row_y = alloc.y;
			int hover_row_height = alloc.height;
			if (row != drag_row) {
				if (y < hover_row_y + hover_row_height/2) {
					hover_top = hover_row_y;
					hover_bottom = hover_top + hover_row_height/2;
					row.get_style_context ().add_class ("drag-hover-top");
					row.get_style_context ().remove_class ("drag-hover-bottom");
					top = true;
				} else {
					hover_top = hover_row_y + hover_row_height/2;
					hover_bottom = hover_row_y + hover_row_height;
					row.get_style_context ().add_class ("drag-hover-bottom");
					row.get_style_context ().remove_class ("drag-hover-top");
					top = false;
				}
			}

			if (hover_row != null && hover_row != row) {
				if (old_top)
					hover_row.get_style_context ().remove_class ("drag-hover-top");
				else
					hover_row.get_style_context ().remove_class ("drag-hover-bottom");
			}

			hover_row = row;
		}

		check_scroll (y);
		if(should_scroll && !scrolling) {
			scrolling = true;
			Timeout.add (SCROLL_DELAY, scroll);
		}

		return true;
	}

	public override void drag_leave (Gdk.DragContext context, uint time) {
		should_scroll = false;
	}

	void check_scroll (int y) {
		if (vadjustment == null) {
			return;
		}
		double vadjustment_min = vadjustment.value;
		double vadjustment_max = vadjustment.page_size + vadjustment_min;
		double show_min = double.max(0, y - SCROLL_DISTANCE);
		double show_max = double.min(vadjustment.upper, y + SCROLL_DISTANCE);
		if(vadjustment_min > show_min) {
			should_scroll = true;
			scroll_up = true;
		} else if (vadjustment_max < show_max){
			should_scroll = true;
			scroll_up = false;
		} else {
			should_scroll = false;
		}
	}

	bool scroll () {
		if (should_scroll) {
			if(scroll_up) {
				vadjustment.value -= SCROLL_STEP_SIZE;
			} else {
				vadjustment.value += SCROLL_STEP_SIZE;
			}
		} else {
			scrolling = false;
		}
		return should_scroll;
	}

	public override void drag_data_received (
		Gdk.DragContext context, int x, int y,
		SelectionData selection_data, uint info, uint time) {
		Widget handle;
		ListBoxRow row;

		int to = 0;
		if (hover_row != null) {
			var h_index = hover_row.get_index();

			handle = ((Widget[])selection_data.get_data ())[0];
			row = (ListBoxRow) handle.get_ancestor (typeof (ListBoxRow));
			var from = row.get_index();

			bool up_down = from < h_index;

			if (top) {
				if (up_down)
					to = h_index - 1;
				else
					to = h_index;
				hover_row.get_style_context ().remove_class ("drag-hover-top");
			} else {
				if (up_down)
					to = h_index;
				else
					to = h_index +1;
				hover_row.get_style_context ().remove_class ("drag-hover-bottom");
			}

			if (from != to) {
				/*
				remove (row);
				insert (row, to);
				*/

				var list_row = (ListRow)model.get_item(from);
				model.remove(from);
				//if (from < to)
				//	  to -= 1;
				model.insert(to, list_row);

				row_reorder(from, to);
			}
		}
		drag_row = null;
	}
}

public class ListBoxRowDnD: ListBoxRow
{
	public signal void switch_changed(bool state);

	public string title {get;set;}

	public Button btn_up;
	public Button btn_down;
	public Button menu_btn_up;
	public Button menu_btn_down;

	public void enable_up(bool flag) {
		menu_btn_up.sensitive = flag;
		btn_up.sensitive = flag;
	}

	public void enable_down(bool flag) {
		menu_btn_down.sensitive = flag;
		btn_down.sensitive = flag;
	}

	public ListBoxRowDnD(string title, bool switch_state) {
		this.title = title;

		var box = new Box (Orientation.HORIZONTAL, 10);
		box.margin_start = 10;
		box.margin_end = 10;

		var handle = new EventBox ();
		handle.set_name("eventBox"+title);
		var image = new Image.from_icon_name ("list-drag-handle-symbolic", IconSize.MENU);
		handle.add (image);
		box.pack_start (handle, false);

		var label = new Gtk.Label (title);
		box.pack_start (label, true);

		var hbox =	new Box (Orientation.VERTICAL, 0);

		btn_up = new Button ();
		btn_up.set_relief(ReliefStyle.NONE);
		btn_up.get_style_context().add_class("flat");

		btn_down = new Button ();
		btn_down.set_relief(ReliefStyle.NONE);
		btn_down.get_style_context().add_class("flat");

		var arrow_up = new Arrow (ArrowType.UP, ShadowType.NONE);
		var arrow_down = new Arrow (ArrowType.DOWN, ShadowType.NONE);

		btn_up.add (arrow_up);
		btn_down.add (arrow_down);

		btn_up.clicked.connect (() => {
			up();
		});
		btn_down.clicked.connect (() => {
			down();
		});

		hbox.pack_start (btn_up, true, true, 0);
		hbox.pack_start (btn_down, true, true, 0);
		box.pack_end (hbox, false, false);

		var menu_btn = new MenuButton();
		menu_btn.set_relief (Gtk.ReliefStyle.NONE);
		menu_btn.add(new Image.from_icon_name ("view-more-symbolic", IconSize.BUTTON));
		menu_btn.use_popover = true;
		menu_btn.set_relief (ReliefStyle.NONE);
		menu_btn.set_tooltip_text ("More options");
		box.pack_end(menu_btn, false, false);

		var pop = new Popover (menu_btn);
		pop.set_border_width (6);
		pop.set_relative_to (menu_btn);

		var v = new Box (Orientation.VERTICAL, 6);
		v.margin = 6;

		menu_btn_up = new Button.with_label ("Up");
		menu_btn_up.relief = ReliefStyle.NONE;
		v.pack_start (menu_btn_up, false, false, 0);

		menu_btn_down = new Button.with_label ("Down");
		menu_btn_down.relief = ReliefStyle.NONE;
		v.pack_start (menu_btn_down, false, false, 0);

		v.show_all();

		pop.add (v);

		menu_btn_up.clicked.connect (() => {
			up();
		});
		menu_btn_down.clicked.connect (() => {
			down();
		});
		menu_btn.set_popover (pop);

		var switch_visible = new Gtk.Switch();
		switch_visible.active = switch_state;
		switch_visible.vexpand = false;
		switch_visible.valign = Align.CENTER;

		switch_visible.state_set.connect ((state) => {
			switch_changed(switch_visible.active);
			return false;
		});
		box.pack_end (switch_visible, false, false);

		var spin = new SpinButton.with_range(0, 1, 1);
		//box.pack_end (spin, false, false);
		add (box);

		drag_source_set (
			handle, Gdk.ModifierType.BUTTON1_MASK, entries, Gdk.DragAction.MOVE
		);
		handle.drag_begin.connect (row_drag_begin);
		handle.drag_data_get.connect (row_drag_data_get);

		show_all();
	}

	private void up() {
		move(-1);
	}

	private void down() {
		move(1);
	}

	private void move(int offset) {
		var from = get_index();
		DragListBox listbox = get_parent() as DragListBox;
		listbox.remove(this);
		listbox.insert(this, from + offset);
		listbox.row_reorder(from, from + offset);
	}
	void row_drag_begin (Widget widget, Gdk.DragContext context) {
		Allocation alloc;
		get_allocation (out alloc);
		var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
		var cr = new Cairo.Context (surface);

		var parent = get_parent () as DragListBox;
		if (parent != null) {
			parent.drag_row = this;
		}

		get_style_context ().add_class ("drag-icon");
		draw (cr);
		get_style_context ().remove_class ("drag-icon");

		int x, y;
		widget.translate_coordinates (this, 0, 0, out x, out y);
		surface.set_device_offset (-x-7, -y-10);
		drag_set_icon_surface (context, surface);
	}

	void row_drag_data_get (
		Widget widget, Gdk.DragContext context, SelectionData selection_data,
		uint info, uint time) {
		uchar[] data = new uchar[(sizeof (Widget))];
		((Widget[])data)[0] = widget;
		selection_data.set (
			Gdk.Atom.intern_static_string ("GTK_LIST_BOX_ROW"), 32, data
		);
	}
}
}

// ex: ts=4 noet
