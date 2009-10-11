#include "gitg-dnd.h"
#include "gitg-ref.h"
#include "gitg-cell-renderer-path.h"
#include "gitg-utils.h"

enum
{
	DRAG_TARGET_REF = 1
};

static GtkTargetEntry target_entries[] = {
	{"gitg-ref", GTK_TARGET_SAME_WIDGET, DRAG_TARGET_REF}
};

typedef struct
{
	GtkTreeView *tree_view;
	GitgRef *ref;
	GitgRef *target;
	GitgRef *cursor_ref;
	
	GitgDndCallback callback;
	gpointer callback_data;
	
	gdouble x;
	gdouble y;
	
	gboolean is_drag;
	GtkTargetList *target_list;
	
	guint scroll_timeout;
} GitgDndData;

#define GITG_DND_DATA_KEY "GitgDndDataKey"

#define GITG_DND_GET_DATA(widget) ((GitgDndData *)g_object_get_data(G_OBJECT(widget), GITG_DND_DATA_KEY))

static void
remove_scroll_timeout (GitgDndData *data)
{
	if (data->scroll_timeout != 0)
	{
		g_source_remove (data->scroll_timeout);
		data->scroll_timeout = 0;
	}
}


static GitgDndData *
gitg_dnd_data_new ()
{
	GitgDndData *data = g_slice_new0 (GitgDndData);
	
	data->target_list = gtk_target_list_new (target_entries,
	                                         G_N_ELEMENTS (target_entries));

	return data;
}

static void
gitg_dnd_data_free (GitgDndData *data)
{
	gtk_target_list_unref (data->target_list);
	remove_scroll_timeout (data);

	g_slice_free (GitgDndData, data);
}

static GitgRef *
get_ref_at_pos (GtkTreeView *tree_view, gint x, gint y, gint *hot_x, gint *hot_y, GitgCellRendererPath **renderer, GtkTreePath **tp)
{
	gint cell_x;
	gint cell_y;
	GtkTreePath *path;
	GtkTreeViewColumn *column;

	if (!gtk_tree_view_get_path_at_pos (tree_view,
	                                    x,
	                                    y,
	                                    &path,
	                                    &column,
	                                    &cell_x,
	                                    &cell_y))
	{
		return NULL;
	}
	
	if (hot_y)
	{
		*hot_y = cell_y;
	}
	
	GtkCellRenderer *cell = gitg_utils_find_cell_at_pos (tree_view, column, path, cell_x);
	
	if (!cell || !GITG_IS_CELL_RENDERER_PATH (cell))
	{
		return NULL;
	}
	
	if (renderer)
	{
		*renderer = GITG_CELL_RENDERER_PATH (cell);
	}
	
	GitgRef *ref = gitg_cell_renderer_path_get_ref_at_pos (GTK_WIDGET (tree_view),
	                                                       GITG_CELL_RENDERER_PATH (cell),
	                                                       cell_x,
	                                                       hot_x);

	if (tp)
	{
		*tp = path;
	}
	else
	{
		gtk_tree_path_free (path);
	}

	return ref;
}

static gboolean
can_drag (GitgRef *ref)
{
	GitgRefType type = gitg_ref_get_ref_type (ref);
	
	switch (type)
	{
		case GITG_REF_TYPE_BRANCH:
		case GITG_REF_TYPE_REMOTE:
		case GITG_REF_TYPE_STASH:
			return TRUE;
		break;
		default:
			return FALSE;
		break;
	}
}

static gboolean
can_drop (GitgRef *source, GitgRef *dest)
{
	if (gitg_ref_equal (source, dest))
	{
		return FALSE;
	}

	GitgRefType source_type = gitg_ref_get_ref_type (source);
	GitgRefType dest_type = gitg_ref_get_ref_type (dest);
	
	if (source_type == GITG_REF_TYPE_BRANCH)
	{
		return dest_type ==  GITG_REF_TYPE_BRANCH || dest_type == GITG_REF_TYPE_REMOTE;
	}
	else if (source_type == GITG_REF_TYPE_REMOTE)
	{
		return dest_type == GITG_REF_TYPE_BRANCH;
	}
	else if (source_type == GITG_REF_TYPE_STASH)
	{
		return dest_type == GITG_REF_TYPE_BRANCH;
	}
	
	return FALSE;
}

static void
begin_drag (GtkWidget   *widget,
            GdkEvent    *event,
            GitgDndData *data)
{

	GtkTreeView *tree_view = GTK_TREE_VIEW (widget);
	gint hot_x;
	gint hot_y;
	GitgCellRendererPath *cell;
	GitgRef *ref = get_ref_at_pos (tree_view, 
	                               (gint)data->x, 
	                               (gint)data->y, 
	                               &hot_x, 
	                               &hot_y,
	                               &cell,
	                               NULL);

	if (!ref || !can_drag (ref))
	{
		return;
	}
	
	data->ref = ref;
	gitg_ref_set_state (ref, GITG_REF_STATE_NONE);

	GdkDragContext *context = gtk_drag_begin (widget,
	                                          data->target_list,
	                                          GDK_ACTION_MOVE,
	                                          1,
	                                          event);

	guint minwidth;
	guint h;
	gdk_display_get_maximal_cursor_size (gtk_widget_get_display (widget), &minwidth, &h);

	GdkPixbuf *pixbuf = gitg_cell_renderer_path_render_ref (GTK_WIDGET (tree_view),
	                                                        cell,
	                                                        ref,
	                                                        minwidth + 1);

	if (pixbuf)
	{
		gtk_drag_set_icon_pixbuf (context, pixbuf, hot_x, hot_y);
		g_object_unref (pixbuf);
	}
	
}

static void
update_highlight (GitgDndData *data, gint x, gint y)
{
	GitgRef *ref = get_ref_at_pos (data->tree_view, 
	                               x, 
	                               y, 
	                               NULL,
	                               NULL,
	                               NULL,
	                               NULL);

	if (ref != data->cursor_ref)
	{
		if (data->cursor_ref)
		{
			gitg_ref_set_state (data->cursor_ref, GITG_REF_STATE_NONE);
		}
		
		if (ref && gitg_ref_get_ref_type (ref) != GITG_REF_TYPE_NONE)
		{
			gitg_ref_set_state (ref, GITG_REF_STATE_PRELIGHT);
			
			gdk_window_set_cursor (gtk_tree_view_get_bin_window (data->tree_view),
			                       gdk_cursor_new (GDK_HAND2));
		}
		else
		{
			gdk_window_set_cursor (gtk_tree_view_get_bin_window (data->tree_view),
			                       NULL);
		}
		
		data->cursor_ref = ref;
		gtk_widget_queue_draw (GTK_WIDGET (data->tree_view));
	}	
}

static gboolean
vertical_autoscroll (GitgDndData *data)
{
	GdkRectangle visible_rect;
	gint y;
	gint offset;
	gfloat value;

	gdk_window_get_pointer (gtk_tree_view_get_bin_window (data->tree_view), NULL, &y, NULL);
	gtk_tree_view_convert_bin_window_to_tree_coords (data->tree_view, 0, y, NULL, &y);

	gtk_tree_view_get_visible_rect (data->tree_view, &visible_rect);

	/* see if we are near the edge. */
	offset = y - (visible_rect.y + 2 * 15);

	if (offset > 0)
	{
		offset = y - (visible_rect.y + visible_rect.height - 2 * 15);
		
		if (offset < 0)
		{
			return TRUE;
		}
	}

	GtkAdjustment *adj = gtk_tree_view_get_vadjustment (data->tree_view);
	
	value = CLAMP (gtk_adjustment_get_value (adj) + offset, 0.0,
	               adj->upper - adj->page_size);

	gtk_adjustment_set_value (adj, value);	
	return TRUE;
}

static void
add_scroll_timeout (GitgDndData *data)
{
	if (data->scroll_timeout == 0)
    {
		data->scroll_timeout = g_timeout_add (50, 
		                                      (GSourceFunc)vertical_autoscroll, 
		                                      data);
    }
}


static gboolean
gitg_drag_source_event_cb (GtkWidget   *widget,
                           GdkEvent    *event,
                           GitgDndData *data)
{
	gboolean retval = FALSE;
	
	switch (event->type)
	{
		case GDK_BUTTON_PRESS:
			if (event->button.button == 1)
			{
				data->x = event->button.x;
				data->y = event->button.y;

				data->is_drag = TRUE;
				data->ref = NULL;
				data->target = NULL;
			}
		break;
		case GDK_BUTTON_RELEASE:
			if (event->button.button == 1)
			{
				data->is_drag = FALSE;
				
				if (data->target)
				{
					gitg_ref_set_state (data->target, GITG_REF_STATE_NONE);
				}
				
				remove_scroll_timeout (data);
			}
		break;
		case GDK_MOTION_NOTIFY:
			if (data->is_drag && (event->motion.state & GDK_BUTTON1_MASK))
			{
				if (gtk_drag_check_threshold (widget, data->x, data->y, event->motion.x, event->motion.y))
				{
					data->is_drag = FALSE;
					begin_drag (widget, event, data);

					retval = TRUE;
				}
			}
			else if (!data->is_drag && !(event->motion.state & GDK_BUTTON1_MASK))
			{
				update_highlight (data, (gint)event->motion.x, (gint)event->motion.y);
			}
		break;
		default:
		break;
	}
  
	return retval;
}

static gboolean
gitg_drag_source_motion_cb (GtkWidget       *widget,
                            GdkDragContext  *context,
                            gint             x,
                            gint             y,
                            guint            time,
                            GitgDndData     *data)
{
	if (!data->ref)
	{
		return FALSE;
	}
	
	GitgRef *ref;
	gint dx;
	gint dy;

	gtk_tree_view_convert_widget_to_bin_window_coords (data->tree_view,
	                                                   x,
	                                                   y,
	                                                   &dx,
	                                                   &dy);
	
	ref = get_ref_at_pos (GTK_TREE_VIEW (widget),
	                      dx,
	                      dy,
	                      NULL,
	                      NULL,
	                      NULL,
	                      NULL);

	gboolean ret = FALSE;

	if (ref != data->target)
	{
		if (data->target)
		{
			gitg_ref_set_state (data->target, GITG_REF_STATE_NONE);
			gtk_widget_queue_draw (widget);
		}
		
		if (data->callback)
		{
			data->callback (data->ref, ref, FALSE, data->callback_data);	
		}
	}
		
	if (ref && can_drop (data->ref, ref))
	{
		if (ref != data->target)
		{
			gitg_ref_set_state (ref, GITG_REF_STATE_SELECTED);
			data->target = ref;
			
			gtk_widget_queue_draw (widget);
		}
		
		gdk_drag_status (context, GDK_ACTION_MOVE, time);
		ret = TRUE;
	}
	else
	{
		if (data->target)
		{
			data->target = NULL;
			gtk_widget_queue_draw (widget);
		}
	}

	add_scroll_timeout (data);
	return ret;
}

static gboolean
gitg_drag_source_drop_cb (GtkWidget *widget,
                          GdkDragContext *context,
                          gint x,
                          gint y,
                          guint time,
                          GitgDndData *data)
{
	if (!data->ref || !data->target)
	{
		return FALSE;
	}

	gboolean ret = FALSE;
	
	if (data->callback)
	{
		ret = data->callback (data->ref, data->target, TRUE, data->callback_data);	
	}
	
	gtk_drag_finish (context, ret, FALSE, time);
	return ret;
}

static gboolean
gitg_drag_source_leave_cb (GtkWidget       *widget,
                           GdkDragContext  *context,
                           guint            time,
                           GitgDndData     *data)
{
	remove_scroll_timeout (data);
	return FALSE;
}

void 
gitg_dnd_enable (GtkTreeView *tree_view, GitgDndCallback callback, gpointer callback_data)
{
	if (GITG_DND_GET_DATA (tree_view))
	{
		return;
	}
	
	GitgDndData *data = gitg_dnd_data_new ();
	
	data->tree_view = tree_view;
	data->callback = callback;
	data->callback_data = callback_data;

	g_object_set_data_full (G_OBJECT (tree_view),
	                        GITG_DND_DATA_KEY,
	                        data,
	                        (GDestroyNotify)gitg_dnd_data_free);
	
	gtk_widget_add_events (GTK_WIDGET (tree_view), 
	                       gtk_widget_get_events (GTK_WIDGET (tree_view)) |
	                       GDK_BUTTON_PRESS_MASK | 
	                       GDK_BUTTON_RELEASE_MASK |
	                       GDK_BUTTON_MOTION_MASK);

	gtk_drag_dest_set (GTK_WIDGET (tree_view),
	                   0,
	                   target_entries,
	                   G_N_ELEMENTS (target_entries),
	                   GDK_ACTION_MOVE);
	                   
	g_signal_connect (tree_view, 
	                  "button-press-event",
	                  G_CALLBACK (gitg_drag_source_event_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "button-release-event",
	                  G_CALLBACK (gitg_drag_source_event_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "motion-notify-event",
	                  G_CALLBACK (gitg_drag_source_event_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "drag-motion",
	                  G_CALLBACK (gitg_drag_source_motion_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "drag-drop",
	                  G_CALLBACK (gitg_drag_source_drop_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "drag-leave",
	                  G_CALLBACK (gitg_drag_source_leave_cb),
	                  data);
}

void
gitg_dnd_disable (GtkTreeView *tree_view)
{
	GitgDndData *data = GITG_DND_GET_DATA (tree_view);
	
	if (data)
	{
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_event_cb, data);
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_motion_cb, data);
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_drop_cb, data);
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_leave_cb, data);
		
		g_object_set_data (G_OBJECT (tree_view), GITG_DND_DATA_KEY, NULL);
	}
}
