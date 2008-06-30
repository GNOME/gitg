#include <math.h>
#include "gitg-cell-renderer-path.h"

#define GITG_CELL_RENDERER_PATH_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_CELL_RENDERER_PATH, GitgCellRendererPathPrivate))

#define DEFAULT_DOT_WIDTH 8
#define DEFAULT_COLUMN_WIDTH (DEFAULT_DOT_WIDTH + 6)

/* Properties */
enum
{
	PROP_0,
	
	PROP_COLUMN,
	PROP_COLUMNS,
	PROP_COLUMN_WIDTH,
	PROP_DOT_WIDTH
};

struct _GitgCellRendererPathPrivate
{
	gint8 column;
	gint8 *columns;
	guint column_width;
	guint dot_width;
};

static GtkCellRendererTextClass *parent_class = NULL;

G_DEFINE_TYPE(GitgCellRendererPath, gitg_cell_renderer_path, GTK_TYPE_CELL_RENDERER_TEXT)

static gint
num_columns(GitgCellRendererPath *self)
{
	gint ret = 1;
	gint8 *ptr = self->priv->columns;
	
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
	return num_columns(self) * self->priv->column_width;
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
		*width = num_columns(self) * self->priv->column_width;
	
	if (height)
		*height = area ? area->height : 1;
}

static void
draw_paths(GitgCellRendererPath *self, cairo_t *cr, GdkRectangle *area)
{
	gint8 *ptr = self->priv->columns;
	gint8 to = 0;
	gdouble cw = self->priv->column_width;
	
	cairo_set_line_width(cr, 1.0);
	cairo_set_source_rgb(cr, 0.0, 0.0, 1.0);
	
	while (ptr && *ptr != -2)
	{
		if (*ptr == -1)
		{
			++to;
		}
		else
		{
			gint8 from = *ptr;
		
			cairo_move_to(cr, area->x + from * cw + cw / 2.0, area->y);
			cairo_line_to(cr, area->x + to * cw + cw / 2.0, area->y + area->height / 2.0);
			cairo_stroke(cr);
		}
				
		++ptr;
	}
}

static void
renderer_render(GtkCellRenderer *renderer, GdkDrawable *window, GtkWidget *widget, GdkRectangle *area, GdkRectangle *cell_area, GdkRectangle *expose_area, GtkCellRendererState flags)
{
	GitgCellRendererPath *self = GITG_CELL_RENDERER_PATH(renderer);

	cairo_t *cr = gdk_cairo_create(window);
	
	draw_paths(self, cr, area);
	
	gdouble offset = self->priv->column * self->priv->column_width + (self->priv->column_width - self->priv->dot_width) / 2.0;
	gdouble radius = self->priv->dot_width / 2.0;
	
	cairo_set_line_width(cr, 1.0);
	cairo_arc(cr, area->x + offset + radius, area->y + area->height / 2.0, radius, 0, 2 * M_PI);
	cairo_set_source_rgb(cr, 0.6, 0.6, 0.6);
	
	cairo_stroke_preserve(cr);
	cairo_set_source_rgb(cr, 0.3, 0.6, 0.8);
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
		case PROP_COLUMN:
			g_value_set_uint(value, self->priv->column);
		break;
		case PROP_COLUMNS:
			g_value_set_pointer(value, self->priv->columns);
		break;
		case PROP_COLUMN_WIDTH:
			g_value_set_uint(value, self->priv->column_width);
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
		case PROP_COLUMN:
			self->priv->column = g_value_get_int(value);
		break;
		case PROP_COLUMNS:
			self->priv->columns = (gint8 *)g_value_get_pointer(value);
			//g_object_set(object, "width", total_width(self), NULL);
		break;
		case PROP_COLUMN_WIDTH:
			self->priv->column_width = g_value_get_uint(value);
			//g_object_set(object, "width", total_width(self), NULL);
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

	g_object_class_install_property(object_class, PROP_COLUMN,
					 g_param_spec_int("column",
							      "COLUMN",
							      "The column",
							      0,
							      G_MAXINT,
							      0,
							      G_PARAM_READWRITE));

	g_object_class_install_property(object_class, PROP_COLUMNS,
					 g_param_spec_pointer("columns",
							      "COLUMNS",
							      "All columns",
							      G_PARAM_READWRITE));
	
	g_object_class_install_property(object_class, PROP_COLUMN_WIDTH,
					 g_param_spec_uint("column-width",
							      "COLUMN WIDTH",
							      "The column width",
							      0,
							      G_MAXUINT,
							      DEFAULT_COLUMN_WIDTH,
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
	
	self->priv->column_width = DEFAULT_COLUMN_WIDTH;
	self->priv->dot_width = DEFAULT_DOT_WIDTH;
}

GtkCellRenderer *
gitg_cell_renderer_path_new()
{
	return GTK_CELL_RENDERER(g_object_new(GITG_TYPE_CELL_RENDERER_PATH, NULL));
}
