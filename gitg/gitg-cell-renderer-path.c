#include <math.h>
#include "gitg-cell-renderer-path.h"

#define GITG_CELL_RENDERER_PATH_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathPrivate))

#define DEFAULT_DOT_WIDTH 10
#define DEFAULT_LANE_WIDTH (DEFAULT_DOT_WIDTH + 6)

/* Properties */
enum
{
	PROP_0,
	
	PROP_LANE,
	PROP_LANES,
	PROP_NEXT_LANES,
	PROP_LANE_WIDTH,
	PROP_DOT_WIDTH
};

struct _GitgCellRendererPathPrivate
{
	gint8 lane;
	gint8 *lanes;
	gint8 *next_lanes;
	guint lane_width;
	guint dot_width;
};

static GtkCellRendererTextClass *parent_class = NULL;

G_DEFINE_TYPE(GitgCellRendererPath, gitg_cell_renderer_path, GTK_TYPE_CELL_RENDERER_TEXT)

static gint
num_lanes(GitgCellRendererPath *self)
{
	gint ret = 1;
	gint8 *ptr = self->priv->lanes;
	
	while (ptr && *ptr != -2)
	{
		if (*ptr++ == -1)
			++ret;
	}

	return ret;
}

inline static gint
total_width(GitgCellRendererPath *self)
{
	return num_lanes(self) * self->priv->lane_width;
}

static void
gitg_cell_renderer_path_finalize(GObject *object)
{
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
		*width = num_lanes(self) * self->priv->lane_width;
	
	if (height)
		*height = area ? area->height : 1;
}

static void
draw_paths_real(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area, gint8 *lanes, gboolean top, gdouble yoffset)
{
	if (!lanes)
		return;

	gint8 to = 0;
	gdouble cw = self->priv->lane_width;
	gdouble ch = area->height / 2.0;

	for (; *lanes != -2; ++lanes)
	{
		if (*lanes == -1)
		{
			++to;
			continue;
		}
		
		gint8 from = *lanes;
		gdouble xf = 0.0;
		
		if (from != to)
			xf = 0.5 * (to - from);
		
		cairo_move_to(cr, area->x + (from + (top ? xf : 0)) * cw + cw / 2.0, area->y + yoffset * ch);
		cairo_line_to(cr, area->x + (to - (top ? 0 : xf)) * cw + cw / 2.0, area->y + (yoffset + 1) * ch);
		cairo_stroke(cr);
	}
}

static void
draw_top_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	draw_paths_real(self, cr, area, self->priv->lanes, TRUE, 0);
}

static void
draw_bottom_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	draw_paths_real(self, cr, area, self->priv->next_lanes, FALSE, 1);
}

static void
draw_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	cairo_set_line_width(cr, 1.5);
	cairo_set_source_rgb(cr, 0.45, 0.6, 0.74);
	
	draw_top_paths(self, cr, area);
	draw_bottom_paths(self, cr, area);
}

static void
renderer_render(GtkCellRenderer *renderer, GdkDrawable *window, GtkWidget *widget, GdkRectangle *area, GdkRectangle *cell_area, GdkRectangle *expose_area, GtkCellRendererState flags)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(renderer);

	cairo_t *cr = gdk_cairo_create(window);
	
	draw_paths(self, cr, area);
	
	gdouble offset = self->priv->lane * self->priv->lane_width + (self->priv->lane_width - self->priv->dot_width) / 2.0;
	gdouble radius = self->priv->dot_width / 2.0;
	
	cairo_set_line_width(cr, 2.0);
	cairo_arc(cr, area->x + offset + radius, area->y + area->height / 2.0, radius, 0, 2 * M_PI);
	cairo_set_source_rgb(cr, 0.12, 0.24, 0.36);
	
	cairo_stroke_preserve(cr);
	cairo_set_source_rgb(cr, 0.3, 0.6, 0.7);
	cairo_fill(cr);

	cairo_destroy(cr);
	
	area->x += total_width(self);
	cell_area->x += total_width(self);

	if (GTK_CELL_RENDERER_CLASS(parent_class)->render)
		GTK_CELL_RENDERER_CLASS(parent_class)->render(renderer, window, widget, area, cell_area, expose_area, flags);
}

static void
gitg_cell_renderer_path_get_property(GObject *object, guint prop_id, GValue *value, GParamSpec *pspec)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(object);

	switch (prop_id)
	{
		case PROP_LANE:
			g_value_set_uint(value, self->priv->lane);
		break;
		case PROP_LANES:
			g_value_set_pointer(value, self->priv->lanes);
		break;
		case PROP_NEXT_LANES:
			g_value_set_pointer(value, self->priv->next_lanes);
		break;
		case PROP_LANE_WIDTH:
			g_value_set_uint(value, self->priv->lane_width);
		break;
		case PROP_DOT_WIDTH:
			g_value_set_uint(value, self->priv->dot_width);
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
		case PROP_LANE:
			self->priv->lane = g_value_get_int(value);
		break;
		case PROP_LANES:
			self->priv->lanes = (gint8 *)g_value_get_pointer(value);
		break;
		case PROP_NEXT_LANES:
			self->priv->next_lanes = (gint8 *)g_value_get_pointer(value);
		break;
		case PROP_LANE_WIDTH:
			self->priv->lane_width = g_value_get_uint(value);
		break;
		case PROP_DOT_WIDTH:
			self->priv->dot_width = g_value_get_uint(value);
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

	g_object_class_install_property(object_class, PROP_LANE,
					 g_param_spec_int("lane",
							      "LANE",
							      "The lane",
							      0,
							      G_MAXINT,
							      0,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_LANES,
					 g_param_spec_pointer("lanes",
							      "LANES",
							      "All lanes",
							      G_PARAM_READWRITE));
	
	g_object_class_install_property(object_class, PROP_NEXT_LANES,
					 g_param_spec_pointer("next-lanes",
							      "NEXT LANES",
							      "All next lanes",
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

	g_type_class_add_private(object_class, sizeof(GitgCellRendererPathPrivate));
}

static void
gitg_cell_renderer_path_init(GitgCellRendererPath *self)
{
	self->priv = GITG_CELL_RENDERER_PATH_GET_PRIVATE(self);
	
	self->priv->lane_width = DEFAULT_LANE_WIDTH;
	self->priv->dot_width = DEFAULT_DOT_WIDTH;
}

GtkCellRenderer *
gitg_cell_renderer_path_new()
{
	return GTK_CELL_RENDERER(g_object_new(GITG_TYPE_CELL_RENDERER_PATH, NULL));
}
