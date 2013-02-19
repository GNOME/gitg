namespace Egg {
    [CCode (cheader_filename = "egg-flow-box.h", type_id = "egg_flow_box_get_type")]
    public class FlowBox : Gtk.Container, Gtk.Orientable {
		[CCode (has_construct_function = false)]
		public FlowBox ();

        public GLib.List<unowned Gtk.Widget> get_selected_children ();
        public void selected_foreach (Egg.FlowBoxForeachFunc func);
        public void set_adjustment (Gtk.Adjustment adjustment);

        public bool get_homogenous ();
        public void set_homogenous (bool homogenous);
        public Gtk.Align get_halign_policy ();
        public void set_halign_policy (Gtk.Align halign_policy);
        public Gtk.Align get_valign_policy ();
        public void set_valign_policy (Gtk.Align valign_policy);
        public uint get_row_spacing ();
        public void set_row_spacing (uint row_spacing);
        public void get_column_spacing ();
        public void set_column_spacing (uint column_spacing);
        public uint get_min_children_per_line ();
        public void set_min_children_per_line (uint min_children_per_line);
        public uint get_max_children_per_line ();
        public void set_max_children_per_line (uint max_children_per_line);
        public bool get_activate_on_single_click ();
        public void set_activate_on_single_click (bool activate_on_single_click);
        public Gtk.SelectionMode get_selection_mode ();
        public void set_selection_mode (Gtk.SelectionMode selection_mode);

        public virtual signal void child_Activated (Gtk.Widget child);
        public virtual signal void selected_children_changed ();
        public virtual signal void activate_cursor_child ();
        public virtual signal void toggle_cursor_child ();
        public virtual signal void move_cursor (Gtk.MovementStep step, int count);

        public bool homogenous { get; set; }
        public Gtk.Align haligh_policy { get; set; }
        public Gtk.Align valign_policy { get; set; }
        public uint row_spacing { get; set; }
        public uint column_spacing { get; set; }
        public uint min_children_per_line { get; set; }
        public uint max_children_per_line { get; set; }
        public bool activate_on_single_click { get; set; }
        public Gtk.SelectionMode selection_mode { get; set; }
    }

    public delegate void FlowBoxForeachFunc (Egg.FlowBox flow_box, Gtk.Widget child);
}
