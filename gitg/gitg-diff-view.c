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

#include <libgitg/gitg-types.h>

#include "gitg-diff-view.h"
#include "gitg-diff-line-renderer.h"
#include "gitg-utils.h"

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

#define GITG_DIFF_ITER_GET_VIEW(iter) ((GitgDiffView *)((iter)->userdata))
#define GITG_DIFF_ITER_GET_REGION(iter) ((Region *)((iter)->userdata2))

#define GITG_DIFF_ITER_SET_REGION(iter, region) ((iter)->userdata2 = region)
#define GITG_DIFF_ITER_SET_VIEW(iter, view) ((iter)->userdata = view)

static void on_buffer_insert_text (GtkTextBuffer *buffer,
                                   GtkTextIter *iter,
                                   gchar const *text,
                                   gint len,
                                   GitgDiffView *view);

static void on_buffer_delete_range (GtkTextBuffer *buffer,
                                    GtkTextIter *start,
                                    GtkTextIter *end,
                                    GitgDiffView *view);

static void
line_renderer_size_func (GtkSourceGutter *gutter,
                         GtkCellRenderer *cell,
                         GitgDiffView    *view);
static void
line_renderer_data_func (GtkSourceGutter *gutter,
                         GtkCellRenderer *cell,
                         gint             line_number,
                         gboolean         current_line,
                         GitgDiffView    *view);

static void disable_diff_view (GitgDiffView *view);
static void enable_diff_view (GitgDiffView *view);

static gboolean on_idle_scan (GitgDiffView *view);

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
	GtkTextTag *subheader_tag;

	GitgDiffLineRenderer *line_renderer;

	Region *lines_current_region;
	gint lines_previous_line;
	guint lines_counters[2];

	gboolean ignore_changes;

	GitgDiffViewLabelFunc label_func;
	gpointer label_func_user_data;
	GDestroyNotify label_func_destroy_notify;
};

G_DEFINE_TYPE(GitgDiffView, gitg_diff_view, GTK_TYPE_SOURCE_VIEW)

static gboolean gitg_diff_view_expose(GtkWidget *widget, GdkEventExpose *event);
static guint diff_view_signals[NUM_SIGNALS] = {0,};

static void
region_free (Region   *region,
             gboolean  all)
{
	if (!region)
	{
		return;
	}

	if (all)
	{
		region_free (region->next, all);
	}
	else
	{
		if (region->next)
		{
			region->next->prev = region->prev;
		}

		if (region->prev)
		{
			region->prev->next = region->next;
		}
	}

	if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
	{
		g_slice_free (Header, (Header *)region);
	}
	else
	{
		g_slice_free (Hunk, (Hunk *)region);
	}
}

static void
regions_free (GitgDiffView *view)
{
	region_free (view->priv->regions, TRUE);

	g_sequence_remove_range (g_sequence_get_begin_iter (view->priv->regions_index),
	                         g_sequence_get_end_iter (view->priv->regions_index));

	view->priv->regions = NULL;
	view->priv->last_region = NULL;
	view->priv->last_scan_line = 0;
	view->priv->max_line_count = 99;
}

static void
gitg_diff_view_finalize (GObject *object)
{
	GitgDiffView *view = GITG_DIFF_VIEW (object);

	regions_free (view);
	g_sequence_free (view->priv->regions_index);

	if (view->priv->label_func &&
	    view->priv->label_func_destroy_notify)
	{
		view->priv->label_func_destroy_notify (view->priv->label_func_user_data);
	}

	G_OBJECT_CLASS (gitg_diff_view_parent_class)->finalize (object);
}

static void
gitg_diff_view_dispose (GObject *object)
{
	GitgDiffView *view = GITG_DIFF_VIEW (object);

	disable_diff_view (view);

	if (view->priv->line_renderer)
	{
		g_object_unref (view->priv->line_renderer);
		view->priv->line_renderer = NULL;
	}

	G_OBJECT_CLASS (gitg_diff_view_parent_class)->dispose (object);
}

static void
set_diff_enabled (GitgDiffView *view,
                  gboolean      enabled)
{
	if (enabled == view->priv->diff_enabled)
	{
		return;
	}

	if (enabled)
	{
		enable_diff_view (view);
	}
	else
	{
		disable_diff_view (view);
	}

	gtk_widget_queue_draw (GTK_WIDGET(view));
}

static void
gitg_diff_view_set_property (GObject      *object,
                             guint         prop_id,
                             const GValue *value,
                             GParamSpec   *pspec)
{
	GitgDiffView *self = GITG_DIFF_VIEW(object);

	switch (prop_id)
	{
		case PROP_DIFF_ENABLED:
			set_diff_enabled(self, g_value_get_boolean (value));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_view_get_property (GObject    *object,
                             guint       prop_id,
                             GValue     *value,
                             GParamSpec *pspec)
{
	GitgDiffView *self = GITG_DIFF_VIEW (object);

	switch (prop_id)
	{
		case PROP_DIFF_ENABLED:
			g_value_set_boolean (value, self->priv->diff_enabled);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_diff_view_constructed (GObject *object)
{
	g_object_set (object, "show-line-numbers", FALSE, NULL);
}

static void
gitg_diff_view_class_init(GitgDiffViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS(klass);

	object_class->finalize = gitg_diff_view_finalize;
	object_class->dispose = gitg_diff_view_dispose;
	object_class->set_property = gitg_diff_view_set_property;
	object_class->get_property = gitg_diff_view_get_property;

	object_class->constructed = gitg_diff_view_constructed;

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

	g_type_class_add_private (object_class, sizeof(GitgDiffViewPrivate));
}

static void
disable_diff_view (GitgDiffView *view)
{
	if (!view->priv->diff_enabled)
	{
		return;
	}

	regions_free (view);

	if (view->priv->scan_id)
	{
		g_source_remove (view->priv->scan_id);
		view->priv->scan_id = 0;
	}

	if (view->priv->current_buffer)
	{
		GtkTextTagTable *table;
		GtkSourceGutter *gutter;

		table = gtk_text_buffer_get_tag_table (view->priv->current_buffer);

		g_signal_handlers_disconnect_by_func (view->priv->current_buffer,
		                                      G_CALLBACK (on_buffer_insert_text),
		                                      view);

		g_signal_handlers_disconnect_by_func (view->priv->current_buffer,
		                                      G_CALLBACK (on_buffer_delete_range),
		                                      view);

		gtk_text_tag_table_remove (table, view->priv->invisible_tag);
		gtk_text_tag_table_remove (table, view->priv->subheader_tag);

		g_object_unref (view->priv->current_buffer);

		view->priv->current_buffer = NULL;
		view->priv->invisible_tag = NULL;
		view->priv->subheader_tag = NULL;

		gutter = gtk_source_view_get_gutter (GTK_SOURCE_VIEW (view),
		                                     GTK_TEXT_WINDOW_LEFT);

		gtk_source_gutter_remove (gutter,
		                          GTK_CELL_RENDERER (view->priv->line_renderer));
	}

	view->priv->diff_enabled = FALSE;
}

static void
enable_diff_view (GitgDiffView *view)
{
	GtkTextBuffer *buffer;
	GtkTextTagTable *table;
	GtkSourceGutter *gutter;

	if (view->priv->diff_enabled)
	{
		disable_diff_view (view);
	}

	buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));
	view->priv->current_buffer = g_object_ref (buffer);

	g_signal_connect_after (buffer,
	                        "insert-text",
	                        G_CALLBACK (on_buffer_insert_text),
	                        view);

	g_signal_connect_after (buffer,
	                        "delete-range",
	                        G_CALLBACK (on_buffer_delete_range),
	                        view);

	view->priv->scan_id = g_idle_add ((GSourceFunc)on_idle_scan, view);

	view->priv->invisible_tag = gtk_text_buffer_create_tag (view->priv->current_buffer,
	                                                        "GitgHunkInvisible",
	                                                        "invisible",
	                                                        TRUE,
	                                                        NULL);

	view->priv->subheader_tag = gtk_text_buffer_create_tag (view->priv->current_buffer,
	                                                        "GitgHunkSubHeader",
	                                                        "invisible",
	                                                        TRUE,
	                                                        NULL);

	table = gtk_text_buffer_get_tag_table (view->priv->current_buffer);

	gtk_text_tag_set_priority (view->priv->subheader_tag,
	                           gtk_text_tag_table_get_size (table) - 1);

	gutter = gtk_source_view_get_gutter (GTK_SOURCE_VIEW (view),
	                                     GTK_TEXT_WINDOW_LEFT);

	gtk_source_gutter_insert (gutter,
	                          GTK_CELL_RENDERER (view->priv->line_renderer),
	                          0);

	gtk_source_gutter_set_cell_data_func (gutter,
	                                      GTK_CELL_RENDERER (view->priv->line_renderer),
	                                      (GtkSourceGutterDataFunc)line_renderer_data_func,
	                                      view,
	                                      NULL);

	gtk_source_gutter_set_cell_size_func (gutter,
	                                      GTK_CELL_RENDERER (view->priv->line_renderer),
	                                      (GtkSourceGutterSizeFunc)line_renderer_size_func,
	                                      view,
	                                      NULL);

	view->priv->diff_enabled = TRUE;
}

static void
on_buffer_set (GitgDiffView *self, GParamSpec *spec, gpointer userdata)
{
	if (self->priv->diff_enabled)
	{
		enable_diff_view (self);
	}
}

static void
gitg_diff_view_init (GitgDiffView *self)
{
	self->priv = GITG_DIFF_VIEW_GET_PRIVATE (self);

	self->priv->regions_index = g_sequence_new (NULL);
	self->priv->line_renderer = gitg_diff_line_renderer_new ();

	g_object_ref (self->priv->line_renderer);
	g_object_set (self->priv->line_renderer, "xpad", 2, NULL);

	g_signal_connect (self, "notify::buffer", G_CALLBACK (on_buffer_set), NULL);
}

GitgDiffView *
gitg_diff_view_new ()
{
	return g_object_new (GITG_TYPE_DIFF_VIEW, NULL);
}

static gint
index_compare(gconstpointer a, gconstpointer b, gpointer userdata)
{
	guint la = ((Region *)a)->line;
	guint lb = ((Region *)b)->line;

	return la < lb ? -1 : (la > lb ? 1 : 0);
}

static void
ensure_max_line (GitgDiffView *view, Hunk *hunk)
{
	guint num = hunk->region.next ? hunk->region.next->line - hunk->region.line : 0;
	guint m = MAX (hunk->new + num, hunk->old + num);

	if (m > view->priv->max_line_count)
	{
		view->priv->max_line_count = m;

		gtk_source_gutter_queue_draw (gtk_source_view_get_gutter (GTK_SOURCE_VIEW (view), GTK_TEXT_WINDOW_LEFT));
	}
}

static void
hide_header_details (GitgDiffView *view,
                     Region       *region)
{
	/* Just hide the lines 2->n lines from region to region->next */
	GtkTextBuffer *buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));
	GtkTextIter startiter;
	GtkTextIter enditer;

	gint line = region->line + 2;

	gtk_text_buffer_get_iter_at_line (buffer, &startiter, line);

	enditer = startiter;

	if (region->next)
	{
		gtk_text_iter_forward_lines (&enditer, region->next->line - line);
	}
	else
	{
		gtk_text_iter_forward_line (&enditer);
	}

	gtk_text_buffer_apply_tag (buffer, view->priv->subheader_tag, &startiter, &enditer);
}

static void
region_to_iter (GitgDiffView *view, Region *region, GitgDiffIter *iter)
{
	GITG_DIFF_ITER_SET_VIEW (iter, view);
	GITG_DIFF_ITER_SET_REGION (iter, region);
}

static void
add_region (GitgDiffView *view, Region *region)
{
	if (view->priv->last_region)
	{
		view->priv->last_region->next = region;
		region->prev = view->priv->last_region;

		if (view->priv->last_region->type == GITG_DIFF_ITER_TYPE_HUNK)
		{
			ensure_max_line (view, (Hunk *)view->priv->last_region);
		}
	}
	else
	{
		view->priv->regions = region;
		region->prev = NULL;
	}

	view->priv->last_region = region;

	if (region->prev && region->prev->type == GITG_DIFF_ITER_TYPE_HEADER)
	{
		/* Hide header details if first hunk is scanned */
		hide_header_details (view, region->prev);
	}

	g_sequence_insert_sorted(view->priv->regions_index, region, index_compare, NULL);

	GitgDiffIter iter;
	region_to_iter (view, region, &iter);

	if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
	{
		g_signal_emit(view, diff_view_signals[HEADER_ADDED], 0, &iter);
	}
	else if (region->type == GITG_DIFF_ITER_TYPE_HUNK)
	{
		g_signal_emit(view, diff_view_signals[HUNK_ADDED], 0, &iter);
	}
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
	{
		return;
	}

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
		{
			break;
		}

		++view->priv->last_scan_line;

		if (!gtk_text_iter_forward_chars(&end, 3))
		{
			continue;
		}

		gchar *text = gtk_text_iter_get_text(&start, &end);

		if (g_str_has_prefix(text, "@@ ") || g_str_has_prefix (text, "@@@"))
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
		{
			continue;
		}

		text = gtk_text_iter_get_text(&start, &end);

		if (g_str_has_prefix(text, "diff --git") || g_str_has_prefix(text, "diff --cc"))
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
	{
		ensure_max_line(view, (Hunk *)view->priv->last_region);
	}
}

static Region *
find_current_region(GitgDiffView *view, guint line)
{
	GSequenceIter *iter;
	Region tmp = {0, NULL, NULL, line};

	iter = g_sequence_search(view->priv->regions_index, &tmp, index_compare, NULL);

	if (!iter || g_sequence_iter_is_begin(iter))
	{
		return NULL;
	}

	if (!g_sequence_iter_is_end(iter))
	{
		Region *ret = (Region *)g_sequence_get(iter); 

		if (ret->line == line)
		{
			return ret->visible ? ret : NULL;
		}
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
	{
		return FALSE;
	}

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
line_renderer_size_func (GtkSourceGutter *gutter,
                         GtkCellRenderer *cell,
                         GitgDiffView    *view)
{
	g_object_set (cell,
	              "line_old", view->priv->max_line_count,
	              "line_new", view->priv->max_line_count,
	              NULL);

	if (view->priv->label_func)
	{
		gchar *label = view->priv->label_func (view,
		                                       -1,
		                                       view->priv->label_func_user_data);

		g_object_set (cell, "label", label, NULL);
		g_free (label);
	}
}

static void
line_renderer_data_func (GtkSourceGutter *gutter,
                         GtkCellRenderer *cell,
                         gint             line_number,
                         gboolean         current_line,
                         GitgDiffView    *view)
{
	gint line_old = -1;
	gint line_new = -1;
	Region **current = &view->priv->lines_current_region;

	ensure_scan (view, line_number);

	if (!*current || view->priv->lines_previous_line + 1 != line_number)
	{
		*current = find_current_region (view, line_number);

		if (*current)
		{
			get_initial_counters (view,
			                      *current,
			                      line_number,
			                      view->priv->lines_counters);
		}
	}

	view->priv->lines_previous_line = line_number;

	if (*current &&
	    (*current)->type == GITG_DIFF_ITER_TYPE_HUNK &&
	    line_number != (*current)->line)
	{
		Hunk *hunk = (Hunk *)*current;

		if (draw_old (view, line_number))
		{
			line_old = hunk->old + view->priv->lines_counters[0]++;
		}

		if (draw_new (view, line_number))
		{
			line_new = hunk->new + view->priv->lines_counters[1]++;
		}
	}

	g_object_set (cell, "line_old", line_old, "line_new", line_new, NULL);

	if (*current && (*current)->next && line_number == (*current)->next->line - 1)
	{
		view->priv->lines_counters[0] = view->priv->lines_counters[1] = 0;
		*current = (*current)->next->visible ? (*current)->next : NULL;
	}

	if (view->priv->label_func)
	{
		gchar *label = view->priv->label_func (view,
		                                       line_number,
		                                       view->priv->label_func_user_data);

		g_object_set (cell, "label", label, NULL);
		g_free (label);
	}
}

static gint
gitg_diff_view_expose (GtkWidget      *widget,
                       GdkEventExpose *event)
{
	GitgDiffView *view = GITG_DIFF_VIEW (widget);

	/* Prepare for new round of expose on the line renderer */
	view->priv->lines_current_region = NULL;
	view->priv->lines_previous_line = -1;
	view->priv->lines_counters[0] = 0;
	view->priv->lines_counters[1] = 0;

	if (GTK_WIDGET_CLASS (gitg_diff_view_parent_class)->expose_event)
	{
		return GTK_WIDGET_CLASS (gitg_diff_view_parent_class)->expose_event (widget, event);
	}
	else
	{
		return FALSE;
	}
}

void
gitg_diff_view_set_diff_enabled(GitgDiffView *view, gboolean enabled)
{
	g_return_if_fail(GITG_IS_DIFF_VIEW(view));

	set_diff_enabled(view, enabled);

	g_object_notify(G_OBJECT(view), "diff-enabled");
}

static void
offset_regions (Region *region,
                gint    offset)
{
	while (region)
	{
		region->line += offset;
		region = region->next;
	}
}

static gint
compare_regions (Region   *first,
                 Region   *second,
                 gpointer  user_data)
{
	return first->line < second->line ? -1 : (first->line > second->line ? 1 : 0);
}

static GSequenceIter *
region_get_iter (GitgDiffView *view, Region *region)
{
	GSequenceIter *iter;

	iter = g_sequence_search (view->priv->regions_index,
	                          region,
	                          (GCompareDataFunc)compare_regions,
	                          NULL);

	if (g_sequence_iter_is_end (iter))
	{
		return g_sequence_iter_prev (iter);
	}
	else
	{
		Region *reg = g_sequence_get (iter);

		if (reg->line != region->line)
		{
			return g_sequence_iter_prev (iter);
		}
		else
		{
			return iter;
		}
	}
}

static void
remove_regions_sequence (GitgDiffView *view,
                         Region       *from,
                         Region       *to)
{
	GSequenceIter *start;
	GSequenceIter *end;

	start = region_get_iter (view, from);

	if (to)
	{
		end = g_sequence_iter_prev (region_get_iter (view, to));
	}
	else
	{
		end = g_sequence_get_end_iter (view->priv->regions_index);
	}

	g_sequence_remove_range (start, end);
}

static void
remove_regions (GitgDiffView *view, Region *from, Region *to)
{
	GtkTextBuffer *buffer;
	GtkTextIter start;
	GtkTextIter end;
	gint offset;

	buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));

	if (from->prev)
	{
		if (to)
		{
			from->prev->next = to;
			to->prev = from->prev;
		}
		else
		{
			from->prev->next = NULL;
		}
	}
	else
	{
		if (to)
		{
			view->priv->regions = to;
			to->prev = NULL;
		}
		else
		{
			view->priv->regions = NULL;
		}
	}

	if (!to)
	{
		view->priv->last_region = from->prev;
	}

	remove_regions_sequence (view, from, to);

	gtk_text_buffer_get_iter_at_line (buffer, &start, from->line);

	if (to)
	{
		gtk_text_buffer_get_iter_at_line (buffer, &end, to->line);
	}
	else
	{
		gtk_text_buffer_get_end_iter (buffer, &end);
	}

	/* Remove and free from sequence */
	while (from && from != to)
	{
		Region *next = from->next;

		//region_free (from);
		from = next;
	}

	offset = gtk_text_iter_get_line (&start) - gtk_text_iter_get_line (&end);

	offset_regions (to, offset);

	view->priv->ignore_changes = TRUE;
	gtk_text_buffer_begin_user_action (buffer);
	gtk_text_buffer_delete (buffer, &start, &end);
	gtk_text_buffer_end_user_action (buffer);
	view->priv->ignore_changes = FALSE;
}

void
gitg_diff_view_remove_hunk (GitgDiffView *view, GtkTextIter *iter)
{
	g_return_if_fail (GITG_IS_DIFF_VIEW (view));
	g_return_if_fail (iter != NULL);

	/* removes hunk at iter and if it was the last hunk of a file, also removes
	   the file header */
	Region *region = find_current_region (view,
	                                      gtk_text_iter_get_line (iter));

	if (!region)
	{
		return;
	}

	Region *from = region;
	Region *to = region->next;

	if (region->prev && region->prev->type == GITG_DIFF_ITER_TYPE_HEADER &&
	    (!to || to->type == GITG_DIFF_ITER_TYPE_HEADER))
	{
		/* also remove the header in this case */
		from = region->prev;
	}

	remove_regions (view, from, to);
}

gboolean
gitg_diff_view_get_start_iter(GitgDiffView *view, GitgDiffIter *iter)
{
	g_return_val_if_fail(GITG_IS_DIFF_VIEW(view), FALSE);
	g_return_val_if_fail(iter != NULL, FALSE);

	if (!view->priv->diff_enabled)
	{
		return FALSE;
	}

	region_to_iter (view, view->priv->regions, iter);
	return GITG_DIFF_ITER_GET_REGION (iter) != NULL;
}

gboolean
gitg_diff_iter_forward(GitgDiffIter *iter)
{
	g_return_val_if_fail(iter != NULL, FALSE);

	if (!GITG_DIFF_ITER_GET_REGION (iter))
	{
		return FALSE;
	}

	GITG_DIFF_ITER_SET_REGION (iter, GITG_DIFF_ITER_GET_REGION (iter)->next);

	return GITG_DIFF_ITER_GET_REGION (iter) != NULL;
}

gboolean
gitg_diff_view_get_end_iter(GitgDiffView *view, GitgDiffIter *iter)
{
	g_return_val_if_fail(GITG_IS_DIFF_VIEW(view), FALSE);
	g_return_val_if_fail(iter != NULL, FALSE);

	region_to_iter (view, view->priv->last_region, iter);

	return GITG_DIFF_ITER_GET_REGION (iter) != NULL;
}

gboolean
gitg_diff_iter_backward(GitgDiffIter *iter)
{
	g_return_val_if_fail(iter != NULL, FALSE);

	if (!GITG_DIFF_ITER_GET_REGION (iter))
	{
		return FALSE;
	}

	GITG_DIFF_ITER_SET_REGION (iter, GITG_DIFF_ITER_GET_REGION (iter)->prev);

	return GITG_DIFF_ITER_GET_REGION (iter) != NULL;

}

GitgDiffIterType 
gitg_diff_iter_get_type(GitgDiffIter *iter)
{
	g_return_val_if_fail (iter != NULL, 0);
	g_return_val_if_fail (GITG_IS_DIFF_VIEW (GITG_DIFF_ITER_GET_VIEW (iter)), 0);
	g_return_val_if_fail (GITG_DIFF_ITER_GET_REGION (iter) != NULL, 0);

	return GITG_DIFF_ITER_GET_REGION (iter)->type;
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
	g_return_if_fail (iter != NULL);
	g_return_if_fail (GITG_IS_DIFF_VIEW (GITG_DIFF_ITER_GET_VIEW (iter)));
	g_return_if_fail (GITG_DIFF_ITER_GET_REGION (iter) != NULL);

	GitgDiffView *view = GITG_DIFF_ITER_GET_VIEW (iter);
	Region *region = GITG_DIFF_ITER_GET_REGION (iter);

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

		if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
		{
			hide_header_details (view, region);
		}
	}
	else
	{
		if (region->type == GITG_DIFF_ITER_TYPE_HEADER)
		{
			gtk_text_buffer_remove_tag (view->priv->current_buffer, view->priv->subheader_tag, &start, &end);
		}

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
				gchar *bet = strstr(start, ",");

				if (!last)
					last = line + strlen(line);

				strncpy(header->index_from, start, (bet ? bet : sep) - start);
				strncpy(header->index_to, sep + 2, last - (sep + 2));

				header->index_from[(bet ? bet : sep) - start] = '\0';
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
gitg_diff_iter_get_index (GitgDiffIter  *iter,
                          gchar        **from,
                          gchar        **to)
{
	Region *region = GITG_DIFF_ITER_GET_REGION (iter);

	while (region && region->type != GITG_DIFF_ITER_TYPE_HEADER)
	{
		region = region->prev;
	}

	if (!region)
	{
		return FALSE;
	}

	Header *header = (Header *)region;
	gboolean ret = TRUE;

	if (!*(header->index_to))
	{
		ret = header_parse_index (GITG_DIFF_ITER_GET_VIEW (iter), header);
	}

	if (!ret)
	{
		return FALSE;
	}

	*from = header->index_from;
	*to = header->index_to;

	return TRUE;
}

static gboolean
iter_in_view (GitgDiffView *view,
              GtkTextIter  *iter)
{
	GtkTextIter start;
	GtkTextIter end;
	GdkRectangle rect;
	GtkTextView *textview = GTK_TEXT_VIEW (view);

	gtk_text_view_get_visible_rect (textview, &rect);
	gtk_text_view_get_iter_at_location (textview, &start, rect.x, rect.y);
	gtk_text_view_get_iter_at_location (textview, &end, rect.x + rect.width, rect.y + rect.height);

	return gtk_text_iter_in_range(iter, &start, &end) || gtk_text_iter_equal(iter, &end);
}

static gboolean
try_scan (GitgDiffView *view)
{
	gint lines = gtk_text_buffer_get_line_count (view->priv->current_buffer);

	if (view->priv->last_scan_line > lines)
	{
		return FALSE;
	}

	guint num = MIN (lines - view->priv->last_scan_line, IDLE_SCAN_COUNT);

	if (num == 0)
	{
		return FALSE;
	}

	gchar str[8];
	g_snprintf (str, sizeof (str), "%u", view->priv->max_line_count);
	guint max_line = strlen (str);

	guint last = view->priv->last_scan_line;
	ensure_scan (view, view->priv->last_scan_line + num);
	g_snprintf (str, sizeof (str), "%u", view->priv->max_line_count);

	if (strlen (str) > max_line)
	{
		gtk_widget_queue_draw (GTK_WIDGET (view));
	}

	return last != view->priv->last_scan_line;
}

static void
on_buffer_delete_range (GtkTextBuffer *buffer,
                        GtkTextIter   *start,
                        GtkTextIter   *end,
                        GitgDiffView  *view)
{
	if (view->priv->ignore_changes)
	{
		return;
	}

	regions_free (view);

	if (iter_in_view (view, start) || iter_in_view (view, end))
	{
		try_scan (view);
	}

	if (!view->priv->scan_id)
	{
		view->priv->scan_id = g_idle_add ((GSourceFunc)on_idle_scan,
		                                  view);
	}
}

static void
on_buffer_insert_text (GtkTextBuffer *buffer,
                       GtkTextIter   *iter,
                       gchar const   *text,
                       gint           len,
                       GitgDiffView  *view)
{
	if (view->priv->ignore_changes)
	{
		return;
	}

	/* if region is in current view and not scanned, issue scan now */
	if (iter_in_view (view, iter))
	{
		try_scan (view);
	}

	if (!view->priv->scan_id)
	{
		view->priv->scan_id = g_idle_add ((GSourceFunc)on_idle_scan, view);
	}
}

static gboolean
on_idle_scan (GitgDiffView *view)
{
	if (try_scan(view))
	{
		return TRUE;
	}

	view->priv->scan_id = 0;
	return FALSE;
}

gboolean
gitg_diff_view_get_header_at_iter (GitgDiffView *view,
                                   GtkTextIter const *iter,
                                   GitgDiffIter *diff_iter)
{
	g_return_val_if_fail (GITG_IS_DIFF_VIEW (view), FALSE);
	g_return_val_if_fail (iter != NULL, FALSE);
	g_return_val_if_fail (diff_iter != NULL, FALSE);

	if (!view->priv->diff_enabled)
	{
		return FALSE;
	}

	ensure_scan (view, gtk_text_iter_get_line (iter));

	Region *region = find_current_region (view, gtk_text_iter_get_line (iter));

	while (region && region->type == GITG_DIFF_ITER_TYPE_HUNK)
	{
		region = region->prev;
	}

	region_to_iter (view, region, diff_iter);
	return region != NULL && region->type == GITG_DIFF_ITER_TYPE_HEADER;
}

gboolean
gitg_diff_view_get_hunk_at_iter (GitgDiffView *view,
                                 GtkTextIter const *iter,
                                 GitgDiffIter *diff_iter)
{
	g_return_val_if_fail (GITG_IS_DIFF_VIEW (view), FALSE);
	g_return_val_if_fail (iter != NULL, FALSE);
	g_return_val_if_fail (diff_iter != NULL, FALSE);

	if (!view->priv->diff_enabled)
	{
		return FALSE;
	}

	ensure_scan (view, gtk_text_iter_get_line (iter));

	Region *region = find_current_region (view, gtk_text_iter_get_line (iter));

	if (region == NULL || region->type != GITG_DIFF_ITER_TYPE_HUNK)
	{
		return FALSE;
	}

	region_to_iter (view, region, diff_iter);
	return TRUE;
}

static void
region_get_bounds (GitgDiffView *view,
                   Region *region,
                   GtkTextIter *start,
                   GtkTextIter *end)
{
	gtk_text_buffer_get_iter_at_line (view->priv->current_buffer,
	                                  start,
	                                  region->line);

	if (region->next != NULL)
	{
		gtk_text_buffer_get_iter_at_line (view->priv->current_buffer,
		                                  end,
		                                  region->next->line);
	}
	else
	{
		gtk_text_buffer_get_end_iter (view->priv->current_buffer,
		                              end);
	}
}

void
gitg_diff_iter_get_bounds (GitgDiffIter const *iter,
                           GtkTextIter *start,
                           GtkTextIter *end)
{
	g_return_if_fail (iter != NULL);
	g_return_if_fail (GITG_IS_DIFF_VIEW (GITG_DIFF_ITER_GET_VIEW (iter)));
	g_return_if_fail (GITG_DIFF_ITER_GET_REGION (iter) != NULL);
	g_return_if_fail (start != NULL);
	g_return_if_fail (end != NULL);

	GitgDiffView *view = GITG_DIFF_ITER_GET_VIEW (iter);
	Region *region = GITG_DIFF_ITER_GET_REGION (iter);

	region_get_bounds (view, region, start, end);
}

GitgDiffLineType
gitg_diff_view_get_line_type (GitgDiffView *view, GtkTextIter const *iter)
{
	g_return_val_if_fail (GITG_IS_DIFF_VIEW (view), GITG_DIFF_LINE_TYPE_NONE);
	g_return_val_if_fail (iter != NULL, GITG_DIFF_LINE_TYPE_NONE);

	if (!view->priv->diff_enabled)
	{
		return GITG_DIFF_LINE_TYPE_NONE;
	}

	GitgDiffIter diff_iter;

	if (!gitg_diff_view_get_hunk_at_iter (view, iter, &diff_iter))
	{
		return GITG_DIFF_LINE_TYPE_NONE;
	}

	GtkTextIter start = *iter;
	gtk_text_iter_set_line_offset (&start, 0);

	gunichar ch = gtk_text_iter_get_char (&start);

	switch (ch)
	{
		case '+':
			return GITG_DIFF_LINE_TYPE_ADD;
		case '-':
			return GITG_DIFF_LINE_TYPE_REMOVE;
		default:
			return GITG_DIFF_LINE_TYPE_NONE;
	}
}

static void
calculate_hunk_header_counters (GitgDiffView *view,
                                Region       *region)
{
	GtkTextIter start;
	GtkTextIter end;
	GtkTextIter begin;

	GtkTextBuffer *buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));

	region_get_bounds (view, region, &start, &end);

	begin = start;

	guint new_count = 0;
	guint old_count = 0;

	gboolean isempty = TRUE;

	if (gtk_text_iter_forward_line (&start))
	{
		while (gtk_text_iter_compare (&start, &end) < 0)
		{
			GitgDiffLineType line_type;
			GtkTextIter line_end = start;

			gtk_text_iter_forward_to_line_end (&line_end);

			line_type = gitg_diff_view_get_line_type (view, &start);

			if (line_type == GITG_DIFF_LINE_TYPE_NONE ||
			    line_type == GITG_DIFF_LINE_TYPE_ADD)
			{
				++new_count;
			}

			if (line_type == GITG_DIFF_LINE_TYPE_NONE ||
			    line_type == GITG_DIFF_LINE_TYPE_REMOVE)
			{
				++old_count;
			}

			if (line_type != GITG_DIFF_LINE_TYPE_NONE)
			{
				isempty = FALSE;
			}

			if (!gtk_text_iter_forward_line (&start))
			{
				break;
			}
		}
	}

	if (isempty)
	{
		gitg_diff_view_remove_hunk (view, &begin);
	}
	else
	{
		end = begin;
		gtk_text_iter_forward_to_line_end (&end);

		gchar *header = gtk_text_buffer_get_text (buffer, &begin, &end, TRUE);
		gchar *ret;

		ret = gitg_utils_rewrite_hunk_counters (header, old_count, new_count);
		g_free (header);

		gtk_text_buffer_delete (buffer, &begin, &end);
		gtk_text_buffer_insert (buffer, &begin, ret, -1);

		g_free (ret);
	}
}

void
gitg_diff_view_clear_line (GitgDiffView *view,
                           GtkTextIter const *iter,
                           GitgDiffLineType old_type,
                           GitgDiffLineType new_type)
{
	g_return_if_fail (GITG_IS_DIFF_VIEW (view));
	g_return_if_fail (iter != NULL);

	GitgDiffLineType line_type;
	GitgDiffIter diff_iter;

	line_type = gitg_diff_view_get_line_type (view, iter);

	if (line_type == GITG_DIFF_LINE_TYPE_NONE)
	{
		return;
	}

	gitg_diff_view_get_hunk_at_iter (view, iter, &diff_iter);

	GtkTextIter start = *iter;
	GtkTextIter end;
	GtkTextBuffer *buffer;
	Region *region;

	buffer = gtk_text_view_get_buffer (GTK_TEXT_VIEW (view));

	gtk_text_iter_set_line_offset (&start, 0);
	end = start;

	gtk_text_buffer_begin_user_action (buffer);
	view->priv->ignore_changes = TRUE;

	region = GITG_DIFF_ITER_GET_REGION (&diff_iter);

	if (line_type == new_type)
	{
		/* means the line now just becomes context */
		gtk_text_iter_forward_char (&end);
		gtk_text_buffer_delete (buffer, &start, &end);
		gtk_text_buffer_insert (buffer, &start, " ", 1);
	}
	else
	{
		/* means the line should be removed */
		if (!gtk_text_iter_forward_line (&end))
		{
			gtk_text_iter_forward_to_line_end (&end);
		}

		gtk_text_buffer_delete (buffer, &start, &end);
		offset_regions (region->next, -1);
	}

	calculate_hunk_header_counters (view, region);

	view->priv->ignore_changes = FALSE;
	gtk_text_buffer_end_user_action (buffer);
}

void
gitg_diff_view_set_label_func (GitgDiffView *view,
                               GitgDiffViewLabelFunc func,
                               gpointer user_data,
                               GDestroyNotify destroy_notify)
{
	g_return_if_fail (GITG_IS_DIFF_VIEW (view));

	if (view->priv->label_func &&
	    view->priv->label_func_destroy_notify)
	{
		view->priv->label_func_destroy_notify (view->priv->label_func_user_data);
	}

	view->priv->label_func = func;
	view->priv->label_func_user_data = user_data;
	view->priv->label_func_destroy_notify = destroy_notify;
}
