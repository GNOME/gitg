#include "gitg-stat-view.h"

#include "gitg-utils.h"
#include <math.h>
#include <cairo.h>

#define GITG_STAT_VIEW_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_STAT_VIEW, GitgStatViewPrivate))

enum
{
	PROP_0,
	PROP_LINES_ADDED,
	PROP_LINES_REMOVED,
	PROP_MAX_LINES
};

struct _GitgStatViewPrivate
{
	gdouble color_added[3];
	gdouble color_removed[3];

	cairo_pattern_t *gradient_added;
	cairo_pattern_t *gradient_removed;

	guint lines_added;
	guint lines_removed;
	guint max_lines;

	guint radius;
	guint stat_padding;
	gboolean show_lines;
	guint lines_spacing;
};

G_DEFINE_TYPE (GitgStatView, gitg_stat_view, GTK_TYPE_DRAWING_AREA)

static void
clear_gradients (GitgStatView *view)
{
	if (view->priv->gradient_added)
	{
		cairo_pattern_destroy (view->priv->gradient_added);
		view->priv->gradient_added = NULL;
	}

	if (view->priv->gradient_removed)
	{
		cairo_pattern_destroy (view->priv->gradient_removed);
		view->priv->gradient_removed = NULL;
	}
}

static void
gitg_stat_view_finalize (GObject *object)
{
	GitgStatView *view = GITG_STAT_VIEW (object);

	clear_gradients (view);

	G_OBJECT_CLASS (gitg_stat_view_parent_class)->finalize (object);
}

static void
update_colors (GitgStatView *view)
{
	GtkStyle *style;
	GdkColor bg_color;
	gdouble r, g, b;
	gdouble hue, sat, val;

	if (!gtk_widget_get_realized (GTK_WIDGET (view)))
	{
		return;
	}

	style = gtk_widget_get_style (GTK_WIDGET (view));
	bg_color = style->base[gtk_widget_get_state (GTK_WIDGET (view))];

	r = bg_color.red / 65535.0;
	g = bg_color.green / 65535.0;
	b = bg_color.blue / 65535.0;

	gtk_rgb_to_hsv (r, g, b, &hue, &sat, &val);

	sat = MIN(sat * 0.5 + 0.5, 1);
	val = MIN((pow(val + 1, 3) - 1) / 7 * 0.6 + 0.2, 1);

	gtk_hsv_to_rgb (0,
	                sat,
	                val,
	                &(view->priv->color_removed[0]),
	                &(view->priv->color_removed[1]),
	                &(view->priv->color_removed[2]));

	gtk_hsv_to_rgb (0.3,
	                sat,
	                val,
	                &(view->priv->color_added[0]),
	                &(view->priv->color_added[1]),
	                &(view->priv->color_added[2]));

	clear_gradients (view);
}

static void
gitg_stat_view_realize (GtkWidget *widget)
{
	if (GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->realize)
	{
		GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->realize (widget);
	}

	update_colors (GITG_STAT_VIEW (widget));
}

static void
update_styles (GitgStatView *view)
{
	gtk_style_get (gtk_widget_get_style (GTK_WIDGET (view)),
	               GITG_TYPE_STAT_VIEW,
	               "radius", &view->priv->radius,
	               "stat-padding", &view->priv->stat_padding,
	               "show-lines", &view->priv->show_lines,
	               "lines-spacing", &view->priv->lines_spacing,
	               NULL);
}

static void
gitg_stat_view_style_set (GtkWidget *widget, GtkStyle *prev_style)
{
	if (GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->style_set)
	{
		GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->style_set (widget, prev_style);
	}

	update_colors (GITG_STAT_VIEW (widget));
	update_styles (GITG_STAT_VIEW (widget));
}

static void
multiply_color (gdouble *color, gdouble factor, gdouble *ret)
{
	guint i;

	for (i = 0; i < 3; ++i)
	{
		ret[i] = color[i] * factor;
	}
}

static cairo_pattern_t *
create_gradient (gdouble *base_color,
                 gint     y,
                 gint     height)
{
	cairo_pattern_t *gradient;
	gdouble ret[3];

	gradient = cairo_pattern_create_linear (0, y, 0, height);

	cairo_pattern_add_color_stop_rgb (gradient,
	                                  0,
	                                  base_color[0],
	                                  base_color[1],
	                                  base_color[2]);

	multiply_color (base_color, 1.3, ret);

	cairo_pattern_add_color_stop_rgb (gradient,
	                                  1,
	                                  ret[0],
	                                  ret[1],
	                                  ret[2]);

	return gradient;
}

static void
update_gradients (GitgStatView *view,
                  GdkRectangle *alloc)
{
	if (view->priv->gradient_added == NULL)
	{
		view->priv->gradient_added = create_gradient (view->priv->color_added,
		                                              0,
		                                              alloc->height);
	}

	if (view->priv->gradient_removed == NULL)
	{
		view->priv->gradient_removed = create_gradient (view->priv->color_removed,
		                                              0,
		                                              alloc->height);
	}
}

static void
draw_stat (GitgStatView    *view,
           cairo_t         *ctx,
           gdouble         *color,
           cairo_pattern_t *gradient,
           gint             x,
           gint             y,
           gint             width,
           gint             height)
{
	gdouble darker[3];
	gdouble xoff;
	cairo_matrix_t mat;

	x += 0.5;
	y += 0.5;
	width -= 1;
	height -= 1;

	gitg_utils_rounded_rectangle (ctx,
	                              x,
	                              y,
	                              width,
	                              height,
	                              view->priv->radius);

	cairo_set_source (ctx, gradient);
	cairo_fill_preserve (ctx);

	multiply_color (color, 0.4, darker);

	cairo_set_line_width (ctx, 1);

	cairo_set_source_rgb (ctx, darker[0], darker[1], darker[2]);
	cairo_stroke (ctx);

	if (view->priv->show_lines)
	{
		xoff = x + view->priv->lines_spacing;

		cairo_matrix_init_rotate (&mat, M_PI);
		cairo_pattern_set_matrix (gradient, &mat);

		cairo_set_source (ctx, gradient);

		while (xoff < x + width - view->priv->lines_spacing / 2)
		{
			cairo_move_to (ctx, xoff, y + 2);
			cairo_line_to (ctx, xoff, y + height - 2);
			cairo_stroke (ctx);

			xoff += view->priv->lines_spacing;
		}

		cairo_matrix_init_identity (&mat);
		cairo_pattern_set_matrix (gradient, &mat);
	}
}

static gboolean
gitg_stat_view_draw (GtkWidget *widget,
                     cairo_t   *ctx)
{
	GdkRectangle alloc;
	guint added_width;
	guint removed_width;
	gdouble unit;
	GitgStatView *view;
	guint padding;

	if (GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->draw)
	{
		GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->draw (widget, ctx);
	}

	view = GITG_STAT_VIEW (widget);

	if (view->priv->max_lines == 0 ||
	    (view->priv->lines_added == 0 && view->priv->lines_removed == 0))
	{
		return TRUE;
	}

	if (view->priv->lines_added == 0 || view->priv->lines_removed == 0)
	{
		padding = 0;
	}
	else
	{
		padding = 2;
	}

	gtk_widget_get_allocation (widget, &alloc);

	update_gradients (view, &alloc);

	unit = (alloc.width - padding) / (gdouble)view->priv->max_lines;

	added_width = MAX(view->priv->radius * 2 + 1, (guint)(unit * view->priv->lines_added));
	removed_width = MAX(view->priv->radius * 2 + 1, (guint)(unit * view->priv->lines_removed));

	if (view->priv->lines_added > 0)
	{
		draw_stat (view,
		           ctx,
		           view->priv->color_added,
		           view->priv->gradient_added,
		           0,
		           0,
		           added_width,
		           alloc.height);
	}
	else
	{
		added_width = 0;
	}

	if (view->priv->lines_removed > 0)
	{
		draw_stat (view,
		           ctx,
		           view->priv->color_removed,
		           view->priv->gradient_removed,
		           added_width + padding,
		           0,
		           removed_width,
		           alloc.height);
	}

	return TRUE;
}

static void
gitg_stat_view_set_property (GObject      *object,
                             guint         prop_id,
                             const GValue *value,
                             GParamSpec   *pspec)
{
	GitgStatView *self = GITG_STAT_VIEW (object);
	
	switch (prop_id)
	{
		case PROP_LINES_ADDED:
			self->priv->lines_added = g_value_get_uint (value);
			gtk_widget_queue_draw (GTK_WIDGET (self));
		break;
		case PROP_LINES_REMOVED:
			self->priv->lines_removed = g_value_get_uint (value);
			gtk_widget_queue_draw (GTK_WIDGET (self));
		break;
		case PROP_MAX_LINES:
			self->priv->max_lines = g_value_get_uint (value);
			gtk_widget_queue_draw (GTK_WIDGET (self));
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static void
gitg_stat_view_get_property (GObject    *object,
                             guint       prop_id,
                             GValue     *value,
                             GParamSpec *pspec)
{
	GitgStatView *self = GITG_STAT_VIEW (object);
	
	switch (prop_id)
	{
		case PROP_LINES_ADDED:
			g_value_set_uint (value, self->priv->lines_added);
		break;
		case PROP_LINES_REMOVED:
			g_value_set_uint (value, self->priv->lines_removed);
		break;
		case PROP_MAX_LINES:
			g_value_set_uint (value, self->priv->max_lines);
		break;
		default:
			G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
		break;
	}
}

static gboolean
gitg_stat_view_configure (GtkWidget *widget,
                          GdkEventConfigure *event)
{
	gboolean ret;

	if (GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->configure_event)
	{
		ret = GTK_WIDGET_CLASS (gitg_stat_view_parent_class)->configure_event (widget, event);
	}
	else
	{
		ret = FALSE;
	}

	clear_gradients (GITG_STAT_VIEW (widget));

	return ret;
}

static void
gitg_stat_view_class_init (GitgStatViewClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);
	GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);

	widget_class->style_set = gitg_stat_view_style_set;
	widget_class->draw = gitg_stat_view_draw;
	widget_class->realize = gitg_stat_view_realize;
	widget_class->configure_event = gitg_stat_view_configure;

	object_class->finalize = gitg_stat_view_finalize;
	object_class->set_property = gitg_stat_view_set_property;
	object_class->get_property = gitg_stat_view_get_property;

	g_object_class_install_property (object_class,
	                                 PROP_LINES_ADDED,
	                                 g_param_spec_uint ("lines-added",
	                                                    "Lines Added",
	                                                    "Lines added",
	                                                    0,
	                                                    G_MAXUINT,
	                                                    0,
	                                                    G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_LINES_REMOVED,
	                                 g_param_spec_uint ("lines-removed",
	                                                    "Lines Removed",
	                                                    "Lines removed",
	                                                    0,
	                                                    G_MAXUINT,
	                                                    0,
	                                                    G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	g_object_class_install_property (object_class,
	                                 PROP_MAX_LINES,
	                                 g_param_spec_uint ("max-lines",
	                                                    "Max Lines",
	                                                    "Max lines",
	                                                    0,
	                                                    G_MAXUINT,
	                                                    0,
	                                                    G_PARAM_READWRITE | G_PARAM_CONSTRUCT));

	gtk_widget_class_install_style_property (widget_class,
	                                         g_param_spec_uint ("radius",
	                                                            "Radius",
	                                                            "Radius",
	                                                            0,
	                                                            G_MAXUINT,
	                                                            4,
	                                                            G_PARAM_READWRITE));

	gtk_widget_class_install_style_property (widget_class,
	                                         g_param_spec_uint ("stat-padding",
	                                                            "Stat padding",
	                                                            "Stat padding",
	                                                            0,
	                                                            G_MAXUINT,
	                                                            2,
	                                                            G_PARAM_READWRITE));

	gtk_widget_class_install_style_property (widget_class,
	                                         g_param_spec_boolean ("show-lines",
	                                                               "Show lines",
	                                                               "Show lines",
	                                                               TRUE,
	                                                               G_PARAM_READWRITE));

	gtk_widget_class_install_style_property (widget_class,
	                                         g_param_spec_uint ("lines-spacing",
	                                                            "Lines spacing",
	                                                            "Lines spacing",
	                                                            1,
	                                                            G_MAXUINT,
	                                                            10,
	                                                            G_PARAM_READWRITE));

	g_type_class_add_private (object_class, sizeof(GitgStatViewPrivate));
}

static void
gitg_stat_view_init (GitgStatView *self)
{
	self->priv = GITG_STAT_VIEW_GET_PRIVATE (self);
}

GtkWidget *
gitg_stat_view_new (guint lines_added,
                    guint lines_removed,
                    guint max_lines)
{
	return g_object_new (GITG_TYPE_STAT_VIEW,
	                     "lines-added",
	                     lines_added,
	                     "lines-removed",
	                     lines_removed,
	                     "max-lines",
	                     max_lines,
	                     NULL);
}
