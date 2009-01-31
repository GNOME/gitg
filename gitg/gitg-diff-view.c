#include "gitg-diff-view.h"
#include <string.h>

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

/* Properties */
enum
{
	PROP_0,
	
	PROP_DIFF_ENABLED
};

typedef struct _Region Region;

typedef enum
{
	REGION_TYPE_HEADER,
	REGION_TYPE_HUNK
} RegionType;

struct _Region
{
	RegionType type;
	Region *next;

	guint line;
};

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
};

G_DEFINE_TYPE(GitgDiffView, gitg_diff_view, GTK_TYPE_SOURCE_VIEW)

static gboolean gitg_diff_view_expose(GtkWidget *widget, GdkEventExpose *event);

static void
region_free(Region *region)
{
	if (!region)
		return;
	
	region_free(region->next);
	
	if (region->type == REGION_TYPE_HEADER)
		g_slice_free(Region, region);
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

		g_object_unref(view->priv->current_buffer);
		view->priv->current_buffer = NULL;
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
	GtkTextViewClass *text_view_class = GTK_TEXT_VIEW_CLASS(klass);
	
	object_class->finalize = gitg_diff_view_finalize;
	object_class->set_property = gitg_diff_view_set_property;
	object_class->get_property = gitg_diff_view_get_property;

	widget_class->expose_event = gitg_diff_view_expose;

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
		
		if (view->priv->last_region->type == REGION_TYPE_HUNK)
			ensure_max_line(view, (Hunk *)view->priv->last_region);
	}
	else
	{
		view->priv->regions = region;
	}

	view->priv->last_region = region;
	g_sequence_insert_sorted(view->priv->regions_index, region, index_compare, NULL);
}

static void
parse_hunk_info(Hunk *hunk, GtkTextIter *iter)
{
	GtkTextIter end = *iter;
	
	gtk_text_iter_forward_to_line_end(&end);
	gchar *text = gtk_text_iter_get_text(iter, &end);
	
	gchar *next = g_utf8_strchr(text, -1, '-');
	gchar *comma = g_utf8_strchr(next, -1, ',');
	*comma = '\0';

	hunk->old = atoi(next + 1);
	
	next = g_utf8_strchr(comma + 1, -1, '+');
	comma = g_utf8_strchr(next, -1, ',');
	*comma = '\0';

	hunk->new = atoi(next + 1);

	g_free(text);
}

static void
ensure_scan(GitgDiffView *view, guint last_line)
{
	/* Scan from last_scan_line, making regions */
	GtkTextIter iter;
	GtkTextBuffer *buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(view));
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
			hunk->region.type = REGION_TYPE_HUNK;
			hunk->region.line = view->priv->last_scan_line - 1;
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
			Region *region = g_slice_new(Region);
			region->type = REGION_TYPE_HEADER;
			region->line = view->priv->last_scan_line - 1;
			
			add_region(view, region);
		}
		
		g_free(text);
	}
	
	if (view->priv->last_region && view->priv->last_region->type == REGION_TYPE_HUNK)
		ensure_max_line(view, (Hunk *)view->priv->last_region);
}

static Region *
find_current_region(GitgDiffView *view, guint line)
{
	GSequenceIter *iter;
	Region tmp = {0, NULL, line};
	
	iter = g_sequence_search(view->priv->regions_index, &tmp, index_compare, NULL);
	
	if (!iter || g_sequence_iter_is_begin(iter))
		return NULL;

	if (!g_sequence_iter_is_end(iter))
	{
		Region *ret = (Region *)g_sequence_get(iter); 
	
		if (ret->line == line)
			return ret;
	}
	 
	return (Region *)g_sequence_get(g_sequence_iter_prev(iter));
}

static gboolean
line_has_prefix(GitgDiffView *view, guint line, gchar const *prefix)
{
	GtkTextIter iter;
	
	gtk_text_buffer_get_iter_at_line(gtk_text_view_get_buffer(GTK_TEXT_VIEW(view)), &iter, line);

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
	
	for (i = region->line; i < line; ++i)
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
	gint text_width, x_pixmap;
	gint i;
	GtkTextIter cur;
	gint cur_line;

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

		if (current && current->type == REGION_TYPE_HUNK)
		{
			Hunk *hunk = (Hunk *)current;
			
			if (draw_old(view, line_to_paint))
				g_snprintf(str_old, sizeof(str_old), line_to_paint == current->line ? "<b>%d</b>" : "%d", hunk->old + counters[0]++);

			if (draw_new(view, line_to_paint))
				g_snprintf(str_new, sizeof(str_new), line_to_paint == current->line ? "<b>%d</b>" : "%d", hunk->new + counters[1]++);
		}
		
		pango_layout_set_markup(layout, str_old, -1);
		gtk_paint_layout(GTK_WIDGET(view)->style, win, GTK_WIDGET_STATE(view), FALSE, NULL, GTK_WIDGET(view), NULL, margin_width - 7 - text_width, pos, layout);

		pango_layout_set_markup(layout, str_new, -1);
		gtk_paint_layout(GTK_WIDGET(view)->style, win, GTK_WIDGET_STATE(view), FALSE, NULL, GTK_WIDGET(view), NULL, margin_width - 2, pos, layout);

		if (current && current->next && line_to_paint == current->next->line - 1)
		{
			counters[0] = counters[1] = 0;
			current = current->next;
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

gboolean
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
