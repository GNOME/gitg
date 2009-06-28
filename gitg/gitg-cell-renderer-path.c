/*
 * gitg-cell-renderer-path.c
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

#include <math.h>
#include "gitg-cell-renderer-path.h"
#include "gitg-lane.h"
#include "gitg-utils.h"
#include "gitg-label-renderer.h"

#define GITG_CELL_RENDERER_PATH_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathPrivate))

#define DEFAULT_DOT_WIDTH 10
#define DEFAULT_TRIANGLE_WIDTH 8

#define DEFAULT_LANE_WIDTH (DEFAULT_DOT_WIDTH + 6)

/* Properties */
enum
{
	PROP_0,
	
	PROP_REVISION,
	PROP_NEXT_REVISION,
	PROP_LANE_WIDTH,
	PROP_DOT_WIDTH,
	PROP_TRIANGLE_WIDTH,
	PROP_LABELS
};

struct _GitgCellRendererPathPrivate
{
	GitgRevision *revision;
	GitgRevision *next_revision;
	GSList *labels;
	guint lane_width;
	guint triangle_width;
	guint dot_width;
	
	gint last_height;
};

static GtkCellRendererTextClass *parent_class = NULL;

G_DEFINE_TYPE(GitgCellRendererPath, gitg_cell_renderer_path, GTK_TYPE_CELL_RENDERER_TEXT)

static gint
num_lanes(GitgCellRendererPath *self)
{
	return g_slist_length (gitg_revision_get_lanes(self->priv->revision));
}

static gboolean
is_dummy(GitgRevision *revision)
{
	switch (gitg_revision_get_sign(revision))
	{
		case 's':
		case 't':
		case 'u':
			return TRUE;
		default:
			return FALSE;
	}
}

static gint
total_width(GitgCellRendererPath *self, GtkWidget *widget)
{
	PangoFontDescription *font;
	g_object_get(self, "font-desc", &font, NULL);
	
	gint offset = 0;
	
	if (is_dummy(self->priv->revision))
		offset = self->priv->lane_width;
	
	return num_lanes(self) * self->priv->lane_width + 
	       gitg_label_renderer_width(widget, font, self->priv->labels) +
	       offset;
}

static void
gitg_cell_renderer_path_finalize(GObject *object)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(object);
	
	gitg_revision_unref(self->priv->revision);
	gitg_revision_unref(self->priv->next_revision);
	
	g_slist_free(self->priv->labels);

	G_OBJECT_CLASS(gitg_cell_renderer_path_parent_class)->finalize(object);
}

static void
renderer_get_size(GtkCellRenderer *renderer, GtkWidget *widget, GdkRectangle *area, gint *xoffset, gint *yoffset, gint *width, gint *height)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(renderer);

	if (xoffset)
		*xoffset = 0;
	
	if (yoffset)
		*yoffset = 0;
	
	if (width)
		*width = total_width(self, widget);
	
	if (height)
		*height = area ? area->height : 1;
}

static void
draw_arrow(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area, gint8 laneidx, gboolean top)
{
	gdouble cw = self->priv->lane_width;
	gdouble xpos = area->x + laneidx * cw + cw / 2.0;
	gdouble df = (top ? -1 : 1) * 0.25 * area->height;
	gdouble ypos = area->y + area->height / 2.0 + df;
	gdouble q = cw / 4.0;
	
	cairo_move_to(cr, xpos - q, ypos + (top ? q : -q));
	cairo_line_to(cr, xpos, ypos);
	cairo_line_to(cr, xpos + q, ypos + (top ? q : -q));
	cairo_stroke(cr);
	
	cairo_move_to(cr, xpos, ypos);
	cairo_line_to(cr, xpos, ypos - df);
	cairo_stroke(cr);
	
	//cairo_move_to(cr, xpos, ypos);
	//cairo_line_to(cr, xpos, ypos + (top ? 1 : -1) * area->height / 2.0);
	//cairo_stroke(cr);
}

static void
draw_paths_real(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area, GitgRevision *revision, gdouble yoffset)
{
	if (!revision)
		return;

	GSList *lanes = gitg_revision_get_lanes(revision);
	gint8 to = 0;
	gdouble cw = self->priv->lane_width;
	gdouble ch = area->height / 2.0;
	GitgLane *lane;
	
	while (lanes)
	{
		GSList *item;

		lane = (GitgLane *)(lanes->data);
		gitg_color_set_cairo_source(lane->color, cr);
		
		for (item = lane->from; item; item = item->next)
		{
			gint8 from = (gint8)GPOINTER_TO_INT(item->data);
			
			cairo_move_to(cr, area->x + from * cw + cw / 2.0, area->y + yoffset * ch);
			cairo_curve_to(cr, area->x + from * cw + cw / 2.0, area->y + (yoffset + 1) * ch,
						   area->x + to * cw + cw / 2.0, area->y + (yoffset + 1) * ch,
						   area->x + to * cw + cw / 2.0, area->y + (yoffset + 2) * ch);
			
			cairo_stroke(cr);
		}

		++to;
		lanes = lanes->next;
	}
}

static void
draw_top_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	draw_paths_real(self, cr, area, self->priv->revision, -1);
}

static void
draw_bottom_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	draw_paths_real(self, cr, area, self->priv->next_revision, 1);
}

static void
draw_arrows(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	GSList *item;
	gint8 to = 0;
	
	for (item = gitg_revision_get_lanes(self->priv->revision); item; item = item->next)
	{
		GitgLane *lane = (GitgLane *)item->data;
		gitg_color_set_cairo_source(lane->color, cr);
		
		if (lane->type & GITG_LANE_TYPE_START)
			draw_arrow(self, cr, area, to, TRUE);
		else if (lane->type & GITG_LANE_TYPE_END)
			draw_arrow(self, cr, area, to, FALSE);
		
		++to;
	}
}

static void
draw_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	cairo_set_line_width(cr, 2);
	//cairo_set_source_rgb(cr, 0.45, 0.6, 0.74);
	cairo_set_line_cap(cr, CAIRO_LINE_CAP_ROUND);

	draw_top_paths(self, cr, area);
	draw_bottom_paths(self, cr, area);
	draw_arrows(self, cr, area);
}

static void
draw_labels(GitgCellRendererPath *self, GtkWidget *widget, cairo_t *context, GdkRectangle *area)
{
	gint offset = num_lanes(self) * self->priv->lane_width;
	PangoFontDescription *font;
	
	if (is_dummy(self->priv->revision))
		offset += self->priv->lane_width;
	
	g_object_get(self, "font-desc", &font, NULL);
	
	cairo_translate(context, offset, 0.0);
	gitg_label_renderer_draw(widget, font, context, self->priv->labels, area);
}

static void
draw_indicator_triangle(GitgCellRendererPath *self, GitgLane *lane, cairo_t *context, GdkRectangle *area)
{
	gdouble offset = gitg_revision_get_mylane(self->priv->revision) * self->priv->lane_width + (self->priv->lane_width - self->priv->triangle_width) / 2.0;
	gdouble radius = self->priv->triangle_width / 2.0;
	gdouble xs;
	int xd;
	
	if (lane->type & GITG_LANE_SIGN_LEFT)
	{
		xs = radius;
		xd = -1;
	}
	else
	{
		xs = -radius;
		xd = 1;
	}
	
	cairo_set_line_width(context, 2.0);
	cairo_move_to(context, area->x + offset + radius + xs, area->y + (area->height - self->priv->triangle_width) / 2);
	cairo_rel_line_to(context, 0, self->priv->triangle_width);
	cairo_rel_line_to(context, xd * self->priv->triangle_width, -self->priv->triangle_width / 2);
	cairo_close_path(context);
	
	cairo_set_source_rgb(context, 0, 0, 0);
	cairo_stroke_preserve(context);

	gitg_color_set_cairo_source(lane->color, context);
	cairo_fill(context);
}

static void
draw_indicator_circle(GitgCellRendererPath *self, GitgLane *lane, cairo_t *context, GdkRectangle *area)
{
	gdouble offset = gitg_revision_get_mylane(self->priv->revision) * self->priv->lane_width + (self->priv->lane_width - self->priv->dot_width) / 2.0;
	gdouble radius = self->priv->dot_width / 2.0;
	
	if (is_dummy(self->priv->revision))
		offset += self->priv->lane_width;

	cairo_set_line_width(context, 2.0);
	cairo_arc(context, area->x + offset + radius, area->y + area->height / 2.0, radius, 0, 2 * M_PI);
	cairo_set_source_rgb(context, 0, 0, 0);
	
	if (is_dummy(self->priv->revision))
	{
		cairo_stroke(context);
	}
	else
	{
		cairo_stroke_preserve(context);
		gitg_color_set_cairo_source(lane->color, context);
	
		cairo_fill(context);
	}
}

static void
draw_indicator(GitgCellRendererPath *self, cairo_t *context, GdkRectangle *area)
{
	GitgLane *lane = gitg_revision_get_lane(self->priv->revision);
	
	if (lane->type & GITG_LANE_SIGN_LEFT || lane->type & GITG_LANE_SIGN_RIGHT)
		draw_indicator_triangle(self, lane, context, area);
	else
		draw_indicator_circle(self, lane, context, area);
}

static void
renderer_render(GtkCellRenderer *renderer, GdkDrawable *window, GtkWidget *widget, GdkRectangle *area, GdkRectangle *cell_area, GdkRectangle *expose_area, GtkCellRendererState flags)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(renderer);
	
	self->priv->last_height = area->height;

	cairo_t *cr = gdk_cairo_create(window);
	
	cairo_rectangle(cr, area->x, area->y, area->width, area->height);
	cairo_clip(cr);
	
	draw_paths(self, cr, area);
	
	/* draw indicator */
	draw_indicator(self, cr, area);
	
	/* draw labels */
	draw_labels(self, widget, cr, area);
	cairo_destroy(cr);
	
	area->x += total_width(self, widget);
	cell_area->x += total_width(self, widget);

	if (GTK_CELL_RENDERER_CLASS(parent_class)->render)
		GTK_CELL_RENDERER_CLASS(parent_class)->render(renderer, window, widget, area, cell_area, expose_area, flags);
}

static void
gitg_cell_renderer_path_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(object);

	switch (prop_id)
	{
		case PROP_REVISION:
			g_value_set_boxed(value, self->priv->revision);
		break;
		case PROP_NEXT_REVISION:
			g_value_set_boxed(value, self->priv->next_revision);
		break;
		case PROP_LANE_WIDTH:
			g_value_set_uint(value, self->priv->lane_width);
		break;
		case PROP_DOT_WIDTH:
			g_value_set_uint(value, self->priv->dot_width);
		break;
		case PROP_TRIANGLE_WIDTH:
			g_value_set_uint(value, self->priv->triangle_width);
		break;
		case PROP_LABELS:
			g_value_set_pointer(value, self->priv->labels);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_cell_renderer_path_set_property(GObject *object, guint prop_id, const GValue *value, GParamSpec *pspec)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(object);
	
	switch (prop_id)
	{
		case PROP_REVISION:
			gitg_revision_unref(self->priv->revision);
			self->priv->revision = g_value_dup_boxed(value);
		break;
		case PROP_NEXT_REVISION:
			gitg_revision_unref(self->priv->next_revision);
			self->priv->next_revision = g_value_dup_boxed(value);
		break;
		case PROP_LANE_WIDTH:
			self->priv->lane_width = g_value_get_uint(value);
		break;
		case PROP_DOT_WIDTH:
			self->priv->dot_width = g_value_get_uint(value);
		break;
		case PROP_TRIANGLE_WIDTH:
			self->priv->triangle_width = g_value_get_uint(value);
		break;
		case PROP_LABELS:
			g_slist_free(self->priv->labels);
			self->priv->labels = (GSList *)g_value_get_pointer(value);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID(object, prop_id, pspec);
		break;
	}
}

static void
gitg_cell_renderer_path_class_init(GitgCellRendererPathClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	GtkCellRendererClass *renderer_class = GTK_CELL_RENDERER_CLASS(klass);
	
	object_class->finalize = gitg_cell_renderer_path_finalize;
	object_class->get_property = gitg_cell_renderer_path_get_property;
	object_class->set_property = gitg_cell_renderer_path_set_property;
	
	renderer_class->get_size = renderer_get_size;
	renderer_class->render = renderer_render;

	parent_class = g_type_class_peek_parent(klass);

	g_object_class_install_property(object_class, PROP_REVISION,
					 g_param_spec_boxed("revision",
							      "REVISION",
							      "The revision",
							      GITG_TYPE_REVISION,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_NEXT_REVISION,
					 g_param_spec_boxed("next-revision",
							      "NEXT_REVISION",
							      "The next revision",
							      GITG_TYPE_REVISION,
							      G_PARAM_READWRITE));	

	g_object_class_install_property(object_class, PROP_LANE_WIDTH,
					 g_param_spec_uint("lane-width",
							      "LANE WIDTH",
							      "The lane width",
							      0,
							      G_MAXUINT,
							      DEFAULT_LANE_WIDTH,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_DOT_WIDTH,
					 g_param_spec_uint("dot-width",
							      "DOT WIDTH",
							      "The dot width",
							      0,
							      G_MAXUINT,
							      DEFAULT_DOT_WIDTH,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_TRIANGLE_WIDTH,
					 g_param_spec_uint("triangle-width",
							      "TRIANGLE WIDTH",
							      "The triangle width",
							      0,
							      G_MAXUINT,
							      DEFAULT_TRIANGLE_WIDTH,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_LABELS,
					 g_param_spec_pointer("labels",
							      "LABELS",
							      "Labels",
							      G_PARAM_READWRITE));

	g_type_class_add_private(object_class, sizeof(GitgCellRendererPathPrivate));
}

static void
gitg_cell_renderer_path_init(GitgCellRendererPath *self)
{
	self->priv = GITG_CELL_RENDERER_PATH_GET_PRIVATE(self);
	
	self->priv->lane_width = DEFAULT_LANE_WIDTH;
	self->priv->dot_width = DEFAULT_DOT_WIDTH;
	self->priv->triangle_width = DEFAULT_TRIANGLE_WIDTH;
}

GtkCellRenderer *
gitg_cell_renderer_path_new()
{
	return GTK_CELL_RENDERER(g_object_new(GITG_TYPE_CELL_RENDERER_PATH, NULL));
}

GitgRef *
gitg_cell_renderer_path_get_ref_at_pos (GtkWidget *widget, GitgCellRendererPath *renderer, gint x, gint *hot_x)
{
	g_return_val_if_fail (GTK_IS_WIDGET (widget), NULL);
	g_return_val_if_fail (GITG_IS_CELL_RENDERER_PATH (renderer), NULL);
	
	PangoFontDescription *font;
	g_object_get (renderer, "font-desc", &font, NULL);
	
	gint offset = 0;
	
	if (is_dummy(renderer->priv->revision))
		offset = renderer->priv->lane_width;
	
	x -= num_lanes(renderer) * renderer->priv->lane_width + offset;

	return gitg_label_renderer_get_ref_at_pos (widget, font, renderer->priv->labels, x, hot_x);
}

GdkPixbuf *
gitg_cell_renderer_path_render_ref (GtkWidget *widget, GitgCellRendererPath *renderer, GitgRef *ref, gint minwidth)
{
	g_return_val_if_fail (GTK_IS_WIDGET (widget), NULL);
	g_return_val_if_fail (GITG_IS_CELL_RENDERER_PATH (renderer), NULL);

	PangoFontDescription *font;
	g_object_get(renderer, "font-desc", &font, NULL);
	
	return gitg_label_renderer_render_ref (widget, font, ref, renderer->priv->last_height, minwidth);
}
