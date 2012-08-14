/* -*- Mode: vala; indent-tabs-mode: t; c-basic-offset: 2; tab-width: 8 -*- */
/*
 * Copyright (C) 2011 Alexander Larsson <alexl@redhat.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

public class Egg.ListBox : Container {
  public delegate bool FilterFunc (Widget child);
  public delegate void UpdateSeparatorFunc (ref Widget? separator, Widget child, Widget? before);

  private class ChildInfo {
    public Widget widget;
    public Widget? separator;
    public SequenceIter<ChildInfo> iter;
    public int y;
    public int height;

    public ChildInfo (Widget widget) {
      this.widget = widget;
    }
  }

  private Sequence<ChildInfo> children;
  private HashTable<unowned Widget, unowned ChildInfo> child_hash;
  private HashTable<unowned Widget, unowned ChildInfo> separator_hash;
  private CompareDataFunc<Widget>? sort_func;
  private FilterFunc? filter_func;
  private UpdateSeparatorFunc? update_separator_func;
  private unowned ChildInfo selected_child;
  private unowned ChildInfo prelight_child;
  private unowned ChildInfo cursor_child;
  bool active_child_active;
  private unowned ChildInfo active_child;
  private SelectionMode selection_mode;
  private Adjustment? adjustment;
  private bool activate_single_click;

  /* DnD */
  private Widget drag_highlighted_widget;
  private uint auto_scroll_timeout_id;

  construct {
    set_can_focus (true);
    set_has_window (true);
    set_redraw_on_allocate (true);

    selection_mode = SelectionMode.SINGLE;
    activate_single_click = true;

    children = new Sequence<ChildInfo>();
    child_hash = new HashTable<unowned Widget, unowned ChildInfo> (GLib.direct_hash, GLib.direct_equal);
    separator_hash = new HashTable<unowned Widget, unowned ChildInfo> (GLib.direct_hash, GLib.direct_equal);
  }

  ~ListBox (){
    if (auto_scroll_timeout_id != 0)
      Source.remove (auto_scroll_timeout_id);
  }

  public unowned Widget? get_selected_child (){
    if (selected_child != null)
      return selected_child.widget;

    return null;
  }

  public unowned Widget? get_child_at_y (int y){
      unowned ChildInfo? child = find_child_at_y (y);

      if (child == null)
        return null;

      return child.widget;
  }

  public void select_child (Widget? child) {
    unowned ChildInfo? info = null;
    if (child != null)
      info = lookup_info (child);
    update_selected (info);
  }

  public virtual signal void child_selected (Widget? child) {
  }

  public virtual signal void child_activated (Widget? child) {
  }

  public void set_adjustment (Adjustment? adjustment) {
    this.adjustment = adjustment;
    this.set_focus_vadjustment (adjustment);
  }

  public void add_to_scrolled (ScrolledWindow scrolled) {
    scrolled.add_with_viewport (this);
    this.set_adjustment (scrolled.get_vadjustment ());
  }

  public void set_selection_mode (SelectionMode mode) {
    if (mode == SelectionMode.MULTIPLE) {
      warning ("Multiple selections not supported");
      return;
    }
    selection_mode = mode;
    if (mode == SelectionMode.NONE)
      update_selected (null);
  }

  public void set_filter_func (owned FilterFunc? f) {
    filter_func = (owned)f;
    refilter ();
  }

  public void set_separator_funcs (owned UpdateSeparatorFunc? update_separator) {
    update_separator_func = (owned)update_separator;
    reseparate ();
  }

  public void refilter () {
    apply_filter_all ();
    reseparate ();
    queue_resize ();
  }

  public void resort () {
    children.sort (do_sort);
    reseparate ();
    queue_resize ();
  }

  public void reseparate () {
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      update_separator (iter);
    }
    queue_resize ();
  }

  public void set_sort_func (owned CompareDataFunc<Widget>? f) {
    sort_func = (owned)f;
    resort ();
  }

  public void child_changed (Widget widget) {
    unowned ChildInfo? info = lookup_info (widget);
    if (info == null)
      return;

    var prev_next = get_next_visible (info.iter);

    if (sort_func != null) {
      children.sort_changed (info.iter, do_sort);
      this.queue_resize ();
    }
    apply_filter (info.widget);
    if (this.get_visible ()) {
      update_separator (info.iter);
      update_separator (get_next_visible (info.iter));
      update_separator (prev_next);
    }

  }

  public void set_activate_on_single_click (bool single) {
    activate_single_click = single;
  }

  /****** Implementation ***********/

  private int do_sort (ChildInfo a, ChildInfo b) {
    return sort_func (a.widget, b.widget);
  }

  [Signal (action=true)]
  public virtual signal void activate_cursor_child () {
    select_and_activate (cursor_child);
  }

  [Signal (action=true)]
  public virtual signal void toggle_cursor_child () {
    if (cursor_child == null)
      return;

    if (selection_mode == SelectionMode.SINGLE &&
	selected_child == cursor_child)
      update_selected (null);
    else
      select_and_activate (cursor_child);
  }

  [Signal (action=true)]
  public virtual signal void move_cursor (MovementStep step, int count) {
    Gdk.ModifierType state;

    bool modify_selection_pressed = false;

    if (Gtk.get_current_event_state (out state)) {
      var modify_mod_mask =  this.get_modifier_mask (Gdk.ModifierIntent.MODIFY_SELECTION);
      if ((state & modify_mod_mask) == modify_mod_mask)
	modify_selection_pressed = true;
    }

    ChildInfo? child = null;
    switch (step) {
    case MovementStep.BUFFER_ENDS:
      if (count < 0)
	child = get_first_visible ();
      else
	child = get_last_visible ();
      break;
    case MovementStep.DISPLAY_LINES:
      if (cursor_child != null) {
	SequenceIter<ChildInfo>? iter = cursor_child.iter;

	while (count < 0 && iter != null) {
	  iter = get_previous_visible (iter);
	  count++;
	}
	while (count > 0 && iter != null) {
	  iter = get_next_visible (iter);
	  count--;
	}
	if (iter != null && !iter.is_end ()) {
	  child = iter.get ();
	}
      }
      break;
    case MovementStep.PAGES:
      int page_size = 100;
      if (adjustment != null)
	page_size = (int) adjustment.get_page_increment ();

      if (cursor_child != null) {
	int start_y = cursor_child.y;
	int end_y = start_y;
	SequenceIter<ChildInfo>? iter = cursor_child.iter;

	child = cursor_child;
	if (count < 0) {
	  /* Up */

	  while (iter != null && !iter.is_begin ()) {
	    iter = get_previous_visible (iter);
	    if (iter == null)
	      break;
	    ChildInfo prev = iter.get ();
	    if (prev.y < start_y - page_size)
	      break;
	    child = prev;
	  }
	} else {
	  /* Down */

	  while (iter != null && !iter.is_end ()) {
	    iter = get_next_visible (iter);
	    if (iter.is_end ())
	      break;
	    ChildInfo next = iter.get ();
	    if (next.y > start_y + page_size)
	      break;
	    child = next;
	  }
	}
	end_y = child.y;
	if (end_y != start_y && adjustment != null)
	  adjustment.value += end_y - start_y;

      }
      break;
    default:
      return;
    }

    if (child == null) {
      error_bell ();
      return;
    }

    update_cursor (child);
    if (!modify_selection_pressed)
      update_selected (child);
  }

  private static void add_move_binding (BindingSet binding_set, uint keyval, Gdk.ModifierType modmask,
					MovementStep step, int count) {
    BindingEntry.add_signal (binding_set, keyval, modmask,
			     "move-cursor", 2,
			     typeof (MovementStep), step,
			     typeof (int), count);

    if ((modmask & Gdk.ModifierType.CONTROL_MASK) == Gdk.ModifierType.CONTROL_MASK)
      return;

    BindingEntry.add_signal (binding_set, keyval, Gdk.ModifierType.CONTROL_MASK,
			     "move-cursor", 2,
			     typeof (MovementStep), step,
			     typeof (int), count);
  }

  [CCode (cname = "klass")]
  private static extern void *workaround_for_local_var_klass;
  static construct {
    unowned BindingSet binding_set = BindingSet.by_class (workaround_for_local_var_klass);

    add_move_binding (binding_set, Gdk.Key.Home, 0,
		      MovementStep.BUFFER_ENDS, -1);
    add_move_binding (binding_set, Gdk.Key.KP_Home, 0,
		      MovementStep.BUFFER_ENDS, -1);

    add_move_binding (binding_set, Gdk.Key.End, 0,
		      MovementStep.BUFFER_ENDS, 1);
    add_move_binding (binding_set, Gdk.Key.KP_End, 0,
		      MovementStep.BUFFER_ENDS, 1);

    add_move_binding (binding_set, Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK,
		      MovementStep.DISPLAY_LINES, -1);
    add_move_binding (binding_set, Gdk.Key.KP_Up, Gdk.ModifierType.CONTROL_MASK,
		      MovementStep.DISPLAY_LINES, -1);

    add_move_binding (binding_set, Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK,
		      MovementStep.DISPLAY_LINES, 1);
    add_move_binding (binding_set, Gdk.Key.KP_Down, Gdk.ModifierType.CONTROL_MASK,
		      MovementStep.DISPLAY_LINES, 1);

    add_move_binding (binding_set, Gdk.Key.Page_Up, 0,
		      MovementStep.PAGES, -1);
    add_move_binding (binding_set, Gdk.Key.KP_Page_Up, 0,
		      MovementStep.PAGES, -1);

    add_move_binding (binding_set, Gdk.Key.Page_Down, 0,
		      MovementStep.PAGES, 1);
    add_move_binding (binding_set, Gdk.Key.KP_Page_Down, 0,
		      MovementStep.PAGES, 1);

    BindingEntry.add_signal (binding_set, Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK,
			     "toggle-cursor-child", 0);

    activate_signal = GLib.Signal.lookup ("activate-cursor-child", typeof (ListBox));
  }

  unowned ChildInfo? find_child_at_y (int y) {
    unowned ChildInfo? child_info = null;
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo info = iter.get ();
      if (y >= info.y && y < info.y + info.height) {
	child_info = info;
	break;
      }
    }
    return child_info;
  }

  private void update_cursor (ChildInfo? child) {
    cursor_child = child;
    this.grab_focus ();
    this.queue_draw ();
    if (child != null && adjustment != null) {
      Allocation allocation;
      this.get_allocation (out allocation);
      adjustment.clamp_page (cursor_child.y + allocation.y,
			     cursor_child.y + allocation.y + cursor_child.height);
    }
  }

  private void update_selected (ChildInfo? child) {
    if (child != selected_child &&
	(child == null || selection_mode != SelectionMode.NONE)) {
      selected_child = child;
      child_selected (selected_child != null ? selected_child.widget : null);
      queue_draw ();
    }
    if (child != null)
      update_cursor (child);
  }

  private void select_and_activate (ChildInfo? child) {
    unowned Widget? w = null;
    if (child != null)
      w = child.widget;
    update_selected (child);
    if (w != null)
      child_activated (w);
  }

  private void update_prelight (ChildInfo? child) {
    if (child != prelight_child) {
      prelight_child = child;
      queue_draw ();
    }
  }

  private void update_active (ChildInfo? child) {
    bool val = active_child == child;
    if (active_child != null && val != active_child_active) {
      active_child_active = val;
      queue_draw ();
    }
  }

  public override bool enter_notify_event (Gdk.EventCrossing event) {
    if (event.window != get_window ())
      return false;

    unowned ChildInfo? child = find_child_at_y ((int)event.y);
    update_prelight (child);
    update_active (child);

    return false;
  }

  public override bool leave_notify_event (Gdk.EventCrossing event) {
    if (event.window != get_window ())
      return false;

    unowned ChildInfo? child;
    if (event.detail != Gdk.NotifyType.INFERIOR) {
      child = null;
    } else {
      child = find_child_at_y ((int)event.y);
    }
    update_prelight (child);
    update_active (child);

    return false;
  }

  public override bool motion_notify_event (Gdk.EventMotion event) {
    unowned ChildInfo? child = find_child_at_y ((int)event.y);
    update_prelight (child);
    update_active (child);

    return false;
  }

  public override bool button_press_event (Gdk.EventButton event) {
    if (event.button == 1) {
      unowned ChildInfo? child = find_child_at_y ((int)event.y);
      if (child != null) {
        active_child = child;
        active_child_active = true;
        queue_draw ();

        if (event.type == Gdk.EventType.2BUTTON_PRESS &&
            !activate_single_click && child.widget != null)
          child_activated (child.widget);
      }

      /* TODO: Should mark as active while down, and handle grab breaks */
    }
    return false;
  }

  public override bool button_release_event (Gdk.EventButton event) {
    if (event.button == 1) {
      if (active_child != null && active_child_active)
        if (activate_single_click)
          select_and_activate (active_child);
        else
          update_selected (active_child);
      active_child = null;
      active_child_active = false;
      queue_draw ();
    }
    return false;
  }

  public override void show () {
    reseparate ();
    base.show ();
  }

  public override bool focus (DirectionType direction) {
    bool had_focus;
    bool focus_into;
    unowned Widget recurse_into = null;

    focus_into = true;
    had_focus = has_focus;

    unowned ChildInfo? current_focus_child = null;
    unowned ChildInfo? next_focus_child = null;

    if (had_focus) {
      /* If on row, going right, enter into possible container */
      if (direction == DirectionType.RIGHT || direction == DirectionType.TAB_FORWARD) {
        if (cursor_child != null)
          recurse_into = cursor_child.widget;
      }
      current_focus_child = cursor_child;
      /* Unless we're going up/down we're always leaving
      the container */
      if (direction != DirectionType.UP && direction != DirectionType.DOWN)
        focus_into = false;
    } else if (this.get_focus_child () != null) {
      /* There is a focus child, always navigat inside it first */
      recurse_into = this.get_focus_child ();
      current_focus_child = lookup_info (recurse_into);

      /* If exiting child container to the right, exit row */
      if (direction == DirectionType.RIGHT || direction == DirectionType.TAB_FORWARD)
        focus_into = false;

      /* If exiting child container to the left, select row or out */
      if (direction == DirectionType.LEFT || direction == DirectionType.TAB_BACKWARD) {
        next_focus_child = current_focus_child;
      }
    } else {
      /* If coming from the left, enter into possible container */
      if (direction == DirectionType.LEFT || direction == DirectionType.TAB_BACKWARD) {
        if (selected_child != null)
          recurse_into = selected_child.widget;
      }
    }

    if (recurse_into != null) {
      if (recurse_into.child_focus (direction))
        return true;
    }

    if (!focus_into)
      return false; // Focus is leaving us

    /* TODO: This doesn't handle up/down going into a focusable separator */

    if (next_focus_child == null) {
      if (current_focus_child != null) {
        if (direction == DirectionType.UP) {
          var i = get_previous_visible (current_focus_child.iter);
          if (i != null)
            next_focus_child = i.get ();
        } else {
          var i = get_next_visible (current_focus_child.iter);
          if (!i.is_end ())
            next_focus_child = i.get ();
        }
      } else {
          switch (direction) {
            case DirectionType.DOWN:
            case DirectionType.TAB_FORWARD:
              next_focus_child = get_first_visible ();
              break;
            case DirectionType.UP:
            case DirectionType.TAB_BACKWARD:
              next_focus_child = get_last_visible ();
              break;
            default:
              next_focus_child = selected_child;
              if (next_focus_child == null)
                next_focus_child = get_first_visible ();
              break;
           }
      }
    }

    if (next_focus_child == null) {
      if (direction == DirectionType.UP || direction == DirectionType.DOWN) {
        error_bell ();
        return true;
      }

      return false;
    }

    bool modify_selection_pressed = false;
    Gdk.ModifierType state;

    if (Gtk.get_current_event_state (out state)) {
      var modify_mod_mask =  this.get_modifier_mask (Gdk.ModifierIntent.MODIFY_SELECTION);
      if ((state & modify_mod_mask) == modify_mod_mask)
        modify_selection_pressed = true;
    }

    update_cursor (next_focus_child);
    if (!modify_selection_pressed)
      update_selected (next_focus_child);

    return true;
  }

  private struct ChildFlags {
    unowned ChildInfo child;
    StateFlags state;

    public static ChildFlags *find_or_add (ref ChildFlags[] array, ChildInfo to_find) {
      for (int i = 0; i < array.length; i++) {
	if (array[i].child == to_find)
	  return &array[i];
      }
      array.resize (array.length+1);
      array[array.length-1].child = to_find;
      array[array.length-1].state = 0;
      return &array[array.length-1];
    }
  }

  public override bool draw (Cairo.Context cr) {
    Allocation allocation;
    this.get_allocation (out allocation);

    unowned StyleContext context = this.get_style_context ();

    context.render_background (cr,
			       0, 0, allocation.width, allocation.height);

    ChildFlags[] flags = {};

    if (selected_child != null) {
      var found = ChildFlags.find_or_add (ref flags, selected_child);
      found.state |= StateFlags.SELECTED;
    }

    if (prelight_child != null) {
      var found = ChildFlags.find_or_add (ref flags, prelight_child);
      found.state |= StateFlags.PRELIGHT;
    }

    if (active_child != null && active_child_active) {
      var found = ChildFlags.find_or_add (ref flags, active_child);
      found.state |= StateFlags.ACTIVE;
    }

    foreach (unowned ChildFlags? flag in flags) {
      context.save ();
      context.set_state (flag.state);
      context.render_background (cr,
				 0, flag.child.y,
				 allocation.width, flag.child.height);
      context.restore ();
    }

    if (has_visible_focus() && cursor_child != null) {
      context.render_focus (cr, 0, cursor_child.y,
			    allocation.width, cursor_child.height);
    }

    base.draw (cr);

    return true;
  }

  public override void realize () {
    Allocation allocation;
    get_allocation (out allocation);
    set_realized (true);

    Gdk.WindowAttr attributes = { };
    attributes.x = allocation.x;
    attributes.y = allocation.y;
    attributes.width = allocation.width;
    attributes.height = allocation.height;
    attributes.window_type = Gdk.WindowType.CHILD;
    attributes.event_mask = this.get_events () |
		       Gdk.EventMask.ENTER_NOTIFY_MASK |
		       Gdk.EventMask.LEAVE_NOTIFY_MASK |
		       Gdk.EventMask.POINTER_MOTION_MASK |
		       Gdk.EventMask.EXPOSURE_MASK |
		       Gdk.EventMask.BUTTON_PRESS_MASK |
		       Gdk.EventMask.BUTTON_RELEASE_MASK;

    attributes.wclass = Gdk.WindowWindowClass.INPUT_OUTPUT;
    var window = new Gdk.Window (get_parent_window (), attributes,
				 Gdk.WindowAttributesType.X |
				 Gdk.WindowAttributesType.Y);
    this.get_style_context ().set_background (window);
    window.set_user_data (this);
    this.set_window (window);
  }

  private void apply_filter (Widget child) {
    bool do_show = true;
    if (filter_func != null)
      do_show = filter_func (child);
    child.set_child_visible (do_show);
  }

  private void apply_filter_all () {
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo child_info = iter.get ();
      apply_filter (child_info.widget);
    }
  }

  private unowned ChildInfo? get_first_visible () {
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      if (widget.get_visible () && widget.get_child_visible ())
	return child_info;
    }
    return null;
  }

  private unowned ChildInfo? get_last_visible () {
    var iter = children.get_end_iter ();
    while (!iter.is_begin ()) {
      iter = iter.prev ();
      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      if (widget.get_visible () && widget.get_child_visible ())
	return child_info;
    }
    return null;
  }

  private SequenceIter<ChildInfo>? get_previous_visible (SequenceIter<ChildInfo> _iter) {
    if (_iter.is_begin())
      return null;
    var iter = _iter;

    do {
      iter = iter.prev ();

      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      if (widget.get_visible () && widget.get_child_visible ())
	return iter;
    } while (!iter.is_begin ());

    return null;
  }

  private SequenceIter<ChildInfo>? get_next_visible (SequenceIter<ChildInfo> _iter) {
    if (_iter.is_end())
      return _iter;

    var iter = _iter;
    do {
      iter = iter.next ();

      if (!iter.is_end ()) {
	unowned ChildInfo child_info = iter.get ();
	unowned Widget widget = child_info.widget;
	if (widget.get_visible () && widget.get_child_visible ())
	  return iter;
      }
    } while (!iter.is_end ());

    return iter;
  }

  private void update_separator (SequenceIter<ChildInfo>? iter) {
    if (iter == null || iter.is_end ())
      return;

    unowned ChildInfo info = iter.get ();
    var before_iter = get_previous_visible (iter);
    var widget = info.widget;
    Widget? before_widget = null;
    if (before_iter != null) {
      unowned ChildInfo before_info = before_iter.get ();
      before_widget = before_info.widget;
    }

    if (update_separator_func != null &&
	widget.get_visible () &&
	widget.get_child_visible ()) {
      var old_separator = info.separator;
      update_separator_func (ref info.separator, widget, before_widget);
      if (old_separator != info.separator) {
	if (old_separator != null) {
	  old_separator.unparent ();
	  separator_hash.remove (old_separator);
	}
	if (info.separator != null) {
	  separator_hash.set (info.separator, info);
	  info.separator.set_parent (this);
	  info.separator.show ();
	}
	this.queue_resize ();
      }
    } else if (info.separator != null) {
      separator_hash.remove (info.separator);
      info.separator.unparent ();
      info.separator = null;
      this.queue_resize ();
    }
  }

  private unowned ChildInfo? lookup_info (Widget widget) {
    return child_hash.get (widget);
  }

  public override void add (Widget widget) {
    ChildInfo info = new ChildInfo (widget);
    SequenceIter<ChildInfo> iter;

    child_hash.set (widget, info);

    if (sort_func != null)
      iter = children.insert_sorted (info, do_sort);
    else
      iter = children.append (info);

    info.iter = iter;
    widget.set_parent (this);

    apply_filter (widget);

    if (this.get_visible ()) {
      update_separator (iter);
      update_separator (get_next_visible (iter));
    }

    widget.notify["visible"].connect (child_visibility_changed);
  }

  private void child_visibility_changed (Object object, ParamSpec pspec) {
    if (this.get_visible ()) {
      unowned ChildInfo? info = lookup_info (object as Widget);
      if (info != null) {
	update_separator (info.iter);
	update_separator (get_next_visible (info.iter));
      }
    }
  }

  public override void remove (Widget widget) {
    bool was_visible = widget.get_visible ();

    widget.notify["visible"].disconnect (child_visibility_changed);

    unowned ChildInfo? info = lookup_info (widget);
    if (info == null) {
      info = separator_hash.get (widget);
      if (info != null) {
	separator_hash.remove (widget);
	info.separator = null;
	widget.unparent ();
	if (was_visible && this.get_visible ())
	  this.queue_resize ();

      } else
	warning ("Tried to remove non-child %p\n", widget);
      return;
    }

    if (info.separator != null) {
      separator_hash.remove (info.separator);
      info.separator.unparent ();
      info.separator = null;
    }

    if (info == selected_child)
      update_selected (null);
    if (info == prelight_child)
      prelight_child = null;
    if (info == cursor_child)
      cursor_child = null;
    if (info == active_child)
      active_child = null;

    var next = get_next_visible (info.iter);

    widget.unparent ();

    child_hash.remove (widget);
    Sequence.remove (info.iter);

    if (this.get_visible ())
      update_separator (next);

    if (was_visible && this.get_visible ())
      this.queue_resize ();
  }

  public override void forall_internal (bool include_internals,
					Gtk.Callback callback) {
    var iter = children.get_begin_iter ();
    while (!iter.is_end ()) {
      unowned ChildInfo child_info = iter.get ();
      iter = iter.next();
      if (child_info.separator != null && include_internals)
	callback (child_info.separator);
      callback (child_info.widget);
    }
  }

  public override void compute_expand_internal (out bool hexpand, out bool vexpand) {
    base.compute_expand_internal (out hexpand, out vexpand);
    /* We don't expand vertically beyound the minimum size */
    vexpand = false;
  }

  public override Type child_type () {
    return typeof (Widget);
  }

  public override Gtk.SizeRequestMode get_request_mode () {
    return SizeRequestMode.HEIGHT_FOR_WIDTH;
  }

  public override void get_preferred_height (out int minimum_height, out int natural_height) {
    int natural_width;
    get_preferred_width_internal (null, out natural_width);
    get_preferred_height_for_width_internal (natural_width, out minimum_height, out natural_height);
  }

  public override void get_preferred_height_for_width (int width, out int minimum_height, out int natural_height) {
    minimum_height = 0;
    unowned StyleContext context = this.get_style_context ();
    int focus_width, focus_pad;
    context.get_style ("focus-line-width", out focus_width,
		       "focus-padding", out focus_pad);
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min;

      if (!widget.get_visible () || !widget.get_child_visible ())
	continue;

      if (child_info.separator != null) {
	child_info.separator.get_preferred_height_for_width (width, out child_min, null);
	minimum_height += child_min;
      }

      widget.get_preferred_height_for_width (width - 2 * (focus_width + focus_pad),
					     out child_min, null);
      minimum_height += child_min + 2 * (focus_width + focus_pad);
    }

    /* We always allocate the minimum height, since handling
       expanding rows is way too costly, and unlikely to
       be used, as lists are generally put inside a scrolling window
       anyway.
    */
    natural_height = minimum_height;
  }

  public override void get_preferred_width (out int minimum_width, out int natural_width) {
    unowned StyleContext context = this.get_style_context ();
    int focus_width, focus_pad;
    context.get_style ("focus-line-width", out focus_width,
		       "focus-padding", out focus_pad);
    minimum_width = 0;
    natural_width = 0;
    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min, child_nat;

      if (!widget.get_visible () || !widget.get_child_visible ())
	continue;

      widget.get_preferred_width (out child_min, out child_nat);
      minimum_width = int.max (minimum_width, child_min + 2 * (focus_width + focus_pad));
      natural_width = int.max (natural_width, child_nat + 2 * (focus_width + focus_pad));

      if (child_info.separator != null) {
	child_info.separator.get_preferred_width (out child_min, out child_nat);
	minimum_width = int.max (minimum_width, child_min);
	natural_width = int.max (natural_width, child_nat);
      }
    }
  }

  public override void get_preferred_width_for_height (int height, out int minimum_width, out int natural_width) {
    get_preferred_width_internal (out minimum_width, out natural_width);
  }

  public override void size_allocate (Gtk.Allocation allocation) {
    Allocation child_allocation = { 0, 0, 0, 0};
    Allocation separator_allocation = { 0, 0, 0, 0};

    set_allocation (allocation);

    var window = get_window();
    if (window != null)
      window.move_resize (allocation.x,
			  allocation.y,
			  allocation.width,
			  allocation.height);

    var context = this.get_style_context ();
    int focus_width, focus_pad;
    context.get_style ("focus-line-width", out focus_width,
		       "focus-padding", out focus_pad);

    child_allocation.x = 0 + focus_width + focus_pad;
    child_allocation.y = 0;
    child_allocation.width = allocation.width - 2 * (focus_width + focus_pad);

    separator_allocation.x = 0;
    separator_allocation.width = allocation.width;

    for (var iter = children.get_begin_iter (); !iter.is_end (); iter = iter.next ()) {
      unowned ChildInfo child_info = iter.get ();
      unowned Widget widget = child_info.widget;
      int child_min;

      if (!widget.get_visible () || !widget.get_child_visible ()) {
	child_info.y = child_allocation.y;
	child_info.height = 0;
	continue;
      }

      if (child_info.separator != null) {
	child_info.separator.get_preferred_height_for_width (allocation.width, out child_min, null);
	separator_allocation.height = child_min;
	separator_allocation.y = child_allocation.y;

	child_info.separator.size_allocate (separator_allocation);

	child_allocation.y += child_min;
      }

      child_info.y = child_allocation.y;
      child_allocation.y += focus_width + focus_pad;

      widget.get_preferred_height_for_width (child_allocation.width, out child_min, null);
      child_allocation.height = child_min;

      child_info.height = child_allocation.height + 2 * (focus_width + focus_pad);
      widget.size_allocate (child_allocation);

      child_allocation.y += child_min + focus_width + focus_pad;
    }
  }

  /* DnD */

  public void drag_unhighlight_widget () {
    if (drag_highlighted_widget == null)
      return;

    Gtk.drag_unhighlight (drag_highlighted_widget);
    drag_highlighted_widget = null;
  }

  public void drag_highlight_widget (Widget widget) {
    if (drag_highlighted_widget == widget)
      return;

    drag_unhighlight_widget ();

    Gtk.drag_highlight (widget);
    drag_highlighted_widget = widget;
  }

  public override void drag_leave (Gdk.DragContext context, uint time_) {
    drag_unhighlight_widget ();

    if (auto_scroll_timeout_id != 0) {
      Source.remove (auto_scroll_timeout_id);
      auto_scroll_timeout_id = 0;
    }
  }

  public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time_) {
    /* Auto-scroll during Dnd if cursor is moving into the top/bottom portion of the
     * box. */
    if (auto_scroll_timeout_id != 0) {
      Source.remove (auto_scroll_timeout_id);
      auto_scroll_timeout_id = 0;
    }

    if (adjustment == null)
     return false;

    /* Part of the view triggering auto-scroll */
    double size = 30;
    int move = 0;

    if (y < adjustment.value + size) {
      /* Scroll up */
      move = -1;
    }
    else if (y > (adjustment.value + adjustment.page_size) - size) {
      /* Scroll down */
      move = 1;
    }

    if (move == 0)
      return false;

    auto_scroll_timeout_id = Timeout.add (150, () =>
      {
        adjustment.value += (adjustment.step_increment * move);

        return true;
      });

    return false;
  }
}
