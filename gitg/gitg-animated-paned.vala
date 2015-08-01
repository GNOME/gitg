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

public enum SlideDirection
{
	IN,
	OUT
}

public enum SlidePanedChild
{
	FIRST,
	SECOND
}

public class AnimatedPaned : Gtk.Paned
{
	private int d_target_pos;
	private int d_original_pos;
	private int d_start_pos;
	private int64 d_slide_start;
	private int64 d_slide_duration;
	private uint d_tick_id;
	private SourceFunc? d_async_callback;
	private SlideDirection d_direction;
	private SlidePanedChild d_child;

	public uint transition_duration
	{
		get;
		construct set;
		default = 250;
	}

	private bool update_position(double factor)
	{
		var pos = (int)Math.round((d_target_pos - d_start_pos) * factor) + d_start_pos;

		set_position(pos);
		queue_draw();

		if (pos == d_target_pos)
		{
			d_tick_id = 0;

			if (d_async_callback != null)
			{
				d_async_callback();
			}

			if (d_direction == SlideDirection.OUT)
			{
				if (d_child == SlidePanedChild.FIRST)
				{
					get_child1().hide();
				}
				else
				{
					get_child2().hide();
				}
			}

			return false;
		}

		return true;
	}

	private bool on_animate_step(Gtk.Widget widget, Gdk.FrameClock clock)
	{
		var elapsed = (clock.get_frame_time() - d_slide_start);
		var factor = (double)elapsed / (double)d_slide_duration;

		if (!update_position(Math.fmin(factor, 1)))
		{
			d_tick_id = 0;
			notify_property("is-animating");
			return false;
		}

		return true;
	}

	public override void dispose()
	{
		if (d_tick_id != 0)
		{
			remove_tick_callback(d_tick_id);
			d_tick_id = 0;
		}

		base.dispose();
	}

	public bool is_animating
	{
		get { return d_tick_id != 0; }
	}

	public void slide(SlidePanedChild child,
	                  SlideDirection  direction)
	{
		slide_async.begin(child, direction, (obj, res) => {
			slide_async.end(res);
		});
	}

	private async void slide_async(SlidePanedChild child,
	                               SlideDirection  direction)
	{
		var should_animate = get_settings().gtk_enable_animations;

		if (d_tick_id == 0)
		{
			if (direction == SlideDirection.OUT)
			{
				d_original_pos = get_position();
			}

			if (should_animate)
			{
				d_tick_id = add_tick_callback(on_animate_step);
				notify_property("is-animating");
			}
		}
		else if (d_tick_id != 0 && !should_animate)
		{
			remove_tick_callback(d_tick_id);
			d_tick_id = 0;
			notify_property("is-animating");
		}

		d_slide_start = get_frame_clock().get_frame_time();
		d_start_pos = get_position();
		d_direction = direction;
		d_child = child;

		double factor;
		int w;

		if (orientation == Gtk.Orientation.VERTICAL)
		{
			w = get_allocated_height();
		}
		else
		{
			w = get_allocated_width();
		}

		if (direction == SlideDirection.OUT)
		{
			if (child == SlidePanedChild.FIRST)
			{
				d_target_pos = 0;
			}
			else
			{
				d_target_pos = w;
			}

			factor = ((double)d_target_pos - (double)d_start_pos) /
			         ((double)d_target_pos - (double)d_original_pos);
		}
		else
		{
			d_target_pos = d_original_pos;

			double div;

			if (child == SlidePanedChild.FIRST)
			{
				div = d_original_pos;
				get_child1().show();
			}
			else
			{
				div = d_original_pos - w;
				get_child2().show();
			}

			factor = ((double)d_target_pos - (double)d_start_pos) / div;
		}

		d_async_callback = slide_async.callback;

		if (should_animate)
		{
			d_slide_duration = (int64)(factor * transition_duration) * 1000;
		}
		else
		{
			Idle.add(() => {
				update_position(1);
				return false;
			});
		}

		yield;
	}
}

}

// vi: ts=4 noet
