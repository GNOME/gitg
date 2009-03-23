/*
 * gitg-diff-view.c
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

#include "gitg-diff-view.h"
#include "gitg-types.h"
#include <string.h>
#include <stdlib.h>

#define GITG_DIFF_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_DIFF_VIEW, GitgDiffViewPrivate))

#ifndef MAX
#define MAX(a, b) (a > b ? a : b)
#endif

#ifndef MIN
#define MIN(a, b) (a < b ? a : b)
#endif

#define IDLE_SCAN_COUNT 30

static void on_buffer_insert_text(GtkTextBuffer *buffer, GtkTextIter *iter, gchar const *text, gint len, GitgDiffView *view);
static void on_buffer_delete_range(GtkTextBuffer *buffer, GtkTextIter *start, GtkTextIter *end, GitgDiffView *view);

static gboolean on_idle_scan(GitgDiffView *view);

/* Signals */
enum
{
	HEADER_ADDED,
	HUNK_ADDED,
	NUM_SIGNALS
};

/* Properties */
enum
{
	PROP_0,
	
	PROP_DIFF_ENABLED
};

typedef struct _Region Region;

struct _Region
{
	GitgDiffIterType type;
	Region *next;
	Region *prev;

	guint line;
	gboolean visible;
};

typedef struct
{
	Region region;

	gchar index_from[HASH_SHA_SIZE + 1];
	gchar index_to[HASH_SHA_SIZE + 1];
} Header;

typedef struct 
{
	Region region;
	guint old;
	guint new;
} Hunk;

struct _GitgDiffViewPrivate
{
	guint last_scan_line;

	guint max_line_count;
	Region *regions;
	Region *last_region;
	GSequence *regions_index;
	
	guint scan_id;
	gboolean diff_enabled;
	GtkTextBuffer *current_buffer;
	GtkTextTag *invisible_tag;
};

G_DEFINE_TYPE(GitgDiffView, gitg_diff_view, GTK_TYPE_SOURCE_VIEW)

static gboolean gitg_diff_view_expose(GtkWidget *widget, GdkEventExpose *event);
static guint diff_view_signals[NUM_SIGNALS] = {0,};

static void
region_free(Region *region)
{
	if (!region)
		return;
	
	region_free(region->next);
	
	if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
		g_slice_free(Header, (Header *)region);
	else
		g_slice_free(Hunk, (Hunk *)region);
}

static void
regions_free(GitgDiffView *view, gboolean remove_signals)
{
	region_free(view->priv->regions);
	g_sequence_remove_range(g_sequence_get_begin_iter(view->priv->regions_index), g_sequence_get_end_iter(view->priv->regions_index));
	
	view->priv->regions = NULL;
	view->priv->last_region = NULL;
	view->priv->last_scan_line = 0;
	view->priv->max_line_count = 99;

	if (view->priv->scan_id)
	{
		g_source_remove(view->priv->scan_id);
		view->priv->scan_id = 0;
	}
	
	if (view->priv->current_buffer && remove_signals)
	{
		g_signal_handlers_disconnect_by_func(view->priv->current_buffer, G_CALLBACK(on_buffer_insert_text), view);
		g_signal_handlers_disconnect_by_func(view->priv->current_buffer, G_CALLBACK(on_buffer_delete_range), view);

		gtk_text_tag_table_remove(gtk_text_buffer_get_tag_table(view->priv->current_buffer), view->priv->invisible_tag);
		
		g_object_unref(view->priv->current_buffer);
		
		view->priv->current_buffer = NULL;
		view->priv->invisible_tag = NULL;
	}
}
							 
static void
gitg_diff_view_finalize(GObject *object)
{
	GitgDiffView *view = GITG_DIFF_VIEW(object);
	
	regions_free(view, TRUE);
	g_sequence_free(view->priv->regions_index);
	
	G_OBJECT_CLASS(gitg_diff_view_parent_class)->finalize(object);
}

static void
set_diff_enabled(GitgDiffView *view, gboolean enabled)
{
	view->priv->diff_enabled = enabled;
	gtk_widget_queue_draw(GTK_WIDGET(view));
}

static void
gitg_diff_view_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgDiffView *self = GITG_DIFF_VIEW(object);
	
	switch (prop_id)
	{
		case PROP_DIFF_ENABLED:
			set_diff_enabled(self, g_value_get_boolean(value));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_view_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgDiffView *self = GITG_DIFF_VIEW(object);

	switch (prop_id)
	{
		case PROP_DIFF_ENABLED:
			g_value_set_boolean(value, self->priv->diff_enabled);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_view_class_init(GitgDiffViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);
	
	object_class->finalize = gitg_diff_view_finalize;
	object_class->set_property = gitg_diff_view_set_property;
	object_class->get_property = gitg_diff_view_get_property;

	widget_class->expose_event = gitg_diff_view_expose;

	diff_view_signals[HEADER_ADDED] =
   		g_signal_new ("header-added",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgDiffViewClass, header_added),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__POINTER,
			      G_TYPE_NONE,
			      1,
			      G_TYPE_POINTER);

	diff_view_signals[HUNK_ADDED] =
   		g_signal_new ("hunk-added",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgDiffViewClass, hunk_added),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__POINTER,
			      G_TYPE_NONE,
			      1,
			      G_TYPE_POINTER);

	g_object_class_install_property(object_class, PROP_DIFF_ENABLED,
					 g_param_spec_boolean("diff-enabled",
							      "DIFF_ENABLED",
							      "Enables diff view",
							      FALSE,
							      G_PARAM_READWRITE));

	g_type_class_add_private(object_class, sizeof(GitgDiffViewPrivate));
}

static void
on_buffer_set(GitgDiffView *self, GParamSpec *spec, gpointer userdata)
{
	/* remove all regions for a new buffer */
	regions_free(self, TRUE);
	
	self->priv->current_buffer = g_object_ref(gtk_text_view_get_buffer(GTK_TEXT_VIEW(self)));
	g_signal_connect_after(self->priv->current_buffer, "insert-text", G_CALLBACK(on_buffer_insert_text), self);
	g_signal_connect_after(self->priv->current_buffer, "delete-range", G_CALLBACK(on_buffer_delete_range), self);

	self->priv->scan_id = g_idle_add((GSourceFunc)on_idle_scan, self);
	self->priv->invisible_tag = gtk_text_buffer_create_tag(self->priv->current_buffer, "GitgHunkInvisible", "invisible", TRUE, NULL);
}

static void
gitg_diff_view_init(GitgDiffView *self)
{
	self->priv = GITG_DIFF_VIEW_GET_PRIVATE(self);
	
	self->priv->regions_index = g_sequence_new(NULL);
	
	g_signal_connect(self, "notify::buffer", G_CALLBACK(on_buffer_set), NULL);
}

GitgDiffView*
gitg_diff_view_new()
{
	return g_object_new(GITG_TYPE_DIFF_VIEW, NULL);
}

/* This function is taken from gtk+/tests/testtext.c */
static void
get_lines (GtkTextView *text_view, gint first_y, gint last_y, GArray *buffer_coords, GArray *line_heights, GArray *numbers, gint *countp)
{
	GtkTextIter iter;
	gint count;
	gint size;
	gint last_line_num = -1;

	g_array_set_size(buffer_coords, 0);
	g_array_set_size(numbers, 0);
	
	if (line_heights != NULL)
		g_array_set_size(line_heights, 0);

	/* Get iter at first y */
	gtk_text_view_get_line_at_y(text_view, &iter, first_y, NULL);

	/* For each iter, get its location and add it to the arrays.
	 * Stop when we pass last_y */
	count = 0;
  	size = 0;

  	while (!gtk_text_iter_is_end(&iter))
    {
		gint y, height;

		gtk_text_view_get_line_yrange(text_view, &iter, &y, &height);

		g_array_append_val(buffer_coords, y);
		
		if (line_heights)
			g_array_append_val(line_heights, height);
			
		last_line_num = gtk_text_iter_get_line(&iter);
		g_array_append_val(numbers, last_line_num);

		++count;

		if ((y + height) >= last_y)
			break;

		gtk_text_iter_forward_line(&iter);
	}

	if (gtk_text_iter_is_end(&iter))
    {
		gint y, height;
		gint line_num;

		gtk_text_view_get_line_yrange(text_view, &iter, &y, &height);

		line_num = gtk_text_iter_get_line(&iter);

		if (line_num != last_line_num)
		{
			g_array_append_val(buffer_coords, y);
			
			if (line_heights)
				g_array_append_val(line_heights, height);

			g_array_append_val(numbers, line_num);
			++count;
		}
	}

	*countp = count;
}

static gint
index_compare(gconstpointer a, gconstpointer b, gpointer userdata)
{
	guint la = ((Region *)a)->line;
	guint lb = ((Region *)b)->line;
	
	return la < lb ? -1 : (la > lb ? 1 : 0);
}

static void
ensure_max_line(GitgDiffView *view, Hunk *hunk)
{
	guint num = hunk->region.next ? hunk->region.next->line - hunk->region.line : 0;
	guint m = MAX(hunk->new + num, hunk->old + num);

	if (m > view->priv->max_line_count)
		view->priv->max_line_count = m;
}

static void
add_region(GitgDiffView *view, Region *region)
{
	if (view->priv->last_region)
	{
		view->priv->last_region->next = region;
		region->prev = view->priv->last_region;
		
		if (view->priv->last_region->type == GITG_DIFF_ITER_TYPE_HUNK)
			ensure_max_line(view, (Hunk *)view->priv->last_region);
	}
	else
	{
		view->priv->regions = region;
		region->prev = NULL;
	}

	view->priv->last_region = region;
	g_sequence_insert_sorted(view->priv->regions_index, region, index_compare, NULL);
	
	GitgDiffIter iter;
	iter.userdata = view;
	iter.userdata2 = region;
	
	if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
		g_signal_emit(view, diff_view_signals[HEADER_ADDED], 0, &iter);
	else if (region->type == GITG_DIFF_ITER_TYPE_HUNK)
		g_signal_emit(view, diff_view_signals[HUNK_ADDED], 0, &iter);
}

static void
parse_hunk_info(Hunk *hunk, GtkTextIter *iter)
{
	GtkTextIter end = *iter;
	
	gtk_text_iter_forward_to_line_end(&end);
	gchar *text = gtk_text_iter_get_text(iter, &end);
	
	hunk->old = 0;
	hunk->new = 0;
	
	gchar *old = g_utf8_strchr(text, -1, '-');
	gchar *new = g_utf8_strchr(text, -1, '+');

	if (!old || !new)
		return;
	
	hunk->old = atoi(old + 1);
	hunk->new = atoi(new + 1);

	g_free(text);
}

static void
ensure_scan(GitgDiffView *view, guint last_line)
{
	/* Scan from last_scan_line, making regions */
	GtkTextIter iter;
	GtkTextBuffer *buffer = view->priv->current_buffer;
	gtk_text_buffer_get_iter_at_line(buffer, &iter, view->priv->last_scan_line);
	
	while (view->priv->last_scan_line <= last_line)
	{
		GtkTextIter start = iter;
		GtkTextIter end = iter;

		if (!gtk_text_iter_forward_line(&iter))
			break;

		++view->priv->last_scan_line;
		
		if (!gtk_text_iter_forward_chars(&end, 3))
			continue;

		gchar *text = gtk_text_iter_get_text(&start, &end);
		
		if (g_str_has_prefix(text, "@@ "))
		{
			/* start new hunk region */
			Hunk *hunk = g_slice_new(Hunk);
			hunk->region.type = GITG_DIFF_ITER_TYPE_HUNK;
			hunk->region.line = view->priv->last_scan_line - 1;
			hunk->region.visible = TRUE;
			
			parse_hunk_info(hunk, &start);
			
			add_region(view, (Region *)hunk);
			
			g_free(text);
			continue;
		}
		
		g_free(text);

		if (!gtk_text_iter_forward_chars(&end, 7))
			continue;
		
		text = gtk_text_iter_get_text(&start, &end);
		
		if (g_str_has_prefix(text, "diff --git"))
		{
			/* start new header region */
			Header *header = g_slice_new(Header);
			header->region.type = GITG_DIFF_ITER_TYPE_HEADER;
			header->region.line = view->priv->last_scan_line - 1;
			header->region.visible = TRUE;
			
			header->index_to[0] = '\0';
			header->index_from[0] = '\0';
			
			add_region(view, (Region *)header);
		}
		
		g_free(text);
	}
	
	if (view->priv->last_region && view->priv->last_region->type == GITG_DIFF_ITER_TYPE_HUNK)
		ensure_max_line(view, (Hunk *)view->priv->last_region);
}

static Region *
find_current_region(GitgDiffView *view, guint line)
{
	GSequenceIter *iter;
	Region tmp = {0, NULL, NULL, line};
	
	iter = g_sequence_search(view->priv->regions_index, &tmp, index_compare, NULL);
	
	if (!iter || g_sequence_iter_is_begin(iter))
		return NULL;

	if (!g_sequence_iter_is_end(iter))
	{
		Region *ret = (Region *)g_sequence_get(iter); 
	
		if (ret->line == line)
			return ret->visible ? ret : NULL;
	}
	 
	Region *ret = (Region *)g_sequence_get(g_sequence_iter_prev(iter));
	return ret->visible ? ret : NULL;
}

static gboolean
line_has_prefix(GitgDiffView *view, guint line, gchar const *prefix)
{
	GtkTextIter iter;
	
	gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, &iter, line);

	GtkTextIter end = iter;
	if (!gtk_text_iter_forward_chars(&end, g_utf8_strlen(prefix, -1)))
		return FALSE;
	
	gchar *text = gtk_text_iter_get_text(&iter, &end);
	gboolean ret = g_str_has_prefix(text, prefix);
	g_free(text);
	
	return ret;
}

static gboolean
draw_old(GitgDiffView *view, guint line)
{
	return !line_has_prefix(view, line, "+");
}

static gboolean
draw_new(GitgDiffView *view, guint line)
{
	return !line_has_prefix(view, line, "-");
}

static void
get_initial_counters(GitgDiffView *view, Region *region, guint line, guint counters[2])
{
	guint i;
	
	counters[0] = counters[1] = 0;
	
	for (i = region->line + 1; i < line; ++i)
	{
		if (draw_old(view, i))
			++counters[0];
		
		if (draw_new(view, i))
			++counters[1];
	}
}

static void
paint_line_numbers(GitgDiffView *view, GdkEventExpose *event)
{
	GtkTextView *text_view;
	GdkWindow *win;
	PangoLayout *layout;
	GArray *numbers;
	GArray *pixels;
	gchar str_old[16];  /* we don't expect more than ten million lines ;-) */
	gchar str_new[16];
	gint y1, y2;
	gint count;
	gint margin_width;
	gint text_width;
	gint i;
	GtkTextIter cur;

	text_view = GTK_TEXT_VIEW(view);
	win = gtk_text_view_get_window(text_view, GTK_TEXT_WINDOW_LEFT);

	y1 = event->area.y;
	y2 = y1 + event->area.height;

	/* get the extents of the line printing */
	gtk_text_view_window_to_buffer_coords(text_view, GTK_TEXT_WINDOW_LEFT, 0, y1, NULL, &y1);
	gtk_text_view_window_to_buffer_coords(text_view, GTK_TEXT_WINDOW_LEFT, 0, y2, NULL, &y2);

	numbers = g_array_new(FALSE, FALSE, sizeof(gint));
	pixels = g_array_new(FALSE, FALSE, sizeof(gint));

	/* get the line numbers and y coordinates. */
	get_lines(text_view, y1, y2, pixels, NULL, numbers, &count);
	
	/* A zero-lined document should display a "1"; we don't need to worry about
	scrolling effects of the text widget in this special case */

	if (count == 0)
	{
		gint y = 0;
		gint n = 0;
		count = 1;
		g_array_append_val(pixels, y);
		g_array_append_val(numbers, n);
	}
	
	/* Ensure scanned until last needed line */	
	guint last = g_array_index(numbers, gint, count - 1);
	ensure_scan(view, last);

	/* set size */
	g_snprintf(str_old, sizeof(str_old), "%d", MAX(99, view->priv->max_line_count));
	layout = gtk_widget_create_pango_layout(GTK_WIDGET(view), str_old);

	pango_layout_get_pixel_size(layout, &text_width, NULL);

	/* determine the width of the left margin. */
	margin_width = text_width * 2 + 9;
	
	guint extra_width = 0;
	
	if (gtk_source_view_get_show_line_marks(GTK_SOURCE_VIEW(view)))
		extra_width = 20;

	pango_layout_set_width(layout, text_width);
	pango_layout_set_alignment(layout, PANGO_ALIGN_RIGHT);

	gtk_text_view_set_border_window_size(GTK_TEXT_VIEW(text_view), GTK_TEXT_WINDOW_LEFT, margin_width + extra_width);
	gtk_text_buffer_get_iter_at_mark(text_view->buffer, &cur, gtk_text_buffer_get_insert(text_view->buffer));

	Region *current = NULL;
	guint counters[2];

	for (i = 0; i < count; ++i)
	{
		gint pos;
		gint line_to_paint;

		gtk_text_view_buffer_to_window_coords(text_view, GTK_TEXT_WINDOW_LEFT, 0, g_array_index(pixels, gint, i), NULL, &pos);
		line_to_paint = g_array_index(numbers, gint, i);
		
		if (!current)
		{
			current = find_current_region(view, line_to_paint);
			
			if (current)
				get_initial_counters(view, current, line_to_paint, counters);
		}
		
		*str_old = '\0';
		*str_new = '\0';

		if (current && current->type == GITG_DIFF_ITER_TYPE_HUNK && line_to_paint != current->line)
		{
			Hunk *hunk = (Hunk *)current;
			
			if (draw_old(view, line_to_paint))
				g_snprintf(str_old, sizeof(str_old), "%d", hunk->old + counters[0]++);

			if (draw_new(view, line_to_paint))
				g_snprintf(str_new, sizeof(str_new), "%d", hunk->new + counters[1]++);
		}
		
		pango_layout_set_markup(layout, str_old, -1);
		gtk_paint_layout(GTK_WIDGET(view)->style, win, GTK_WIDGET_STATE(view), FALSE, NULL, GTK_WIDGET(view), NULL, margin_width - 7 - text_width, pos, layout);

		pango_layout_set_markup(layout, str_new, -1);
		gtk_paint_layout(GTK_WIDGET(view)->style, win, GTK_WIDGET_STATE(view), FALSE, NULL, GTK_WIDGET(view), NULL, margin_width - 2, pos, layout);

		if (current && current->next && line_to_paint == current->next->line - 1)
		{
			counters[0] = counters[1] = 0;
			current = current->next->visible ? current->next : NULL;
		}
	}
	
	gtk_paint_vline(GTK_WIDGET(view)->style, win, GTK_WIDGET_STATE(view), NULL, GTK_WIDGET(view), NULL, event->area.y, event->area.y + event->area.height, 4 + text_width);

	g_array_free(pixels, TRUE);
	g_array_free(numbers, TRUE);

	g_object_unref(G_OBJECT(layout));
}

static gint 
gitg_diff_view_expose(GtkWidget *widget, GdkEventExpose *event)
{
	gboolean ret = FALSE;
	GtkTextView *text_view = GTK_TEXT_VIEW(widget);
	GitgDiffView *view = GITG_DIFF_VIEW(widget);

	if (event->window == gtk_text_view_get_window(text_view, GTK_TEXT_WINDOW_LEFT) && 
	    view->priv->diff_enabled && gtk_source_view_get_show_line_numbers(GTK_SOURCE_VIEW(view)))
	{
		paint_line_numbers(GITG_DIFF_VIEW(widget), event);
		ret = TRUE;
	}

	if (GTK_WIDGET_CLASS(gitg_diff_view_parent_class)->expose_event)
		ret = ret || GTK_WIDGET_CLASS(gitg_diff_view_parent_class)->expose_event(widget, event);

	return ret;
}

void
gitg_diff_view_set_diff_enabled(GitgDiffView *view, gboolean enabled)
{
	g_return_if_fail(GITG_IS_DIFF_VIEW(view));

	set_diff_enabled(view, enabled);

	g_object_notify(G_OBJECT(view), "diff-enabled");
}

void
gitg_diff_view_remove_hunk(GitgDiffView *view, GtkTextIter *iter)
{
	g_return_if_fail(GITG_IS_DIFF_VIEW(view));
	
	/* removes hunk at iter and if it was the last hunk of a file, also removes
	   the file header */
	Region *region = find_current_region(view, gtk_text_iter_get_line(iter));
	
	if (!region)
		return;
	
	GtkTextIter start;
	GtkTextIter end;
	
	gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, &start, region->line);
	
	if (region->next)
	{
		gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, &end, region->next->line - 1);
		gtk_text_iter_forward_line(&end);
	}
	else
	{
		gtk_text_buffer_get_end_iter(view->priv->current_buffer, &end);
	}
	
	Region *prev = find_current_region(view, region->line - 1);
	
	if ((!region->next || region->next->type == GITG_DIFF_ITER_TYPE_HEADER) && (!prev || prev->type == GITG_DIFF_ITER_TYPE_HEADER))
	{
		if (!prev)
			gtk_text_buffer_get_start_iter(view->priv->current_buffer, &start);
		else
			gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, &start, region->line);
	}
	
	gtk_text_buffer_delete(view->priv->current_buffer, &start, &end);
}

gboolean
gitg_diff_view_get_start_iter(GitgDiffView *view, GitgDiffIter *iter)
{
	g_return_val_if_fail(GITG_IS_DIFF_VIEW(view), FALSE);
	g_return_val_if_fail(iter != NULL, FALSE);

	iter->userdata = view;
	iter->userdata2 = view->priv->regions;
	
	return iter->userdata2 != NULL;
}

gboolean
gitg_diff_iter_forward(GitgDiffIter *iter)
{
	g_return_val_if_fail(iter != NULL, FALSE);
	
	if (!iter->userdata2)
		return FALSE;
	
	iter->userdata2 = ((Region *)iter->userdata2)->next;

	return iter->userdata2 != NULL;
}

gboolean
gitg_diff_view_get_end_iter(GitgDiffView *view, GitgDiffIter *iter)
{
	g_return_val_if_fail(GITG_IS_DIFF_VIEW(view), FALSE);
	g_return_val_if_fail(iter != NULL, FALSE);

	iter->userdata = view;
	iter->userdata2 = view->priv->last_region;
	
	return iter->userdata2 != NULL;
}

gboolean
gitg_diff_iter_backward(GitgDiffIter *iter)
{
	g_return_val_if_fail(iter != NULL, FALSE);
	
	if (!iter->userdata2)
		return FALSE;
	
	iter->userdata2 = ((Region *)iter->userdata2)->prev;

	return iter->userdata2 != NULL;
	
}

GitgDiffIterType 
gitg_diff_iter_get_type(GitgDiffIter *iter)
{
	g_return_val_if_fail(iter != NULL, 0);
	g_return_val_if_fail(GITG_IS_DIFF_VIEW(iter->userdata), 0);
	g_return_val_if_fail(iter->userdata2 != NULL, 0);
	
	return ((Region *)iter->userdata2)->type;
}

static void
region_iter_range(GitgDiffView *view, Region *region, GtkTextIter *start, GtkTextIter *end)
{
	gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, start, region->line);
	
	Region *next = region->next;
	
	while (next && next->type != region->type)
		next = next->next;
	
	if (next)
		gtk_text_buffer_get_iter_at_line(view->priv->current_buffer, end, next->line);
	else
		gtk_text_buffer_get_end_iter(view->priv->current_buffer, end);
}

void
gitg_diff_iter_set_visible(GitgDiffIter *iter, gboolean visible)
{
	g_return_if_fail(iter != NULL);
	g_return_if_fail(GITG_IS_DIFF_VIEW(iter->userdata));
	g_return_if_fail(iter->userdata2 != NULL);

	GitgDiffView *view = GITG_DIFF_VIEW(iter->userdata);
	Region *region = (Region *)iter->userdata2;
	
	if (region->visible == visible)
		return;
	
	GtkTextIter start;
	GtkTextIter end;
	
	region_iter_range(view, region, &start, &end);
	region->visible = visible;
	
	/* Propagate visibility to hunks */
	if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
	{
		Region *next = region->next;
		
		while (next && next->type != GITG_DIFF_ITER_TYPE_HEADER)
		{
			next->visible = visible;
			next = next->next;
		}
	}

	if (visible)
	{
		gtk_text_buffer_remove_tag(view->priv->current_buffer, view->priv->invisible_tag, &start, &end);
	}
	else
	{
		gtk_text_buffer_apply_tag(view->priv->current_buffer, view->priv->invisible_tag, &start, &end);
	}	
}

static gboolean
header_parse_index(GitgDiffView *view, Header *header)
{
	GtkTextIter iter;
	GtkTextBuffer *buffer = view->priv->current_buffer;
	guint num;
	guint i;

	if (header->region.next)
		num = header->region.next->line - header->region.line;
	else
		num = gtk_text_buffer_get_line_count(buffer) - header->region.line;
	
	gtk_text_buffer_get_iter_at_line(buffer, &iter, header->region.line);
	
	for (i = 0; i < num; ++i)
	{
		if (!gtk_text_iter_forward_line(&iter))
			return FALSE;
		
		GtkTextIter end = iter;
		gtk_text_iter_forward_to_line_end(&end);

		/* get line contents */
		gchar *line = gtk_text_iter_get_text(&iter, &end);
		gchar match[] = "index ";

		if (g_str_has_prefix(line, match))
		{
			gchar *start = line + strlen(match);
			gchar *sep = strstr(start, "..");
			gboolean ret;
			
			if (sep)
			{
				gchar *last = strstr(sep, " ");
				
				if (!last)
					last = line + strlen(line);
				
				strncpy(header->index_from, start, sep - start);
				strncpy(header->index_to, sep + 2, last - (sep + 2));
				
				header->index_from[sep - start] = '\0';
				header->index_to[last - (sep + 2)] = '\0';

				ret = TRUE;
			}
			else
			{
				ret = FALSE;
			}
			
			g_free(line);
			return ret;
		}
		
		g_free(line);
	}
	
	return FALSE;
}

gboolean
gitg_diff_iter_get_index(GitgDiffIter *iter, gchar **from, gchar **to)
{
	Region *region = (Region *)iter->userdata2;
	
	while (region && region->type != GITG_DIFF_ITER_TYPE_HEADER)
		region = region->prev;
	
	if (!region)
		return FALSE;
	
	Header *header = (Header *)region;
	gboolean ret = TRUE;
	
	if (!*(header->index_to))
		ret = header_parse_index((GitgDiffView *)iter->userdata, header);
	
	if (!ret)
		return FALSE;
	
	*from = header->index_from;
	*to = header->index_to;
	
	return TRUE;
}

static gboolean 
iter_in_view(GitgDiffView *view, GtkTextIter *iter)
{
	GtkTextIter start;
	GtkTextIter end;
	GdkRectangle rect;
	GtkTextView *textview = GTK_TEXT_VIEW(view);
	
	gtk_text_view_get_visible_rect(textview, &rect);
	gtk_text_view_get_iter_at_location(textview, &start, rect.x, rect.y);
	gtk_text_view_get_iter_at_location(textview, &end, rect.x + rect.width, rect.y + rect.height);
	
	return gtk_text_iter_in_range(iter, &start, &end) || gtk_text_iter_equal(iter, &end);
}

static gboolean
try_scan(GitgDiffView *view)
{
	gint lines = gtk_text_buffer_get_line_count(view->priv->current_buffer);
	
	if (view->priv->last_scan_line > lines)
		return FALSE;

	guint num = MIN(lines - view->priv->last_scan_line, IDLE_SCAN_COUNT);
	
	if (num == 0)
		return FALSE;

	gchar str[8];
	g_snprintf(str, sizeof(str), "%u", view->priv->max_line_count);
	guint max_line = strlen(str);

	guint last = view->priv->last_scan_line;
	ensure_scan(view, view->priv->last_scan_line + num);
	g_snprintf(str, sizeof(str), "%u", view->priv->max_line_count);
	
	if (strlen(str) > max_line)
		gtk_widget_queue_draw(GTK_WIDGET(view));
	
	return last != view->priv->last_scan_line;
}

static void
on_buffer_delete_range(GtkTextBuffer *buffer, GtkTextIter *start, GtkTextIter *end, GitgDiffView *view)
{
	regions_free(view, FALSE);

	if (iter_in_view(view, start) || iter_in_view(view, end))
		try_scan(view);

	if (!view->priv->scan_id)
		view->priv->scan_id = g_idle_add((GSourceFunc)on_idle_scan, view);
}

static void 
on_buffer_insert_text(GtkTextBuffer *buffer, GtkTextIter *iter, gchar const *text, gint len, GitgDiffView *view)
{
	/* if region is in current view and not scanned, issue scan now */
	if (iter_in_view(view, iter))
		try_scan(view);

	if (!view->priv->scan_id)
		view->priv->scan_id = g_idle_add((GSourceFunc)on_idle_scan, view);
}

static gboolean 
on_idle_scan(GitgDiffView *view)
{
	if (try_scan(view))
		return TRUE;
	
	view->priv->scan_id = 0;
	return FALSE;
}
