public class Gitg.LinkMap:Gtk.DrawingArea {

	public Gtk.SourceView left_sourceview { get; set; }
	public Gtk.SourceView right_sourceview { get; set; }

	private List<weak DiffModel> d_diff_model_list = null;

	public LinkMap () {
		Object ();
      reset ();
	}

   public void reset () {
      d_diff_model_list.foreach((model) => {
         model.removed();
      });
   }

   public void add (DiffModel model) {
      d_diff_model_list.append(model);
      listen_model_remove (model);
   }

   private void listen_model_remove (DiffModel model) {
      model.removed.connect(() => {
         d_diff_model_list.remove(model);
         queue_draw();
      });
   }

	public override bool draw (Cairo.Context context) {
		if (d_diff_model_list != null && d_diff_model_list.length () > 0) {
			Gtk.Allocation ? left_rectangle = null;
			Gtk.Allocation ? right_rectangle = null;

			left_sourceview.get_allocation (out left_rectangle);
			right_sourceview.get_allocation (out right_rectangle);

			//int[] pix_start = { left_rectangle.y, right_rectangle.y };
			int dxl = 0, dyl = 0;
			left_sourceview.translate_coordinates (get_toplevel (), 0, 0, out dxl, out dyl);
			int dxr = 0, dyr = 0;
			right_sourceview.translate_coordinates (get_toplevel (), 0, 0, out dxr, out dyr);
			int[] y_offset = { dyl + 1, dyr + 1 };

			var clip_y = array_get_min (y_offset) - 1;

			int[] heights = { left_rectangle.height, right_rectangle.height };
			var clip_height = array_get_max (heights) + 2;

			Gtk.Allocation ? allocation = null;
			get_allocation (out allocation);

			weak Gtk.StyleContext style_context = get_style_context ();
			style_context.render_background (context, 0, clip_y, allocation.width, clip_height);
			context.set_line_width (1.0);

			int height = get_allocated_height ();
			/*
			int[] visible = {
				get_line_num_for_y (left_sourceview, pix_start[0]),
				get_line_num_for_y (left_sourceview, pix_start[0] + height),
				get_line_num_for_y (right_sourceview, pix_start[1]),
				get_line_num_for_y (right_sourceview, pix_start[1] + height),
			};
			*/

			int wtotal = get_allocated_width ();

			// For bezier control points
			double[] x_steps = { -0.5, wtotal / 2, wtotal / 2, wtotal + 0.5 };

			double q_rad = GLib.Math.PI / 2;

			// left, right = self.view_indices

			var RADIUS = 3;

			d_diff_model_list.foreach ((model) => {

            int f0, t0, f1, t1;

            if (model.direction == DiffModel.Direction.RTL) {

                f0 = model.t0;
                t0 = model.f0;
                f1 = model.t1;
                t1 = model.f1;
            }

            else {

                f0 = model.f0;
				t0 = model.t0;
				f1 = model.f1;
				t1 = model.t1;
            }
				f1 = f1 == f0 ? f1 : f1 - 1;
				t1 = t1 == t0 ? t1 : t1 - 1;

				if ((t0 < 0 && t1 < 0) || (t0 > height && t1 > height)) {
					if (f0 == f1)
						return;
					context.arc (x_steps[0], f0 - 0.5 + RADIUS, RADIUS, -q_rad, 0);
					context.arc (x_steps[0], f1 - 0.5 - RADIUS, RADIUS, 0, q_rad);
					context.close_path ();

				} else if ((f0 < 0 && f1 < 0) || (f0 > height && f1 > height)) {
					if (t0 == t1)
						return;
					context.arc_negative (x_steps[3], t0 - 0.5 + RADIUS, RADIUS,-q_rad, q_rad * 2);
					context.arc_negative (x_steps[3], t1 - 0.5 - RADIUS, RADIUS,q_rad * 2, q_rad);
					context.close_path ();
				} else {
					context.move_to (x_steps[0], f0 - 0.5);
					context.curve_to (x_steps[1], f0 - 0.5,x_steps[2], t0 - 0.5,x_steps[3], t0 - 0.5);
					context.line_to (x_steps[3], t1 - 0.5);
					context.curve_to (x_steps[2], t1 - 0.5,x_steps[1], f1 - 0.5,x_steps[0], f1 - 0.5);
					context.close_path ();
				}

				// context.set_source_rgba(self.fill_colors[c[0]]);
				var color = Gdk.RGBA ();
				string color_str = null;
				if( model.direction == DiffModel.Direction.RTL) {
				    switch (model.diff_type) {
					    case DiffModel.DiffType.ADD:
					    color_str = "#ff0000";
					    break;
					    case DiffModel.DiffType.MODIFIED:
					    color_str = "#1d59d6";
					    break;
					    case DiffModel.DiffType.REMOVED:
					    color_str = "#008800";
					    break;
				}
				}
				else {
				    switch (model.diff_type) {
					    case DiffModel.DiffType.ADD:
					    color_str = "#008800";
					    break;
					    case DiffModel.DiffType.MODIFIED:
					    color_str = "#1d59d6";
					    break;
					    case DiffModel.DiffType.REMOVED:
					    color_str = "#ff0000";
					    break;
				}
				}
				color.parse (color_str);

				context.set_source_rgba (color.red, color.green, color.blue, color.alpha);
				context.fill_preserve ();

				// var chunk_idx = self.filediff.linediffer.locate_chunk(left, c[1])[0]
				// if chunk_idx == self.filediff.cursor.chunk:
				//if (false) {
				//	// var highlight = self.fill_colors['current-chunk-highlight']
				//	context.set_source_rgba ( /*highlight*/ 0, 0, 0, 0);
				//	context.fill_preserve ();
				//}

				// context.set_source_rgba(self.line_colors[c[0]]);
				color_str = null;
				if( model.direction == DiffModel.Direction.RTL) {
				    switch (model.diff_type) {
					    case DiffModel.DiffType.ADD:
					    color_str = "#ff0000";
					    break;
					    case DiffModel.DiffType.MODIFIED:
					    color_str = "#1d59d6";
					    break;
					    case DiffModel.DiffType.REMOVED:
					    color_str = "#008800";
					    break;
				}
				}
				else {
				    switch (model.diff_type) {
					    case DiffModel.DiffType.ADD:
					    color_str = "#008800";
					    break;
					    case DiffModel.DiffType.MODIFIED:
					    color_str = "#1d59d6";
					    break;
					    case DiffModel.DiffType.REMOVED:
					    color_str = "#ff0000";
					    break;
				}
				}
				color.parse(color_str);

				context.set_source_rgba (color.red, color.green, color.blue, color.alpha);
				context.stroke ();

			});

			return true;
		}
		return false;

	}

/*
	int view_offset_line (Gtk.SourceView source_view, int line_num, int pix_start, int y_offset) {
		int line_start = get_y_for_line_num (source_view, line_num);
		return line_start - pix_start + y_offset;
	}

	int get_y_for_line_num (Gtk.SourceView source_view, int line) {
		var buf = source_view.get_buffer ();
		Gtk.TextIter it;
		buf.get_iter_at_line (out it, line);
		int y, h;
		source_view.get_line_yrange (it, out y, out h);
		if (line >= buf.get_line_count ())
			return y + h;
		return y;
	}

	int get_line_num_for_y (Gtk.SourceView source_view, int y) {
		int line_start;
		source_view.get_line_at_y (null, y, out line_start);
		return line_start;
	}
*/

	int array_get_max (int[] array) {
		int max = array[0];
		for (int i = 0; i < array.length; i++)
			if (array[i] > max)
				max = array[i];
		return max;
	}

	int array_get_min (int[] array) {
		int min = array[0];
		for (int i = 0; i < array.length; i++)
			if (array[i] < min)
				min = array[i];
		return min;
	}
}
