/*
 * Copyright (C) 2012 Alexander Larsson <alexl@redhat.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see <http://www.gnu.org/licenses/>.
 */

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <gdk/gdk.h>
#include <float.h>
#include <math.h>
#include <cairo.h>
#include <string.h>
#include <gobject/gvaluecollector.h>

#include "list-box.h"

#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))
static gpointer _g_object_ref0 (gpointer self) {
	return self ? g_object_ref (self) : NULL;
}

static void g_cclosure_user_marshal_VOID__ENUM_INT (GClosure             *closure,
						    GValue               *return_value,
						    guint                 n_param_values,
						    const GValue         *param_values,
						    gpointer              invocation_hint,
						    gpointer              marshal_data);




static void g_cclosure_user_marshal_VOID__ENUM_INT (GClosure * closure, GValue * return_value, guint n_param_values, const GValue * param_values, gpointer invocation_hint, gpointer marshal_data) {
  typedef void (*GMarshalFunc_VOID__ENUM_INT) (gpointer data1, gint arg_1, gint arg_2, gpointer data2);
  register GMarshalFunc_VOID__ENUM_INT callback;
  register GCClosure * cc;
  register gpointer data1;
  register gpointer data2;
  cc = (GCClosure *) closure;
  g_return_if_fail (n_param_values == 3);
  if (G_CCLOSURE_SWAP_DATA (closure)) {
    data1 = closure->data;
    data2 = param_values->data[0].v_pointer;
  } else {
    data1 = param_values->data[0].v_pointer;
    data2 = closure->data;
  }
  callback = (GMarshalFunc_VOID__ENUM_INT) (marshal_data ? marshal_data : cc->callback);
  callback (data1, g_value_get_enum (param_values + 1), g_value_get_int (param_values + 2), data2);
}

typedef struct _EggListBoxChildInfo EggListBoxChildInfo;

struct _EggListBoxPrivate
{
  GSequence *children;
  GHashTable *child_hash;
  GHashTable *separator_hash;

  GCompareDataFunc sort_func;
  gpointer sort_func_target;
  GDestroyNotify sort_func_target_destroy_notify;

  EggListBoxFilterFunc filter_func;
  gpointer filter_func_target;
  GDestroyNotify filter_func_target_destroy_notify;

  EggListBoxUpdateSeparatorFunc update_separator_func;
  gpointer update_separator_func_target;
  GDestroyNotify update_separator_func_target_destroy_notify;

  EggListBoxChildInfo *selected_child;
  EggListBoxChildInfo *prelight_child;
  EggListBoxChildInfo *cursor_child;

  gboolean active_child_active;
  EggListBoxChildInfo *active_child;

  GtkSelectionMode selection_mode;

  GtkAdjustment *adjustment;
  gboolean activate_single_click;

  /* DnD */
  GtkWidget *drag_highlighted_widget;
  guint auto_scroll_timeout_id;
};

struct _EggListBoxChildInfo
{
  GSequenceIter *iter;
  GtkWidget *widget;
  GtkWidget *separator;
  gint y;
  gint height;
};

enum {
  CHILD_SELECTED,
  CHILD_ACTIVATED,
  ACTIVATE_CURSOR_CHILD,
  TOGGLE_CURSOR_CHILD,
  MOVE_CURSOR,
  LAST_SIGNAL
};

enum  {
  PROP_0
};

G_DEFINE_TYPE (EggListBox, egg_list_box, GTK_TYPE_CONTAINER)

static EggListBoxChildInfo *egg_list_box_find_child_at_y                     (EggListBox          *self,
									      gint                 y);
static EggListBoxChildInfo *egg_list_box_lookup_info                         (EggListBox          *self,
									      GtkWidget           *widget);
static void                 egg_list_box_update_selected                     (EggListBox          *self,
									      EggListBoxChildInfo *child);
static void                 egg_list_box_apply_filter_all                    (EggListBox          *self);
static void                 egg_list_box_update_separator                    (EggListBox          *self,
									      GSequenceIter       *iter);
static GSequenceIter *      egg_list_box_get_next_visible                    (EggListBox          *self,
									      GSequenceIter       *_iter);
static void                 egg_list_box_apply_filter                        (EggListBox          *self,
									      GtkWidget           *child);
static void                 egg_list_box_add_move_binding                    (GtkBindingSet       *binding_set,
									      guint                keyval,
									      GdkModifierType      modmask,
									      GtkMovementStep      step,
									      gint                 count);
static void                 egg_list_box_update_cursor                       (EggListBox          *self,
									      EggListBoxChildInfo *child);
static void                 egg_list_box_select_and_activate                 (EggListBox          *self,
									      EggListBoxChildInfo *child);
static void                 egg_list_box_update_prelight                     (EggListBox          *self,
									      EggListBoxChildInfo *child);
static void                 egg_list_box_update_active                       (EggListBox          *self,
									      EggListBoxChildInfo *child);
static gboolean             egg_list_box_real_enter_notify_event             (GtkWidget           *base,
									      GdkEventCrossing    *event);
static gboolean             egg_list_box_real_leave_notify_event             (GtkWidget           *base,
									      GdkEventCrossing    *event);
static gboolean             egg_list_box_real_motion_notify_event            (GtkWidget           *base,
									      GdkEventMotion      *event);
static gboolean             egg_list_box_real_button_press_event             (GtkWidget           *base,
									      GdkEventButton      *event);
static gboolean             egg_list_box_real_button_release_event           (GtkWidget           *base,
									      GdkEventButton      *event);
static void                 egg_list_box_real_show                           (GtkWidget           *base);
static gboolean             egg_list_box_real_focus                          (GtkWidget           *base,
									      GtkDirectionType     direction);
static GSequenceIter*       egg_list_box_get_previous_visible                (EggListBox          *self,
									      GSequenceIter       *_iter);
static EggListBoxChildInfo *egg_list_box_get_first_visible                   (EggListBox          *self);
static EggListBoxChildInfo *egg_list_box_get_last_visible                    (EggListBox          *self);
static gboolean             egg_list_box_real_draw                           (GtkWidget           *base,
									      cairo_t             *cr);
static void                 egg_list_box_real_realize                        (GtkWidget           *base);
static void                 egg_list_box_real_add                            (GtkContainer        *container,
									      GtkWidget           *widget);
static void                 egg_list_box_child_visibility_changed            (EggListBox          *self,
									      GObject             *object,
									      GParamSpec          *pspec);
static void                 egg_list_box_real_remove                         (GtkContainer        *container,
									      GtkWidget           *widget);
static void                 egg_list_box_real_forall_internal                (GtkContainer        *container,
									      gboolean             include_internals,
									      GtkCallback          callback,
									      void                *callback_target);
static void                 egg_list_box_real_compute_expand_internal        (GtkWidget           *base,
									      gboolean            *hexpand,
									      gboolean            *vexpand);
static GType                egg_list_box_real_child_type                     (GtkContainer        *container);
static GtkSizeRequestMode   egg_list_box_real_get_request_mode               (GtkWidget           *base);
static void                 egg_list_box_real_get_preferred_height           (GtkWidget           *base,
									      gint                *minimum_height,
									      gint                *natural_height);
static void                 egg_list_box_real_get_preferred_height_for_width (GtkWidget           *base,
									      gint                 width,
									      gint                *minimum_height,
									      gint                *natural_height);
static void                 egg_list_box_real_get_preferred_width            (GtkWidget           *base,
									      gint                *minimum_width,
									      gint                *natural_width);
static void                 egg_list_box_real_get_preferred_width_for_height (GtkWidget           *base,
									      gint                 height,
									      gint                *minimum_width,
									      gint                *natural_width);
static void                 egg_list_box_real_size_allocate                  (GtkWidget           *base,
									      GtkAllocation       *allocation);
static void                 egg_list_box_real_drag_leave                     (GtkWidget           *base,
									      GdkDragContext      *context,
									      guint                time_);
static gboolean             egg_list_box_real_drag_motion                    (GtkWidget           *base,
									      GdkDragContext      *context,
									      gint                 x,
									      gint                 y,
									      guint                time_);
static void                 egg_list_box_real_activate_cursor_child          (EggListBox          *self);
static void                 egg_list_box_real_toggle_cursor_child            (EggListBox          *self);
static void                 egg_list_box_real_move_cursor                    (EggListBox          *self,
									      GtkMovementStep      step,
									      gint                 count);
static void                 egg_list_box_finalize                            (GObject             *obj);

static void   _egg_list_box_child_visibility_changed_g_object_notify (GObject              *_sender,
								      GParamSpec           *pspec,
								      gpointer              self);

static guint signals[LAST_SIGNAL] = { 0 };

static EggListBoxChildInfo*
egg_list_box_child_info_new (GtkWidget *widget)
{
  EggListBoxChildInfo *info;

  info = g_new0 (EggListBoxChildInfo, 1);
  info->widget = g_object_ref (widget);
  return info;
}

static void
egg_list_box_child_info_free (EggListBoxChildInfo *info)
{
  _g_object_unref0 (info->widget);
  _g_object_unref0 (info->separator);
  g_free (info);
}

EggListBox*
egg_list_box_new (void)
{
  return g_object_new (EGG_TYPE_LIST_BOX, NULL);
}

static void
egg_list_box_init (EggListBox *self)
{
  self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, EGG_TYPE_LIST_BOX, EggListBoxPrivate);

  gtk_widget_set_can_focus ((GtkWidget*) self, TRUE);
  gtk_widget_set_has_window ((GtkWidget*) self, TRUE);
  gtk_widget_set_redraw_on_allocate ((GtkWidget*) self, TRUE);
  self->priv->selection_mode = GTK_SELECTION_SINGLE;
  self->priv->activate_single_click = TRUE;

  self->priv->children = g_sequence_new ((GDestroyNotify)egg_list_box_child_info_free);
  self->priv->child_hash = g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);
  self->priv->separator_hash = g_hash_table_new_full (g_direct_hash, g_direct_equal, NULL, NULL);
}

static void
egg_list_box_finalize (GObject *obj)
{

  EggListBox *self;
  self = EGG_LIST_BOX (obj);

  if (self->priv->auto_scroll_timeout_id != ((guint) 0))
    g_source_remove (self->priv->auto_scroll_timeout_id);

  if (self->priv->sort_func_target_destroy_notify != NULL)
    self->priv->sort_func_target_destroy_notify (self->priv->sort_func_target);
  if (self->priv->filter_func_target_destroy_notify != NULL)
    self->priv->filter_func_target_destroy_notify (self->priv->filter_func_target);
  if (self->priv->update_separator_func_target_destroy_notify != NULL)
    self->priv->update_separator_func_target_destroy_notify (self->priv->update_separator_func_target);

  if (self->priv->adjustment)
    g_object_unref (self->priv->adjustment);

  if (self->priv->drag_highlighted_widget)
    g_object_unref (self->priv->drag_highlighted_widget);

  g_sequence_free (self->priv->children);
  g_hash_table_unref (self->priv->child_hash);
  g_hash_table_unref (self->priv->separator_hash);

  G_OBJECT_CLASS (egg_list_box_parent_class)->finalize (obj);
}

static void
egg_list_box_class_init (EggListBoxClass *klass)
{
  GObjectClass *object_class = G_OBJECT_CLASS (klass);
  GtkWidgetClass *widget_class = GTK_WIDGET_CLASS (klass);
  GtkContainerClass *container_class = GTK_CONTAINER_CLASS (klass);
  GtkBindingSet *binding_set;

  egg_list_box_parent_class = g_type_class_peek_parent (klass);

  g_type_class_add_private (klass, sizeof (EggListBoxPrivate));

  object_class->finalize = egg_list_box_finalize;
  widget_class->enter_notify_event = egg_list_box_real_enter_notify_event;
  widget_class->leave_notify_event = egg_list_box_real_leave_notify_event;
  widget_class->motion_notify_event = egg_list_box_real_motion_notify_event;
  widget_class->button_press_event = egg_list_box_real_button_press_event;
  widget_class->button_release_event = egg_list_box_real_button_release_event;
  widget_class->show = egg_list_box_real_show;
  widget_class->focus = egg_list_box_real_focus;
  widget_class->draw = egg_list_box_real_draw;
  widget_class->realize = egg_list_box_real_realize;
  widget_class->compute_expand = egg_list_box_real_compute_expand_internal;
  widget_class->get_request_mode = egg_list_box_real_get_request_mode;
  widget_class->get_preferred_height = egg_list_box_real_get_preferred_height;
  widget_class->get_preferred_height_for_width = egg_list_box_real_get_preferred_height_for_width;
  widget_class->get_preferred_width = egg_list_box_real_get_preferred_width;
  widget_class->get_preferred_width_for_height = egg_list_box_real_get_preferred_width_for_height;
  widget_class->size_allocate = egg_list_box_real_size_allocate;
  widget_class->drag_leave = egg_list_box_real_drag_leave;
  widget_class->drag_motion = egg_list_box_real_drag_motion;
  container_class->add = egg_list_box_real_add;
  container_class->remove = egg_list_box_real_remove;
  container_class->forall = egg_list_box_real_forall_internal;
  container_class->child_type = egg_list_box_real_child_type;
  klass->activate_cursor_child = egg_list_box_real_activate_cursor_child;
  klass->toggle_cursor_child = egg_list_box_real_toggle_cursor_child;
  klass->move_cursor = egg_list_box_real_move_cursor;

  signals[CHILD_SELECTED] =
    g_signal_new ("child-selected",
		  EGG_TYPE_LIST_BOX,
		  G_SIGNAL_RUN_LAST,
		  G_STRUCT_OFFSET (EggListBoxClass, child_selected),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__OBJECT,
		  G_TYPE_NONE, 1,
		  GTK_TYPE_WIDGET);
  signals[CHILD_ACTIVATED] =
    g_signal_new ("child-activated",
		  EGG_TYPE_LIST_BOX,
		  G_SIGNAL_RUN_LAST,
		  G_STRUCT_OFFSET (EggListBoxClass, child_activated),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__OBJECT,
		  G_TYPE_NONE, 1,
		  GTK_TYPE_WIDGET);
  signals[ACTIVATE_CURSOR_CHILD] =
    g_signal_new ("activate-cursor-child",
		  EGG_TYPE_LIST_BOX,
		  G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
		  G_STRUCT_OFFSET (EggListBoxClass, activate_cursor_child),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__VOID,
		  G_TYPE_NONE, 0);
  signals[TOGGLE_CURSOR_CHILD] =
    g_signal_new ("toggle-cursor-child",
		  EGG_TYPE_LIST_BOX,
		  G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
		  G_STRUCT_OFFSET (EggListBoxClass, toggle_cursor_child),
		  NULL, NULL,
		  g_cclosure_marshal_VOID__VOID,
		  G_TYPE_NONE, 0);
  signals[MOVE_CURSOR] =
    g_signal_new ("move-cursor",
		  EGG_TYPE_LIST_BOX,
		  G_SIGNAL_RUN_LAST | G_SIGNAL_ACTION,
		  G_STRUCT_OFFSET (EggListBoxClass, move_cursor),
		  NULL, NULL,
		  g_cclosure_user_marshal_VOID__ENUM_INT,
		  G_TYPE_NONE, 2,
		  GTK_TYPE_MOVEMENT_STEP, G_TYPE_INT);

  widget_class->activate_signal = signals[ACTIVATE_CURSOR_CHILD];

  binding_set = gtk_binding_set_by_class (klass);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_Home, 0,
				 GTK_MOVEMENT_BUFFER_ENDS, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_Home, 0,
				 GTK_MOVEMENT_BUFFER_ENDS, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_End, 0,
				 GTK_MOVEMENT_BUFFER_ENDS, 1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_End, 0,
				 GTK_MOVEMENT_BUFFER_ENDS, 1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_Up, GDK_CONTROL_MASK,
				 GTK_MOVEMENT_DISPLAY_LINES, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_Up, GDK_CONTROL_MASK,
				 GTK_MOVEMENT_DISPLAY_LINES, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_Down, GDK_CONTROL_MASK,
				 GTK_MOVEMENT_DISPLAY_LINES, 1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_Down, GDK_CONTROL_MASK,
				 GTK_MOVEMENT_DISPLAY_LINES, 1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_Page_Up, 0,
				 GTK_MOVEMENT_PAGES, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_Page_Up, 0,
				 GTK_MOVEMENT_PAGES, -1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_Page_Down, 0,
				 GTK_MOVEMENT_PAGES, 1);
  egg_list_box_add_move_binding (binding_set, GDK_KEY_KP_Page_Down, 0,
				 GTK_MOVEMENT_PAGES, 1);
  gtk_binding_entry_add_signal (binding_set, GDK_KEY_space, GDK_CONTROL_MASK,
				"toggle-cursor-child", 0, NULL);
}

GtkWidget *
egg_list_box_get_selected_child (EggListBox *self)
{
  g_return_val_if_fail (self != NULL, NULL);

  if (self->priv->selected_child != NULL)
    return self->priv->selected_child->widget;

  return NULL;
}

GtkWidget *
egg_list_box_get_child_at_y (EggListBox *self, gint y)
{
  EggListBoxChildInfo *child;

  g_return_val_if_fail (self != NULL, NULL);

  child = egg_list_box_find_child_at_y (self, y);
  if (child == NULL)
    return NULL;

  return child->widget;
}


void
egg_list_box_select_child (EggListBox *self, GtkWidget *child)
{
  EggListBoxChildInfo *info = NULL;

  g_return_if_fail (self != NULL);

  if (child != NULL)
    info = egg_list_box_lookup_info (self, child);

  egg_list_box_update_selected (self, info);
}

void
egg_list_box_set_adjustment (EggListBox *self,
			     GtkAdjustment *adjustment)
{
  g_return_if_fail (self != NULL);

  g_object_ref (adjustment);
  _g_object_unref0 (self->priv->adjustment);
  self->priv->adjustment = adjustment;
  gtk_container_set_focus_vadjustment (GTK_CONTAINER (self),
				       adjustment);
}

void
egg_list_box_add_to_scrolled (EggListBox *self,
			      GtkScrolledWindow *scrolled)
{
  g_return_if_fail (self != NULL);
  g_return_if_fail (scrolled != NULL);

  gtk_scrolled_window_add_with_viewport (scrolled,
					 GTK_WIDGET (self));
  egg_list_box_set_adjustment (self,
			       gtk_scrolled_window_get_vadjustment (scrolled));
}


void egg_list_box_set_selection_mode (EggListBox *self, GtkSelectionMode mode) {
  g_return_if_fail (self != NULL);

  if (mode == GTK_SELECTION_MULTIPLE)
    {
      g_warning ("egg-list-box.vala:115: Multiple selections not supported");
      return;
    }

  self->priv->selection_mode = mode;
  if (mode == GTK_SELECTION_NONE)
    egg_list_box_update_selected (self, NULL);
}


void
egg_list_box_set_filter_func (EggListBox *self,
			      EggListBoxFilterFunc f,
			      void *f_target,
			      GDestroyNotify f_target_destroy_notify)
{
  g_return_if_fail (self != NULL);

  if (self->priv->filter_func_target_destroy_notify != NULL)
    self->priv->filter_func_target_destroy_notify (self->priv->filter_func_target);

  self->priv->filter_func = f;
  self->priv->filter_func_target = f_target;
  self->priv->filter_func_target_destroy_notify = f_target_destroy_notify;

  egg_list_box_refilter (self);
}

void
egg_list_box_set_separator_funcs (EggListBox *self,
				  EggListBoxUpdateSeparatorFunc update_separator,
				  void *update_separator_target,
				  GDestroyNotify update_separator_target_destroy_notify)
{
  g_return_if_fail (self != NULL);

  if (self->priv->update_separator_func_target_destroy_notify != NULL)
    self->priv->update_separator_func_target_destroy_notify (self->priv->update_separator_func_target);

  self->priv->update_separator_func = update_separator;
  self->priv->update_separator_func_target = update_separator_target;
  self->priv->update_separator_func_target_destroy_notify = update_separator_target_destroy_notify;
  egg_list_box_reseparate (self);
}

void
egg_list_box_refilter (EggListBox *self)
{
  g_return_if_fail (self != NULL);


  egg_list_box_apply_filter_all (self);
  egg_list_box_reseparate (self);
  gtk_widget_queue_resize ((GtkWidget*) self);
}

static gint
do_sort (EggListBoxChildInfo *a,
	 EggListBoxChildInfo *b,
	 EggListBox *self)
{
  return self->priv->sort_func (a->widget, b->widget,
				self->priv->sort_func_target);
}

void
egg_list_box_resort (EggListBox *self)
{
  g_return_if_fail (self != NULL);

  g_sequence_sort (self->priv->children, (GCompareDataFunc)do_sort, self);
  egg_list_box_reseparate (self);
  gtk_widget_queue_resize ((GtkWidget*) self);
}

void
egg_list_box_reseparate (EggListBox *self)
{
  GSequenceIter *iter;

  g_return_if_fail (self != NULL);

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    egg_list_box_update_separator (self, iter);

  gtk_widget_queue_resize ((GtkWidget*) self);
}

void
egg_list_box_set_sort_func (EggListBox *self,
			    GCompareDataFunc f,
			    void *f_target,
			    GDestroyNotify f_target_destroy_notify)
{
  g_return_if_fail (self != NULL);

  if (self->priv->sort_func_target_destroy_notify != NULL)
    self->priv->sort_func_target_destroy_notify (self->priv->sort_func_target);

  self->priv->sort_func = f;
  self->priv->sort_func_target = f_target;
  self->priv->sort_func_target_destroy_notify = f_target_destroy_notify;
  egg_list_box_resort (self);
}

void
egg_list_box_child_changed (EggListBox *self, GtkWidget *widget)
{
  EggListBoxChildInfo *info;
  GSequenceIter *prev_next, *next;

  g_return_if_fail (self != NULL);
  g_return_if_fail (widget != NULL);

  info = egg_list_box_lookup_info (self, widget);
  if (info == NULL)
    return;

  prev_next = egg_list_box_get_next_visible (self, info->iter);
  if (self->priv->sort_func != NULL)
    {
      g_sequence_sort_changed (info->iter,
			       (GCompareDataFunc)do_sort,
			       self);
      gtk_widget_queue_resize ((GtkWidget*) self);
    }
  egg_list_box_apply_filter (self, info->widget);
  if (gtk_widget_get_visible ((GtkWidget*) self))
    {
      next = egg_list_box_get_next_visible (self, info->iter);
      egg_list_box_update_separator (self, info->iter);
      egg_list_box_update_separator (self, next);
      egg_list_box_update_separator (self, prev_next);
    }
}

void
egg_list_box_set_activate_on_single_click (EggListBox *self,
					   gboolean single)
{
  g_return_if_fail (self != NULL);

  self->priv->activate_single_click = single;
}

static void
egg_list_box_add_move_binding (GtkBindingSet *binding_set,
			       guint keyval,
			       GdkModifierType modmask,
			       GtkMovementStep step,
			       gint count)
{
  gtk_binding_entry_add_signal (binding_set, keyval, modmask,
				"move-cursor", (guint) 2, GTK_TYPE_MOVEMENT_STEP, step, G_TYPE_INT, count, NULL);

  if ((modmask & GDK_CONTROL_MASK) == GDK_CONTROL_MASK)
    return;

  gtk_binding_entry_add_signal (binding_set, keyval, GDK_CONTROL_MASK,
				"move-cursor", (guint) 2, GTK_TYPE_MOVEMENT_STEP, step, G_TYPE_INT, count, NULL);
}

static EggListBoxChildInfo*
egg_list_box_find_child_at_y (EggListBox *self, gint y)
{
  EggListBoxChildInfo *child_info;
  GSequenceIter *iter;
  EggListBoxChildInfo *info;

  child_info = NULL;
  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
      info = (EggListBoxChildInfo*) g_sequence_get (iter);
      if (y >= info->y && y < (info->y + info->height))
	{
	  child_info = info;
	  break;
	}
    }

  return child_info;
}

static void
egg_list_box_update_cursor (EggListBox *self,
			    EggListBoxChildInfo *child)
{
  self->priv->cursor_child = child;
  gtk_widget_grab_focus ((GtkWidget*) self);
  gtk_widget_queue_draw ((GtkWidget*) self);
  if (child != NULL && self->priv->adjustment != NULL)
    {
      GtkAllocation allocation;
      gtk_widget_get_allocation ((GtkWidget*) self, &allocation);
      gtk_adjustment_clamp_page (self->priv->adjustment,
				 self->priv->cursor_child->y + allocation.y,
				 self->priv->cursor_child->y + allocation.y + self->priv->cursor_child->height);
  }
}

static void
egg_list_box_update_selected (EggListBox *self,
			      EggListBoxChildInfo *child)
{
  if (child != self->priv->selected_child &&
      (child == NULL || self->priv->selection_mode != GTK_SELECTION_NONE))
    {
      self->priv->selected_child = child;
      g_signal_emit (self, signals[CHILD_SELECTED], 0,
		     (self->priv->selected_child != NULL) ? self->priv->selected_child->widget : NULL);
      gtk_widget_queue_draw ((GtkWidget*) self);
    }
  if (child != NULL)
    egg_list_box_update_cursor (self, child);
}

static void
egg_list_box_select_and_activate (EggListBox *self, EggListBoxChildInfo *child)
{
  GtkWidget *w = NULL;

  if (child != NULL)
    w = child->widget;

  egg_list_box_update_selected (self, child);

  if (w != NULL)
    g_signal_emit (self, signals[CHILD_ACTIVATED], 0, w);
}

static void
egg_list_box_update_prelight (EggListBox *self, EggListBoxChildInfo *child)
{
  if (child != self->priv->prelight_child)
    {
      self->priv->prelight_child = child;
      gtk_widget_queue_draw ((GtkWidget*) self);
    }
}

static void
egg_list_box_update_active (EggListBox *self, EggListBoxChildInfo *child)
{
  gboolean val;

  val = self->priv->active_child == child;
  if (self->priv->active_child != NULL &&
      val != self->priv->active_child_active)
    {
      self->priv->active_child_active = val;
      gtk_widget_queue_draw ((GtkWidget*) self);
    }
}

static gboolean
egg_list_box_real_enter_notify_event (GtkWidget *base,
				      GdkEventCrossing *event)
{
  EggListBox *self = EGG_LIST_BOX (base);
  EggListBoxChildInfo *child;


  if (event->window != gtk_widget_get_window ((GtkWidget*) self))
    return FALSE;

  child = egg_list_box_find_child_at_y (self, event->y);
  egg_list_box_update_prelight (self, child);
  egg_list_box_update_active (self, child);

  return FALSE;
}

static gboolean
egg_list_box_real_leave_notify_event (GtkWidget *base,
				      GdkEventCrossing *event)
{
  EggListBox *self = EGG_LIST_BOX (base);
  EggListBoxChildInfo *child = NULL;

  if (event->window != gtk_widget_get_window ((GtkWidget*) self))
    return FALSE;

  if (event->detail != GDK_NOTIFY_INFERIOR)
    child = NULL;
  else
    child = egg_list_box_find_child_at_y (self, event->y);

  egg_list_box_update_prelight (self, child);
  egg_list_box_update_active (self, child);

  return FALSE;
}

static gboolean
egg_list_box_real_motion_notify_event (GtkWidget *base,
				       GdkEventMotion *event)
{
  EggListBox *self = EGG_LIST_BOX (base);
  EggListBoxChildInfo *child;


  child = egg_list_box_find_child_at_y (self, event->y);
  egg_list_box_update_prelight (self, child);
  egg_list_box_update_active (self, child);

  return FALSE;
}

static gboolean
egg_list_box_real_button_press_event (GtkWidget *base,
				      GdkEventButton *event)
{
  EggListBox *self = EGG_LIST_BOX (base);

  if (event->button == 1)
    {
      EggListBoxChildInfo *child;
      child = egg_list_box_find_child_at_y (self, event->y);
      if (child != NULL)
	{
	  self->priv->active_child = child;
	  self->priv->active_child_active = TRUE;
	  gtk_widget_queue_draw ((GtkWidget*) self);
	  if (event->type == GDK_2BUTTON_PRESS &&
	      !self->priv->activate_single_click &&
	      child->widget != NULL)
	    g_signal_emit (self, signals[CHILD_ACTIVATED], 0,
			   child->widget);

	}
      /* TODO:
	 Should mark as active while down,
	 and handle grab breaks */
    }

  return FALSE;
}

static gboolean
egg_list_box_real_button_release_event (GtkWidget *base,
					GdkEventButton *event)
{
  EggListBox *self = EGG_LIST_BOX (base);

  if (event->button == 1)
    {
    if (self->priv->active_child != NULL &&
	self->priv->active_child_active)
      {
	if (self->priv->activate_single_click)
	  egg_list_box_select_and_activate (self, self->priv->active_child);
	else
	  egg_list_box_update_selected (self, self->priv->active_child);
      }
    self->priv->active_child = NULL;
    self->priv->active_child_active = FALSE;
    gtk_widget_queue_draw ((GtkWidget*) self);
  }

  return FALSE;
}

static void
egg_list_box_real_show (GtkWidget *base)
{
  EggListBox * self = EGG_LIST_BOX (base);

  egg_list_box_reseparate (self);

  GTK_WIDGET_CLASS (egg_list_box_parent_class)->show ((GtkWidget*) G_TYPE_CHECK_INSTANCE_CAST (self, GTK_TYPE_CONTAINER, GtkContainer));
}


static gboolean
egg_list_box_real_focus (GtkWidget* base, GtkDirectionType direction)
{
  EggListBox * self= (EggListBox*) base;
  gboolean had_focus = FALSE;
  gboolean focus_into = FALSE;
  GtkWidget* recurse_into;
  EggListBoxChildInfo *current_focus_child;
  EggListBoxChildInfo *next_focus_child;
  gboolean modify_selection_pressed;
  GdkModifierType state = 0;

  recurse_into = NULL;
  focus_into = TRUE;

  g_object_get ((GtkWidget*) self, "has-focus", &had_focus, NULL);
  current_focus_child = NULL;
  next_focus_child = NULL;
  if (had_focus)
    {
      /* If on row, going right, enter into possible container */
      if (direction == GTK_DIR_RIGHT || direction == GTK_DIR_TAB_FORWARD)
	{
	  if (self->priv->cursor_child != NULL)
	    recurse_into = self->priv->cursor_child->widget;
	}
      current_focus_child = self->priv->cursor_child;
      /* Unless we're going up/down we're always leaving
      the container */
      if (direction != GTK_DIR_UP && direction != GTK_DIR_DOWN)
	focus_into = FALSE;
    }
  else if (gtk_container_get_focus_child ((GtkContainer*) self) != NULL)
    {
      /* There is a focus child, always navigat inside it first */
      recurse_into = gtk_container_get_focus_child ((GtkContainer*) self);
      current_focus_child = egg_list_box_lookup_info (self, recurse_into);

      /* If exiting child container to the right, exit row */
      if (direction == GTK_DIR_RIGHT || direction == GTK_DIR_TAB_FORWARD)
	focus_into = FALSE;

      /* If exiting child container to the left, select row or out */
      if (direction == GTK_DIR_LEFT || direction == GTK_DIR_TAB_BACKWARD)
	next_focus_child = current_focus_child;
    }
  else
    {
      /* If coming from the left, enter into possible container */
      if (direction == GTK_DIR_LEFT || direction == GTK_DIR_TAB_BACKWARD)
	{
	  if (self->priv->selected_child != NULL)
	    recurse_into = self->priv->selected_child->widget;
	}
    }

  if (recurse_into != NULL)
    {
      if (gtk_widget_child_focus (recurse_into, direction))
	return TRUE;
    }

  if (!focus_into)
    return FALSE; /* Focus is leaving us */

  /* TODO: This doesn't handle up/down going into a focusable separator */

  if (next_focus_child == NULL)
    {
      if (current_focus_child != NULL)
	{
	  GSequenceIter* i;
	  if (direction == GTK_DIR_UP)
	    {
	      i = egg_list_box_get_previous_visible (self, current_focus_child->iter);
	      if (i != NULL)
		next_focus_child = g_sequence_get (i);

	    }
	  else
	    {
	      i = egg_list_box_get_next_visible (self, current_focus_child->iter);
	      if (!g_sequence_iter_is_end (i))
		next_focus_child = g_sequence_get (i);

	    }
	}
      else
	{
	  switch (direction)
	    {
	    case GTK_DIR_DOWN:
	    case GTK_DIR_TAB_FORWARD:
	      next_focus_child = egg_list_box_get_first_visible (self);
	      break;
	    case GTK_DIR_UP:
	    case GTK_DIR_TAB_BACKWARD:
	      next_focus_child = egg_list_box_get_last_visible (self);
	      break;
	    default:
	      next_focus_child = self->priv->selected_child;
	      if (next_focus_child == NULL)
		next_focus_child =
		  egg_list_box_get_first_visible (self);
	      break;
	    }
	}
    }

  if (next_focus_child == NULL)
    {
      if (direction == GTK_DIR_UP || direction == GTK_DIR_DOWN)
	{
	  gtk_widget_error_bell ((GtkWidget*) self);
	  return TRUE;
	}

      return FALSE;
    }

  modify_selection_pressed = FALSE;
  if (gtk_get_current_event_state (&state))
    {
      GdkModifierType modify_mod_mask;
      modify_mod_mask =
	gtk_widget_get_modifier_mask ((GtkWidget*) self,
				      GDK_MODIFIER_INTENT_MODIFY_SELECTION);
      if ((state & modify_mod_mask) == modify_mod_mask)
	modify_selection_pressed = TRUE;
    }

  egg_list_box_update_cursor (self, next_focus_child);
  if (!modify_selection_pressed)
    egg_list_box_update_selected (self, next_focus_child);

  return TRUE;
}

typedef struct {
  EggListBoxChildInfo *child;
  GtkStateFlags state;
} ChildFlags;

static ChildFlags*
child_flags_find_or_add (ChildFlags *array,
			 int *array_length,
			 EggListBoxChildInfo *to_find)
{
  gint i;

  for (i = 0; i < *array_length; i++)
    {
      if (array[i].child == to_find)
	return &array[i];
    }

  *array_length = *array_length + 1;
  array[*array_length - 1].child = to_find;
  array[*array_length - 1].state = 0;
  return &array[*array_length - 1];
}

static gboolean
egg_list_box_real_draw (GtkWidget* base, cairo_t* cr)
{
  EggListBox * self = EGG_LIST_BOX (base);
  GtkAllocation allocation = {0};
  GtkStyleContext* context;
  ChildFlags flags[3], *found;
  gint flags_length;
  int i;

  gtk_widget_get_allocation ((GtkWidget*) self, &allocation);
  context = gtk_widget_get_style_context ((GtkWidget*) self);
  gtk_render_background (context, cr, (gdouble) 0, (gdouble) 0, (gdouble) allocation.width, (gdouble) allocation.height);
  flags_length = 0;

  if (self->priv->selected_child != NULL)
    {
      found = child_flags_find_or_add (flags, &flags_length, self->priv->selected_child);
      found->state |= GTK_STATE_FLAG_SELECTED;
    }

  if (self->priv->prelight_child != NULL)
    {
      found = child_flags_find_or_add (flags, &flags_length, self->priv->prelight_child);
      found->state |= GTK_STATE_FLAG_PRELIGHT;
    }

  if (self->priv->active_child != NULL && self->priv->active_child_active)
    {
      found = child_flags_find_or_add (flags, &flags_length, self->priv->active_child);
      found->state |= GTK_STATE_FLAG_ACTIVE;
    }

  for (i = 0; i < flags_length; i++)
    {
      ChildFlags *flag = &flags[i];
      gtk_style_context_save (context);
      gtk_style_context_set_state (context, flag->state);
      gtk_render_background (context, cr, 0, flag->child->y, allocation.width, flag->child->height);
      gtk_style_context_restore (context);
    }

  if (gtk_widget_has_visible_focus ((GtkWidget*) self) && self->priv->cursor_child != NULL)
    gtk_render_focus (context, cr, 0, self->priv->cursor_child->y, allocation.width, self->priv->cursor_child->height);

  GTK_WIDGET_CLASS (egg_list_box_parent_class)->draw ((GtkWidget*) G_TYPE_CHECK_INSTANCE_CAST (self, GTK_TYPE_CONTAINER, GtkContainer), cr);

  return TRUE;
}


static void
egg_list_box_real_realize (GtkWidget* base)
{
  EggListBox *self = EGG_LIST_BOX (base);
  GtkAllocation allocation;
  GdkWindowAttr attributes = {0};
  GdkWindow *window;

  gtk_widget_get_allocation ((GtkWidget*) self, &allocation);
  gtk_widget_set_realized ((GtkWidget*) self, TRUE);

  attributes.x = allocation.x;
  attributes.y = allocation.y;
  attributes.width = allocation.width;
  attributes.height = allocation.height;
  attributes.window_type = GDK_WINDOW_CHILD;
  attributes.event_mask = gtk_widget_get_events ((GtkWidget*) self) |
    GDK_ENTER_NOTIFY_MASK | GDK_LEAVE_NOTIFY_MASK | GDK_POINTER_MOTION_MASK |
    GDK_EXPOSURE_MASK | GDK_BUTTON_PRESS_MASK | GDK_BUTTON_RELEASE_MASK;
  attributes.wclass = GDK_INPUT_OUTPUT;

  window = gdk_window_new (gtk_widget_get_parent_window ((GtkWidget*) self),
			   &attributes, GDK_WA_X | GDK_WA_Y);
  gtk_style_context_set_background (gtk_widget_get_style_context ((GtkWidget*) self), window);
  gdk_window_set_user_data (window, (GObject*) self);
  gtk_widget_set_window ((GtkWidget*) self, window); /* Passes ownership */
}


static void
egg_list_box_apply_filter (EggListBox *self, GtkWidget *child)
{
  gboolean do_show;

  do_show = TRUE;
  if (self->priv->filter_func != NULL)
    do_show = self->priv->filter_func (child, self->priv->filter_func_target);

  gtk_widget_set_child_visible (child, do_show);
}

static void
egg_list_box_apply_filter_all (EggListBox *self)
{
  EggListBoxChildInfo *child_info;
  GSequenceIter *iter;

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
      child_info = g_sequence_get (iter);
      egg_list_box_apply_filter (self, child_info->widget);
    }
}

static EggListBoxChildInfo*
egg_list_box_get_first_visible (EggListBox *self)
{
  EggListBoxChildInfo *child_info;
  GSequenceIter *iter;
  GtkWidget *child;

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
	child_info = g_sequence_get (iter);
	child = child_info->widget;
	if (gtk_widget_get_visible (child) &&
	    gtk_widget_get_child_visible (child))
	  return child_info;
    }

  return NULL;
}


static EggListBoxChildInfo*
egg_list_box_get_last_visible (EggListBox *self)
{
  EggListBoxChildInfo *child_info;
  GSequenceIter* iter;
  GtkWidget* child;

  iter = g_sequence_get_end_iter (self->priv->children);
  while (!g_sequence_iter_is_begin (iter))
    {
      iter = g_sequence_iter_prev (iter);
      child_info = g_sequence_get (iter);
      child = child_info->widget;
      if (gtk_widget_get_visible (child) &&
	  gtk_widget_get_child_visible (child))
	return child_info;
    }

  return NULL;
}

static GSequenceIter*
egg_list_box_get_previous_visible (EggListBox *self,
				   GSequenceIter* iter)
{
  EggListBoxChildInfo *child_info;
  GtkWidget *child;

  if (g_sequence_iter_is_begin (iter))
    return NULL;

  do
    {
      iter = g_sequence_iter_prev (iter);
      child_info = g_sequence_get (iter);
      child = child_info->widget;
      if (gtk_widget_get_visible (child) &&
	  gtk_widget_get_child_visible (child))
	return iter;
    }
  while (!g_sequence_iter_is_begin (iter));

  return NULL;
}

static GSequenceIter*
egg_list_box_get_next_visible (EggListBox *self, GSequenceIter* iter)
{
  EggListBoxChildInfo *child_info;
  GtkWidget *child;

  if (g_sequence_iter_is_end (iter))
    return iter;

  do
    {
      iter = g_sequence_iter_next (iter);
      if (!g_sequence_iter_is_end (iter))
	{
	child_info = g_sequence_get (iter);
	child = child_info->widget;
	if (gtk_widget_get_visible (child) &&
	    gtk_widget_get_child_visible (child))
	  return iter;
	}
    }
  while (!g_sequence_iter_is_end (iter));

  return iter;
}


static void
egg_list_box_update_separator (EggListBox *self, GSequenceIter* iter)
{
  EggListBoxChildInfo *info;
  GSequenceIter *before_iter;
  GtkWidget *child;
  GtkWidget *before_child;
  EggListBoxChildInfo *before_info;
  GtkWidget *old_separator;

  if (iter == NULL || g_sequence_iter_is_end (iter))
    return;

  info = g_sequence_get (iter);
  before_iter = egg_list_box_get_previous_visible (self, iter);
  child = _g_object_ref0 (info->widget);
  before_child = NULL;
  if (before_iter != NULL)
    {
      before_info = g_sequence_get (before_iter);
      before_child = _g_object_ref0 (before_info->widget);
    }

  if (self->priv->update_separator_func != NULL &&
      gtk_widget_get_visible (child) &&
      gtk_widget_get_child_visible (child))
    {
      old_separator = _g_object_ref0 (info->separator);
      self->priv->update_separator_func (&info->separator,
					 child,
					 before_child,
					 self->priv->update_separator_func_target);
      if (old_separator != info->separator)
	{
	  if (old_separator != NULL)
	    {
	      gtk_widget_unparent (old_separator);
	      g_hash_table_remove (self->priv->separator_hash, old_separator);
	    }
	  if (info->separator != NULL)
	    {
	      g_hash_table_insert (self->priv->separator_hash, info->separator, info);
	      gtk_widget_set_parent (info->separator, (GtkWidget*) self);
	      gtk_widget_show (info->separator);
	    }
	  gtk_widget_queue_resize ((GtkWidget*) self);
	}
      _g_object_unref0 (old_separator);
    }
  else
    {
      if (info->separator != NULL)
	{
	  g_hash_table_remove (self->priv->separator_hash, info->separator);
	  gtk_widget_unparent (info->separator);
	  _g_object_unref0 (info->separator);
	  gtk_widget_queue_resize ((GtkWidget*) self);
	}
    }
  _g_object_unref0 (before_child);
  _g_object_unref0 (child);
}

static EggListBoxChildInfo*
egg_list_box_lookup_info (EggListBox *self, GtkWidget* child)
{
  return g_hash_table_lookup (self->priv->child_hash, child);
}

static void
_egg_list_box_child_visibility_changed_g_object_notify (GObject* _sender, GParamSpec* pspec, gpointer self)
{
  egg_list_box_child_visibility_changed (self, _sender, pspec);
}

static void
egg_list_box_real_add (GtkContainer* container, GtkWidget* child)
{
  EggListBox *self = EGG_LIST_BOX (container);
  EggListBoxChildInfo *info;
  GSequenceIter* iter = NULL;
  info = egg_list_box_child_info_new (child);
  g_hash_table_insert (self->priv->child_hash, child, info);
  if (self->priv->sort_func != NULL)
    iter = g_sequence_insert_sorted (self->priv->children, info,
				     (GCompareDataFunc)do_sort, self);
  else
    iter = g_sequence_append (self->priv->children, info);

  info->iter = iter;
  gtk_widget_set_parent (child, (GtkWidget*) self);
  egg_list_box_apply_filter (self, child);
  if (gtk_widget_get_visible ((GtkWidget*) self))
    {
      egg_list_box_update_separator (self, iter);
      egg_list_box_update_separator (self, egg_list_box_get_next_visible (self, iter));
    }
  g_signal_connect_object (child, "notify::visible",
			   (GCallback) _egg_list_box_child_visibility_changed_g_object_notify, self, 0);
}

static void
egg_list_box_child_visibility_changed (EggListBox *self, GObject* object, GParamSpec* pspec)
{
  EggListBoxChildInfo *info;

  if (gtk_widget_get_visible ((GtkWidget*) self))
    {
      info = egg_list_box_lookup_info (self, GTK_WIDGET (object));
      if (info != NULL)
	{
	  egg_list_box_update_separator (self, info->iter);
	  egg_list_box_update_separator (self,
					 egg_list_box_get_next_visible (self, info->iter));
	}
    }
}

static void
egg_list_box_real_remove (GtkContainer* container, GtkWidget* child)
{
  EggListBox *self = EGG_LIST_BOX (container);
  gboolean was_visible;
  EggListBoxChildInfo *info;
  GSequenceIter *next;

  g_return_if_fail (child != NULL);
  was_visible = gtk_widget_get_visible (child);

  g_signal_handlers_disconnect_by_func (child, (GCallback) _egg_list_box_child_visibility_changed_g_object_notify, self);

  info = egg_list_box_lookup_info (self, child);
  if (info == NULL)
    {
      info = g_hash_table_lookup (self->priv->separator_hash, child);
      if (info != NULL)
	{
	  g_hash_table_remove (self->priv->separator_hash, child);
	  _g_object_unref0 (info->separator);
	  info->separator = NULL;
	  gtk_widget_unparent (child);
	  if (was_visible && gtk_widget_get_visible ((GtkWidget*) self))
	    gtk_widget_queue_resize ((GtkWidget*) self);
	}
      else
	{
	  g_warning ("egg-list-box.vala:846: Tried to remove non-child %p\n", child);
	}
      return;
    }

  if (info->separator != NULL)
    {
      g_hash_table_remove (self->priv->separator_hash, info->separator);
      gtk_widget_unparent (info->separator);
      _g_object_unref0 (info->separator);
      info->separator = NULL;
    }

  if (info == self->priv->selected_child)
      egg_list_box_update_selected (self, NULL);
  if (info == self->priv->prelight_child)
    self->priv->prelight_child = NULL;
  if (info == self->priv->cursor_child)
    self->priv->cursor_child = NULL;
  if (info == self->priv->active_child)
    self->priv->active_child = NULL;

  next = egg_list_box_get_next_visible (self, info->iter);
  gtk_widget_unparent (child);
  g_hash_table_remove (self->priv->child_hash, child);
  g_sequence_remove (info->iter);
  if (gtk_widget_get_visible ((GtkWidget*) self))
    egg_list_box_update_separator (self, next);

  if (was_visible && gtk_widget_get_visible ((GtkWidget*) self))
    gtk_widget_queue_resize ((GtkWidget*) self);
}


static void
egg_list_box_real_forall_internal (GtkContainer* container,
				   gboolean include_internals,
				   GtkCallback callback,
				   void* callback_target)
{
  EggListBox *self = EGG_LIST_BOX (container);
  GSequenceIter *iter;
  EggListBoxChildInfo *child_info;


  iter = g_sequence_get_begin_iter (self->priv->children);
  while (!g_sequence_iter_is_end (iter))
    {
      child_info = g_sequence_get (iter);
      iter = g_sequence_iter_next (iter);
      if (child_info->separator != NULL && include_internals)
	callback (child_info->separator, callback_target);
      callback (child_info->widget, callback_target);
    }
}

static void
egg_list_box_real_compute_expand_internal (GtkWidget* base,
					   gboolean* hexpand,
					   gboolean* vexpand)
{
  GTK_WIDGET_CLASS (egg_list_box_parent_class)->compute_expand (base,
								hexpand, vexpand);

  /* We don't expand vertically beyound the minimum size */
  if (vexpand)
    *vexpand = FALSE;
}

static GType
egg_list_box_real_child_type (GtkContainer* container)
{
  return GTK_TYPE_WIDGET;
}

static GtkSizeRequestMode
egg_list_box_real_get_request_mode (GtkWidget* base)
{
  return GTK_SIZE_REQUEST_HEIGHT_FOR_WIDTH;
}

static void
egg_list_box_real_get_preferred_height (GtkWidget* base,
					gint* minimum_height,
					gint* natural_height)
{
  gint natural_width;
  egg_list_box_real_get_preferred_width (base, NULL, &natural_width);
  egg_list_box_real_get_preferred_height_for_width (base, natural_width,
						    minimum_height, natural_height);
}

static void
egg_list_box_real_get_preferred_height_for_width (GtkWidget* base, gint width,
						  gint* minimum_height_out, gint* natural_height_out)
{
  EggListBox *self = EGG_LIST_BOX (base);
  GSequenceIter *iter;
  gint minimum_height;
  gint natural_height;
  GtkStyleContext *context;
  gint focus_width;
  gint focus_pad;

  minimum_height = 0;

  context = gtk_widget_get_style_context ((GtkWidget*) self);
  gtk_style_context_get_style (context,
			       "focus-line-width", &focus_width,
			       "focus-padding", &focus_pad, NULL);

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
      EggListBoxChildInfo *child_info;
      GtkWidget *child;
      gint child_min = 0;
      child_info = g_sequence_get (iter);
      child = child_info->widget;

      if (!(gtk_widget_get_visible (child) &&
	    gtk_widget_get_child_visible (child)))
	continue;

      if (child_info->separator != NULL)
	{
	  gtk_widget_get_preferred_height_for_width (child_info->separator, width, &child_min, NULL);
	  minimum_height += child_min;
	}
      gtk_widget_get_preferred_height_for_width (child, width - 2 * (focus_width + focus_pad),
						 &child_min, NULL);
      minimum_height += child_min + 2 * (focus_width + focus_pad);
    }

  /* We always allocate the minimum height, since handling
     expanding rows is way too costly, and unlikely to
     be used, as lists are generally put inside a scrolling window
     anyway.
  */
  natural_height = minimum_height;
  if (minimum_height_out)
    *minimum_height_out = minimum_height;
  if (natural_height_out)
    *natural_height_out = natural_height;
}

static void
egg_list_box_real_get_preferred_width (GtkWidget* base, gint* minimum_width_out, gint* natural_width_out)
{
  EggListBox *self = EGG_LIST_BOX (base);
  gint minimum_width;
  gint natural_width;
  GtkStyleContext *context;
  gint focus_width;
  gint focus_pad;
  GSequenceIter *iter;
  EggListBoxChildInfo *child_info;
  GtkWidget *child;
  gint child_min;
  gint child_nat;

  context = gtk_widget_get_style_context ((GtkWidget*) self);
  gtk_style_context_get_style (context, "focus-line-width", &focus_width, "focus-padding", &focus_pad, NULL);

  minimum_width = 0;
  natural_width = 0;

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
      child_info = g_sequence_get (iter);
      child = child_info->widget;
      if (!(gtk_widget_get_visible (child) && gtk_widget_get_child_visible (child)))
	continue;

      gtk_widget_get_preferred_width (child, &child_min, &child_nat);
      minimum_width = MAX (minimum_width, child_min + 2 * (focus_width + focus_pad));
      natural_width = MAX (natural_width, child_nat + 2 * (focus_width + focus_pad));

      if (child_info->separator != NULL)
	{
	  gtk_widget_get_preferred_width (child_info->separator, &child_min, &child_nat);
	  minimum_width = MAX (minimum_width, child_min);
	  natural_width = MAX (natural_width, child_nat);
	}
    }

  if (minimum_width_out)
    *minimum_width_out = minimum_width;
  if (natural_width_out)
    *natural_width_out = natural_width;
}

static void
egg_list_box_real_get_preferred_width_for_height (GtkWidget *base, gint height,
						  gint *minimum_width, gint *natural_width)
{
  EggListBox *self = EGG_LIST_BOX (base);
  egg_list_box_real_get_preferred_width ((GtkWidget*) self, minimum_width, natural_width);
}

static void
egg_list_box_real_size_allocate (GtkWidget *base, GtkAllocation *allocation)
{
  EggListBox *self = EGG_LIST_BOX (base);
  GtkAllocation child_allocation;
  GtkAllocation separator_allocation;
  EggListBoxChildInfo *child_info;
  GdkWindow *window;
  GtkWidget *child;
  GSequenceIter *iter;
  GtkStyleContext *context;
  gint focus_width;
  gint focus_pad;
  int child_min;


  child_allocation.x = 0;
  child_allocation.y = 0;
  child_allocation.width = 0;
  child_allocation.height = 0;

  separator_allocation.x = 0;
  separator_allocation.y = 0;
  separator_allocation.width = 0;
  separator_allocation.height = 0;

  gtk_widget_set_allocation ((GtkWidget*) self, allocation);
  window = gtk_widget_get_window ((GtkWidget*) self);
  if (window != NULL)
    gdk_window_move_resize (window,
			    allocation->x, allocation->y,
			    allocation->width, allocation->height);

  context = gtk_widget_get_style_context ((GtkWidget*) self);
  gtk_style_context_get_style (context,
			       "focus-line-width", &focus_width,
			       "focus-padding", &focus_pad,
			       NULL);
  child_allocation.x = 0 + focus_width + focus_pad;
  child_allocation.y = 0;
  child_allocation.width = allocation->width - 2 * (focus_width + focus_pad);
  separator_allocation.x = 0;
  separator_allocation.width = allocation->width;

  for (iter = g_sequence_get_begin_iter (self->priv->children);
       !g_sequence_iter_is_end (iter);
       iter = g_sequence_iter_next (iter))
    {
      child_info = g_sequence_get (iter);
      child = child_info->widget;
      if (!(gtk_widget_get_visible (child) && gtk_widget_get_child_visible (child)))
	{
	  child_info->y = child_allocation.y;
	  child_info->height = 0;
	  continue;
	}

      if (child_info->separator != NULL)
	{
	  gtk_widget_get_preferred_height_for_width (child_info->separator,
						     allocation->width, &child_min, NULL);
	  separator_allocation.height = child_min;
	  separator_allocation.y = child_allocation.y;
	  gtk_widget_size_allocate (child_info->separator,
				    &separator_allocation);
	  child_allocation.y += child_min;
	}

      child_info->y = child_allocation.y;
      child_allocation.y += focus_width + focus_pad;

      gtk_widget_get_preferred_height_for_width (child, child_allocation.width, &child_min, NULL);
      child_allocation.height = child_min;

      child_info->height = child_allocation.height + 2 * (focus_width + focus_pad);
      gtk_widget_size_allocate (child, &child_allocation);

      child_allocation.y += child_min + focus_width + focus_pad;
    }
}

void
egg_list_box_drag_unhighlight_widget (EggListBox *self)
{
  g_return_if_fail (self != NULL);

  if (self->priv->drag_highlighted_widget == NULL)
    return;

  gtk_drag_unhighlight (self->priv->drag_highlighted_widget);
  g_object_unref (self->priv->drag_highlighted_widget);
  self->priv->drag_highlighted_widget = NULL;
}


void
egg_list_box_drag_highlight_widget (EggListBox *self, GtkWidget *child)
{
  GtkWidget *old_highlight;

  g_return_if_fail (self != NULL);
  g_return_if_fail (child != NULL);

  if (self->priv->drag_highlighted_widget == child)
    return;

  egg_list_box_drag_unhighlight_widget (self);
  gtk_drag_highlight (child);

  old_highlight = self->priv->drag_highlighted_widget;
  self->priv->drag_highlighted_widget = g_object_ref (child);
  if (old_highlight)
    g_object_unref (old_highlight);
}

static void
egg_list_box_real_drag_leave (GtkWidget *base, GdkDragContext *context, guint time_)
{
  EggListBox *self = EGG_LIST_BOX (base);

  egg_list_box_drag_unhighlight_widget (self);
  if (self->priv->auto_scroll_timeout_id != 0) {
    g_source_remove (self->priv->auto_scroll_timeout_id);
    self->priv->auto_scroll_timeout_id = 0;
  }
}

typedef struct
{
  EggListBox *self;
  gint move;
} MoveData;

static void
move_data_free (MoveData *data)
{
  g_slice_free (MoveData, data);
}

static gboolean
drag_motion_timeout (MoveData *data)
{
  EggListBox *self = data->self;

  gtk_adjustment_set_value (self->priv->adjustment,
			    gtk_adjustment_get_value (self->priv->adjustment) +
			    gtk_adjustment_get_step_increment (self->priv->adjustment) * data->move);
  return TRUE;
}

static gboolean
egg_list_box_real_drag_motion (GtkWidget *base, GdkDragContext *context,
			       gint x, gint y, guint time_)
{
  EggListBox *self = EGG_LIST_BOX (base);
  int move;
  MoveData *data;
  gdouble size;

  /* Auto-scroll during Dnd if cursor is moving into the top/bottom portion of the
     * box. */
  if (self->priv->auto_scroll_timeout_id != 0)
    {
      g_source_remove (self->priv->auto_scroll_timeout_id);
      self->priv->auto_scroll_timeout_id = 0;
    }

  if (self->priv->adjustment == NULL)
    return FALSE;

  /* Part of the view triggering auto-scroll */
  size = 30;
  move = 0;

  if (y < (gtk_adjustment_get_value (self->priv->adjustment) + size))
    {
      /* Scroll up */
      move = -1;
    }
  else if (y > ((gtk_adjustment_get_value (self->priv->adjustment) + gtk_adjustment_get_page_size (self->priv->adjustment)) - size))
    {
      /* Scroll down */
      move = 1;
    }

  if (move == 0)
    return FALSE;

  data = g_slice_new0 (MoveData);
  data->self = self;

  self->priv->auto_scroll_timeout_id =
    g_timeout_add_full (G_PRIORITY_DEFAULT, 150, (GSourceFunc)drag_motion_timeout,
			data, (GDestroyNotify) move_data_free);

  return FALSE;
}

static void
egg_list_box_real_activate_cursor_child (EggListBox *self)
{
  egg_list_box_select_and_activate (self, self->priv->cursor_child);
}

static void
egg_list_box_real_toggle_cursor_child (EggListBox *self)
{
  if (self->priv->cursor_child == NULL)
    return;

  if (self->priv->selection_mode == GTK_SELECTION_SINGLE &&
      self->priv->selected_child == self->priv->cursor_child)
    egg_list_box_update_selected (self, NULL);
  else
    egg_list_box_select_and_activate (self, self->priv->cursor_child);
}

static void
egg_list_box_real_move_cursor (EggListBox *self, GtkMovementStep step, gint count)
{
  GdkModifierType state;
  gboolean modify_selection_pressed;
  EggListBoxChildInfo *child;
  GdkModifierType modify_mod_mask;
  EggListBoxChildInfo *prev;
  EggListBoxChildInfo *next;
  gint page_size;
  GSequenceIter *iter;
  gint start_y;
  gint end_y;

  modify_selection_pressed = FALSE;

  if (gtk_get_current_event_state (&state))
    {
      modify_mod_mask = gtk_widget_get_modifier_mask ((GtkWidget*) self,
						      GDK_MODIFIER_INTENT_MODIFY_SELECTION);
      if ((state & modify_mod_mask) == modify_mod_mask)
	modify_selection_pressed = TRUE;
    }

  child = NULL;
  switch (step)
    {
    case GTK_MOVEMENT_BUFFER_ENDS:
      if (count < 0)
	child = egg_list_box_get_first_visible (self);
      else
	child = egg_list_box_get_last_visible (self);
      break;
    case GTK_MOVEMENT_DISPLAY_LINES:
      if (self->priv->cursor_child != NULL)
	{
	  iter = self->priv->cursor_child->iter;

	  while (count < 0  && iter != NULL)
	    {
	      iter = egg_list_box_get_previous_visible (self, iter);
	      count = count + 1;
	    }
	  while (count > 0  && iter != NULL)
	    {
	      iter = egg_list_box_get_next_visible (self, iter);
	      count = count - 1;
	    }

	  if (iter != NULL && !g_sequence_iter_is_end (iter))
	    child = g_sequence_get (iter);
	}
      break;
    case GTK_MOVEMENT_PAGES:
      page_size = 100;
      if (self->priv->adjustment != NULL)
	page_size = gtk_adjustment_get_page_increment (self->priv->adjustment);

      if (self->priv->cursor_child != NULL)
	{
	  start_y = self->priv->cursor_child->y;
	  end_y = start_y;
	  iter = self->priv->cursor_child->iter;

	  child = self->priv->cursor_child;
	  if (count < 0)
	    {
	      /* Up */
	      while (iter != NULL && !g_sequence_iter_is_begin (iter))
		{
		  iter = egg_list_box_get_previous_visible (self, iter);
		  if (iter == NULL)
		    break;

		  prev = g_sequence_get (iter);
		  if (prev->y < start_y - page_size)
		    break;

		  child = prev;
		}
	    }
	  else
	    {
	      /* Down */
	      while (iter != NULL && !g_sequence_iter_is_end (iter))
		{
		  iter = egg_list_box_get_next_visible (self, iter);
		  if (g_sequence_iter_is_end (iter))
		    break;

		  next = g_sequence_get (iter);
		  if (next->y > start_y + page_size)
		    break;

		  child = next;
		}
	    }
	  end_y = child->y;
	  if (end_y != start_y && self->priv->adjustment != NULL)
	    gtk_adjustment_set_value (self->priv->adjustment,
				      gtk_adjustment_get_value (self->priv->adjustment) +
				      end_y - start_y);
	}
      break;
    default:
      return;
    }

  if (child == NULL)
    {
      gtk_widget_error_bell ((GtkWidget*) self);
      return;
    }

  egg_list_box_update_cursor (self, child);
  if (!modify_selection_pressed)
    egg_list_box_update_selected (self, child);
}
