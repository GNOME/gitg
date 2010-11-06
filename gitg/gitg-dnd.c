/*
 * gitg-dnd.h
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <gtk/gtk.h>

#include "gitg-dnd.h"
#include "gitg-cell-renderer-path.h"
#include "gitg-window.h"
#include "gitg-branch-actions.h"
#include "gseal-gtk-compat.h"
#include "gitg-utils.h"

#include <string.h>

enum
{
	DRAG_TARGET_REF = 1,
	DRAG_TARGET_TREEISH,
	DRAG_TARGET_REVISION,
	DRAG_TARGET_TEXT,
	DRAG_TARGET_URI,
	DRAG_TARGET_DIRECT_SAVE
};

#define XDS_ATOM   gdk_atom_intern  ("XdndDirectSave0", FALSE)
#define TEXT_ATOM  gdk_atom_intern  ("text/plain", FALSE)

#define MAX_XDS_ATOM_VAL_LEN 4096

static GtkTargetEntry target_dest_entries[] = {
	{"gitg-ref", GTK_TARGET_SAME_WIDGET, DRAG_TARGET_REF}
};

static GtkTargetEntry target_source_entries[] = {
	{"x-gitg/treeish-list", GTK_TARGET_OTHER_APP, DRAG_TARGET_TREEISH},
	{"XdndDirectSave0", GTK_TARGET_OTHER_APP, DRAG_TARGET_DIRECT_SAVE}
};

typedef struct
{
	GtkTreeView *tree_view;
	GitgRef *ref;
	GitgRef *target;
	GitgRef *cursor_ref;

	GitgDndCallback callback;
	GitgDndRevisionCallback revision_callback;
	gpointer callback_data;

	gdouble x;
	gdouble y;

	gboolean is_drag;
	GtkTargetList *target_list;
	GtkTargetList *revision_target_list;
	GitgRevision *revision;

	guint scroll_timeout;
	gchar *xds_destination;
	gchar *xds_filename;
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

	data->target_list = gtk_target_list_new (target_dest_entries,
	                                         G_N_ELEMENTS (target_dest_entries));

	data->revision_target_list = gtk_target_list_new (target_source_entries,
	                                                  G_N_ELEMENTS (target_source_entries));

	gtk_target_list_add_text_targets (data->revision_target_list, DRAG_TARGET_TEXT);
	gtk_target_list_add_uri_targets (data->revision_target_list, DRAG_TARGET_URI);

	return data;
}

static void
gitg_dnd_data_free (GitgDndData *data)
{
	gtk_target_list_unref (data->target_list);
	gtk_target_list_unref (data->revision_target_list);

	remove_scroll_timeout (data);

	g_slice_free (GitgDndData, data);
}

static GitgRef *
get_ref_at_pos (GtkTreeView           *tree_view,
                gint                   x,
                gint                   y,
                gint                  *hot_x,
                gint                  *hot_y,
                GitgCellRendererPath **renderer,
                GtkTreePath          **tp)
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

static GitgRevision *
get_revision_at_pos (GtkTreeView  *tree_view,
                     gint          x,
                     gint          y,
                     GtkTreePath **tp)
{
	gint cell_x;
	gint cell_y;
	GtkTreePath *path;
	GtkTreeViewColumn *column;
	GtkTreeModel *model;
	GtkTreeIter iter;
	GitgRevision *revision;

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

	model = gtk_tree_view_get_model (tree_view);

	if (!gtk_tree_model_get_iter (model, &iter, path))
	{
		return NULL;
	}

	gtk_tree_model_get (model, &iter, 0, &revision, -1);

	if (revision && tp)
	{
		*tp = path;
	}
	else
	{
		gtk_tree_path_free (path);
	}

	return revision;
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

/* Copied from gitg-label-renderer
 * TODO: refactor
 */
static inline guint8
convert_color_channel (guint8 src,
                       guint8 alpha)
{
	return alpha ? src / (alpha / 255.0) : 0;
}

static void
convert_bgra_to_rgba (guint8 const  *src,
                      guint8        *dst,
                      gint           width,
                      gint           height)
{
	guint8 const *src_pixel = src;
	guint8 * dst_pixel = dst;
	int y;

	for (y = 0; y < height; y++)
	{
		int x;

		for (x = 0; x < width; x++)
		{
			dst_pixel[0] = convert_color_channel (src_pixel[2],
							                      src_pixel[3]);
			dst_pixel[1] = convert_color_channel (src_pixel[1],
							                      src_pixel[3]);
			dst_pixel[2] = convert_color_channel (src_pixel[0],
							                      src_pixel[3]);
			dst_pixel[3] = src_pixel[3];

			dst_pixel += 4;
			src_pixel += 4;
		}
	}
}

static GdkPixbuf *
create_revision_drag_icon (GtkTreeView  *tree_view,
                           GitgRevision *revision)
{
	gchar const *subject = gitg_revision_get_subject (revision);
	gchar *sha1 = gitg_revision_get_sha1 (revision);

	/* Only take first 8 characters */
	sha1[8] = '\0';

	gchar *text = g_strdup_printf ("%s: %s", sha1, subject);

	PangoLayout *layout = gtk_widget_create_pango_layout (GTK_WIDGET (tree_view), text);
	gint width;
	gint height;

	pango_layout_get_pixel_size (layout, &width, &height);
	
	cairo_surface_t *surface = cairo_image_surface_create (CAIRO_FORMAT_ARGB32, width + 4, height + 4);
	cairo_t *context = cairo_create (surface);

	cairo_rectangle (context, 0, 0, width + 4, height + 4);
	cairo_set_source_rgb (context, 1, 1, 1);
	cairo_fill (context);

	cairo_translate (context, 2, 2);
	cairo_set_source_rgb (context, 0, 0, 0);
	pango_cairo_show_layout (context, layout);

	guint8 *data = cairo_image_surface_get_data (surface);
	GdkPixbuf *ret = gdk_pixbuf_new (GDK_COLORSPACE_RGB, TRUE, 8, width + 4, height + 4);
	guint8 *pixdata = gdk_pixbuf_get_pixels (ret);

	convert_bgra_to_rgba (data, pixdata, width + 4, height + 4);

	cairo_destroy (context);
	cairo_surface_destroy (surface);

	g_object_unref (layout);

	g_free (text);
	g_free (sha1);

	return ret;
}

static gchar *
generate_format_patch_filename (GitgRevision *revision)
{
	gchar *name = gitg_revision_get_format_patch_name (revision);
	gchar *filename = g_strdup_printf ("0001-%s.patch", name);

	g_free (name);
	return filename;
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

	if (ref && !can_drag (ref))
	{
		return;
	}
	else if (ref)
	{
		/* This is a DND operation on a ref */
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
	else
	{
		/* This is a normal DND operation which is just possibly just about
		   a SHA */
		GitgRevision *revision;
		GtkTreePath *path = NULL;

		revision = get_revision_at_pos (tree_view,
		                                (gint)data->x,
		                                (gint)data->y,
		                                &path);

		if (revision && !gitg_revision_get_sign (revision))
		{
			/* Make a DND for the revision */
			data->revision = revision;

			GdkDragContext *context = gtk_drag_begin (widget,
			                                          data->revision_target_list,
			                                          GDK_ACTION_COPY,
			                                          1,
			                                          event);
			GdkPixbuf *icon;
			gchar *filename;

			filename = generate_format_patch_filename (revision);

			gdk_property_change (gtk_widget_get_window (widget),
			                     XDS_ATOM, TEXT_ATOM,
			                     8, GDK_PROP_MODE_REPLACE,
			                     (guchar *) filename,
			                     strlen (filename));

			data->xds_filename = filename;

			icon = create_revision_drag_icon (tree_view, revision);

			if (icon)
			{
				gtk_drag_set_icon_pixbuf (context, icon, 0, 0);
				g_object_unref (icon);
			}

			gtk_tree_path_free (path);
		}

		if (revision)
		{
			gitg_revision_unref (revision);
		}
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
	               gtk_adjustment_get_upper (adj) - gtk_adjustment_get_page_size (adj));

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

	if (event->any.window != gtk_tree_view_get_bin_window (GTK_TREE_VIEW (widget)))
	{
		return FALSE;
	}

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
	if (!data->ref && !data->revision)
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

		if (data->ref && data->callback)
		{
			data->callback (data->ref, ref, FALSE, data->callback_data);
		}
		else if (data->revision && data->revision_callback)
		{
			data->revision_callback (data->revision, ref, FALSE, data->callback_data);
		}
	}

	if ((data->ref && ref && can_drop (data->ref, ref)) ||
	    (data->revision && ref && gitg_ref_get_ref_type (ref) == GITG_REF_TYPE_BRANCH))
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

	if (data->ref)
	{
		add_scroll_timeout (data);
	}

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
	if (!(data->ref || data->revision) || !data->target)
	{
		return FALSE;
	}

	gboolean ret = FALSE;

	if (data->ref && data->callback)
	{
		ret = data->callback (data->ref, data->target, TRUE, data->callback_data);
	}
	else if (data->revision && data->revision_callback)
	{
		ret = data->revision_callback (data->revision, data->target, TRUE, data->callback_data);
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

static void
remove_trailing_newlines (gchar **lines)
{
	gint lastnewline = -1;
	gchar **ptr = lines;
	gint i = 0;

	while (ptr && *ptr)
	{
		if (lastnewline == -1 && **ptr == '\0')
		{
			lastnewline = i;
		}
		else if (lastnewline != -1 && **ptr != '\0')
		{
			lastnewline = -1;
		}

		++i;
		++ptr;
	}

	if (lastnewline == -1)
	{
		return;
	}

	while (lines[lastnewline])
	{
		g_free (lines[lastnewline]);
		lines[lastnewline] = NULL;

		++lastnewline;
	}
}

static gchar *
revision_to_text (GitgRepository *repository,
                  GitgRevision   *revision)
{
	gchar **lines;
	gchar *sha1 = gitg_revision_get_sha1 (revision);

	lines = gitg_shell_run_sync_with_output (gitg_command_new (repository,
	                                                           "log",
	                                                           "-1",
	                                                           "--pretty=format:%h: %s%n%n%b",
	                                                           sha1,
	                                                           NULL),
	                                         FALSE,
	                                         NULL);

	remove_trailing_newlines (lines);
	gchar *ret = g_strjoinv ("\n", lines);

	g_strfreev (lines);
	g_free (sha1);

	return ret;
}

static gchar *
revision_to_uri (GitgRepository *repository,
                 GitgRevision   *revision)
{
	GFile *work_tree = gitg_repository_get_work_tree (repository);
	gchar *sha1 = gitg_revision_get_sha1 (revision);

	gchar *path = g_file_get_path (work_tree);
	gchar *ret = g_strdup_printf ("gitg://%s:%s", path, sha1);

	g_free (sha1);
	g_free (path);
	g_object_unref (work_tree);

	return ret;
}

static gchar *
revision_to_treeish (GitgRepository *repository,
                     GitgRevision   *revision)
{
	GFile *work_tree = gitg_repository_get_work_tree (repository);
	gchar *sha1 = gitg_revision_get_sha1 (revision);
	gchar *path = g_file_get_path (work_tree);

	gchar *ret = g_strdup_printf ("%s\n%s", path, sha1);

	g_free (sha1);
	g_free (path);
	g_object_unref (work_tree);

	return ret;
}

static gchar *
get_xds_filename (GtkWidget      *widget,
                  GdkDragContext *context)
{
	if (context == NULL || widget == NULL)
	{
		return NULL;
	}

	gint len;
	gchar *ret = NULL;

	if (gdk_property_get (gtk_widget_get_window (widget),
	                      XDS_ATOM, TEXT_ATOM,
	                      0, MAX_XDS_ATOM_VAL_LEN,
	                      FALSE, NULL, NULL, &len,
	                      (unsigned char **) &ret))
	{
		gchar *dupped = g_strndup (ret, len);
		g_free (ret);

		return dupped;
	}

	return NULL;
}

static gboolean
has_direct_save (GitgDndData    *data,
                 GtkWidget      *widget,
                 GdkDragContext *context)
{
	gboolean ret;

	if (!g_list_find (gdk_drag_context_list_targets (context), XDS_ATOM))
	{
		return FALSE;
	}

	gchar *filename = get_xds_filename (widget, context);
	ret = filename && *filename && g_strcmp0 (data->xds_filename, filename) != 0;
	g_free (filename);

	return ret;
}

static void
gitg_drag_source_data_get_cb (GtkWidget        *widget,
                              GdkDragContext   *context,
                              GtkSelectionData *selection,
                              guint             info,
                              guint             time,
                              GitgDndData      *data)
{
	if (!data->revision)
	{
		return;
	}

	GitgRepository *repository = GITG_REPOSITORY (gtk_tree_view_get_model (GTK_TREE_VIEW (widget)));

	if (has_direct_save (data, widget, context))
	{
		gchar *destination = get_xds_filename (widget, context);

		if (destination && *destination)
		{
			data->xds_destination = g_strdup (destination);

			gtk_selection_data_set (selection,
			                        gtk_selection_data_get_target (selection),
			                        8,
			                        (guchar const *)"S",
			                        1);
		}
		else
		{
			gtk_selection_data_set (selection,
			                        gtk_selection_data_get_target (selection),
			                        8,
			                        (guchar const *)"E",
			                        1);
		}

		g_free (destination);
		return;
	}

	switch (info)
	{
		case DRAG_TARGET_TEXT:
		{
			gchar *text = revision_to_text (repository, data->revision);
			gtk_selection_data_set_text (selection, text, -1);
			g_free (text);
		}
		break;
		case DRAG_TARGET_TREEISH:
		{
			gchar *treeish = revision_to_treeish (repository,
			                                      data->revision);

			gtk_selection_data_set (selection,
			                        gtk_selection_data_get_target (selection),
			                        8,
			                        (guchar const *)treeish,
			                        strlen (treeish));

			g_free (treeish);
		}
		break;
		case DRAG_TARGET_URI:
		{
			gchar *uri = revision_to_uri (repository, data->revision);
			gchar *uris[] = {uri, NULL};

			gtk_selection_data_set_uris (selection, uris);
			g_free (uri);
		}
		break;
	}
}

static void
gitg_drag_source_end_cb (GtkTreeView    *tree_view,
                         GdkDragContext *context,
                         GitgDndData    *data)
{
	if (data->revision)
	{
		gdk_property_delete (gtk_widget_get_window (GTK_WIDGET (tree_view)), XDS_ATOM);

		if (data->xds_destination != NULL)
		{
			/* Do extract it there then */
			GitgWindow *window = GITG_WINDOW (gtk_widget_get_toplevel (GTK_WIDGET (data->tree_view)));
			gitg_window_add_branch_action (window,
			                               gitg_branch_actions_format_patch (window,
			                                                                 data->revision,
			                                                                 data->xds_destination));

			g_free (data->xds_destination);
			data->xds_destination = NULL;
		}

		if (data->xds_filename != NULL)
		{
			g_free (data->xds_filename);
			data->xds_filename = NULL;
		}
	}
}

static void
gitg_drag_source_data_delete_cb (GtkTreeView    *tree_view,
                                 GdkDragContext *context,
                                 GitgDndData    *data)
{
	g_signal_stop_emission_by_name (tree_view, "drag-data-delete");
}

void
gitg_dnd_enable (GtkTreeView             *tree_view,
                 GitgDndCallback          callback,
                 GitgDndRevisionCallback  revision_callback,
                 gpointer                 callback_data)
{
	if (GITG_DND_GET_DATA (tree_view))
	{
		return;
	}

	GitgDndData *data = gitg_dnd_data_new ();

	data->tree_view = tree_view;
	data->callback = callback;
	data->revision_callback = revision_callback;
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
	                   target_dest_entries,
	                   G_N_ELEMENTS (target_dest_entries),
	                   GDK_ACTION_MOVE);

	g_signal_connect (tree_view,
	                  "drag-data-get",
	                  G_CALLBACK (gitg_drag_source_data_get_cb),
	                  data);

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

	g_signal_connect (tree_view,
	                  "drag-end",
	                  G_CALLBACK (gitg_drag_source_end_cb),
	                  data);

	g_signal_connect (tree_view,
	                  "drag-data-delete",
	                  G_CALLBACK (gitg_drag_source_data_delete_cb),
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
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_data_get_cb, data);
		g_signal_handlers_disconnect_by_func (tree_view, gitg_drag_source_end_cb, data);

		g_object_set_data (G_OBJECT (tree_view), GITG_DND_DATA_KEY, NULL);
	}
}
