/*
 * Copyright (C) 2013 Red Hat, Inc.
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see <http://www.gnu.org/licenses/>.
 */

#include "egg-list-box.h"
#include "egg-list-box-accessible.h"

static void atk_selection_interface_init (AtkSelectionIface *iface);

G_DEFINE_TYPE_WITH_CODE (EggListBoxAccessible, egg_list_box_accessible, GTK_TYPE_CONTAINER_ACCESSIBLE,
                         G_IMPLEMENT_INTERFACE (ATK_TYPE_SELECTION, atk_selection_interface_init))

static void
egg_list_box_accessible_init (EggListBoxAccessible *accessible)
{
}

static void
egg_list_box_accessible_initialize (AtkObject *obj,
                                    gpointer   data)
{
  ATK_OBJECT_CLASS (egg_list_box_accessible_parent_class)->initialize (obj, data);

  obj->role = ATK_ROLE_LIST_BOX;
}

static AtkStateSet*
egg_list_box_accessible_ref_state_set (AtkObject *obj)
{
  AtkStateSet *state_set;
  GtkWidget *widget;

  state_set = ATK_OBJECT_CLASS (egg_list_box_accessible_parent_class)->ref_state_set (obj);
  widget = gtk_accessible_get_widget (GTK_ACCESSIBLE (obj));

  if (widget != NULL)
    atk_state_set_add_state (state_set, ATK_STATE_MANAGES_DESCENDANTS);

  return state_set;
}

static void
egg_list_box_accessible_class_init (EggListBoxAccessibleClass *klass)
{
  AtkObjectClass *object_class = ATK_OBJECT_CLASS (klass);

  object_class->initialize = egg_list_box_accessible_initialize;
  object_class->ref_state_set = egg_list_box_accessible_ref_state_set;
}

static gboolean
egg_list_box_accessible_add_selection (AtkSelection *selection,
                                       gint          idx)
{
  GtkWidget *box;
  GList *children;
  GtkWidget *child;

  box = gtk_accessible_get_widget (GTK_ACCESSIBLE (selection));
  if (box == NULL)
    return FALSE;

  children = gtk_container_get_children (GTK_CONTAINER (box));
  child = g_list_nth_data (children, idx);
  g_list_free (children);
  if (child)
    {
      egg_list_box_select_child (EGG_LIST_BOX (box), child);
      return TRUE;
    }
  return FALSE;
}

static gboolean
egg_list_box_accessible_clear_selection (AtkSelection *selection)
{
  GtkWidget *box;

  box = gtk_accessible_get_widget (GTK_ACCESSIBLE (selection));
  if (box == NULL)
    return FALSE;

  egg_list_box_select_child (EGG_LIST_BOX (box), NULL);
  return TRUE;
}

static AtkObject *
egg_list_box_accessible_ref_selection (AtkSelection *selection,
                                       gint          idx)
{
  GtkWidget *box;
  GtkWidget *widget;
  AtkObject *accessible;

  if (idx != 0)
    return NULL;

  box = gtk_accessible_get_widget (GTK_ACCESSIBLE (selection));
  if (box == NULL)
    return NULL;

  widget = egg_list_box_get_selected_child (EGG_LIST_BOX (box));
  if (widget == NULL)
    return NULL;

  accessible = gtk_widget_get_accessible (widget);
  g_object_ref (accessible);
  return accessible;
}

static gint
egg_list_box_accessible_get_selection_count (AtkSelection *selection)
{
  GtkWidget *box;
  GtkWidget *widget;

  box = gtk_accessible_get_widget (GTK_ACCESSIBLE (selection));
  if (box == NULL)
    return 0;

  widget = egg_list_box_get_selected_child (EGG_LIST_BOX (box));
  if (widget == NULL)
    return 0;

  return 1;
}

static gboolean
egg_list_box_accessible_is_child_selected (AtkSelection *selection,
                                           gint          idx)
{
  GtkWidget *box;
  GtkWidget *widget;
  GList *children;
  GtkWidget *child;

  box = gtk_accessible_get_widget (GTK_ACCESSIBLE (selection));
  if (box == NULL)
    return FALSE;

  widget = egg_list_box_get_selected_child (EGG_LIST_BOX (box));
  if (widget == NULL)
    return FALSE;

  children = gtk_container_get_children (GTK_CONTAINER (box));
  child = g_list_nth_data (children, idx);
  g_list_free (children);
  return child == widget;
}

static void atk_selection_interface_init (AtkSelectionIface *iface)
{
  iface->add_selection = egg_list_box_accessible_add_selection;
  iface->clear_selection = egg_list_box_accessible_clear_selection;
  iface->ref_selection = egg_list_box_accessible_ref_selection;
  iface->get_selection_count = egg_list_box_accessible_get_selection_count;
  iface->is_child_selected = egg_list_box_accessible_is_child_selected;
}

void
_egg_list_box_accessible_update_selected (EggListBox *box,
                                          GtkWidget  *child)
{
  AtkObject *accessible;
  accessible = gtk_widget_get_accessible (GTK_WIDGET (box));
  g_signal_emit_by_name (accessible, "selection-changed");
}

void
_egg_list_box_accessible_update_cursor (EggListBox *box,
                                        GtkWidget  *child)
{
  AtkObject *accessible;
  AtkObject *descendant;
  accessible = gtk_widget_get_accessible (GTK_WIDGET (box));
  descendant = child ? gtk_widget_get_accessible (child) : NULL;
  g_signal_emit_by_name (accessible, "active-descendant-changed", descendant);
}
