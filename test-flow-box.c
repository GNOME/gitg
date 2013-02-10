/*
 * Copyright (C) 2010 Openismus GmbH
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#include <gtk/gtk.h>
#include "egg-flow-box.h"

enum {
  SIMPLE_ITEMS = 0,
  WRAPPY_ITEMS,
  STOCK_ITEMS,
  IMAGE_ITEMS
};

#define INITIAL_HALIGN          GTK_ALIGN_FILL
#define INITIAL_VALIGN          GTK_ALIGN_START
#define INITIAL_MINIMUM_LENGTH  3
#define INITIAL_MAXIMUM_LENGTH  6
#define INITIAL_CSPACING        2
#define INITIAL_RSPACING        2
#define N_ITEMS 4000

static EggFlowBox    *the_flowbox       = NULL;
static gint           items_type       = SIMPLE_ITEMS;
static GtkOrientation text_orientation = GTK_ORIENTATION_HORIZONTAL;

static void
populate_flowbox_simple (EggFlowBox *flowbox)
{
  GtkWidget *widget, *frame;
  gint i;

  for (i = 0; i < N_ITEMS; i++)
    {
      gchar *text = g_strdup_printf ("Item %02d", i);

      widget = gtk_label_new (text);
      frame  = gtk_frame_new (NULL);
      gtk_widget_show (widget);
      gtk_widget_show (frame);

      gtk_container_add (GTK_CONTAINER (frame), widget);

      if (text_orientation == GTK_ORIENTATION_VERTICAL)
        gtk_label_set_angle (GTK_LABEL (widget), 90);
      g_object_set_data_full (G_OBJECT (frame), "id", (gpointer)g_strdup (text), g_free);
      gtk_container_add (GTK_CONTAINER (flowbox), frame);

      g_free (text);
    }
}

static void
populate_flowbox_wrappy (EggFlowBox *flowbox)
{
  GtkWidget *widget, *frame;
  gint i;

  const gchar *strings[] = {
    "These are", "some wrappy label", "texts", "of various", "lengths.",
    "They should always be", "shown", "consecutively. Except it's",
    "hard to say", "where exactly the", "label", "will wrap", "and where exactly",
    "the actual", "container", "will wrap.", "This label is really really really long !",
    "Let's add some more", "labels to the",
    "mix. Just to", "make sure we", "got something to work", "with here."
  };

  for (i = 0; i < G_N_ELEMENTS (strings); i++)
    {
      widget = gtk_label_new (strings[i]);
      frame  = gtk_frame_new (NULL);
      gtk_widget_show (widget);
      gtk_widget_show (frame);

      if (text_orientation == GTK_ORIENTATION_VERTICAL)
        gtk_label_set_angle (GTK_LABEL (widget), 90);

      gtk_container_add (GTK_CONTAINER (frame), widget);

      gtk_label_set_line_wrap (GTK_LABEL (widget), TRUE);
      gtk_label_set_line_wrap_mode (GTK_LABEL (widget), PANGO_WRAP_WORD);
      gtk_label_set_width_chars (GTK_LABEL (widget), 10);
      g_object_set_data_full (G_OBJECT (frame), "id", (gpointer)g_strdup (strings[i]), g_free);

      gtk_container_add (GTK_CONTAINER (flowbox), frame);
    }
}

static void
populate_flowbox_stock (EggFlowBox *flowbox)
{
  GtkWidget *widget;
  static GSList *stock_ids = NULL;
  GSList *l;
  gint i;

  if (!stock_ids)
    stock_ids = gtk_stock_list_ids ();

  for (i = 0, l = stock_ids; i < 30 && l != NULL; i++, l = l->next)
    {
      gchar *stock_id = l->data;
      gchar *text = g_strdup_printf ("Item %02d", i);

      widget = gtk_button_new_from_stock (stock_id);
      gtk_widget_show (widget);

      g_object_set_data_full (G_OBJECT (widget), "id", (gpointer)g_strdup (text), g_free);
      gtk_container_add (GTK_CONTAINER (flowbox), widget);
    }
}

static void
populate_flowbox_images (EggFlowBox *flowbox)
{
  GtkWidget *widget, *image, *label;
  gint i;

  for (i = 0; i < N_ITEMS; i++)
    {
      gchar *text = g_strdup_printf ("Item %02d", i);

      widget = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);
      gtk_widget_set_hexpand (widget, TRUE);

      image = gtk_image_new_from_icon_name ("face-wink", GTK_ICON_SIZE_DIALOG);
      gtk_widget_set_hexpand (image, TRUE);
      gtk_image_set_pixel_size (GTK_IMAGE (image), 256);

      label = gtk_label_new (text);

      gtk_container_add (GTK_CONTAINER (widget), image);
      gtk_container_add (GTK_CONTAINER (widget), label);
      gtk_widget_show_all (widget);

      if (text_orientation == GTK_ORIENTATION_VERTICAL)
        gtk_label_set_angle (GTK_LABEL (widget), 90);

      g_object_set_data_full (G_OBJECT (widget), "id", (gpointer)g_strdup (text), g_free);
      gtk_container_add (GTK_CONTAINER (flowbox), widget);

      g_free (text);
    }
}

static void
populate_items (EggFlowBox *flowbox)
{
  GList *children, *l;

  /* Remove all children first */
  children = gtk_container_get_children (GTK_CONTAINER (flowbox));
  for (l = children; l; l = l->next)
    {
      GtkWidget *child = l->data;

      gtk_container_remove (GTK_CONTAINER (flowbox), child);
    }
  g_list_free (children);

  if (items_type == SIMPLE_ITEMS)
    populate_flowbox_simple (flowbox);
  else if (items_type == WRAPPY_ITEMS)
    populate_flowbox_wrappy (flowbox);
  else if (items_type == STOCK_ITEMS)
    populate_flowbox_stock (flowbox);
  else if (items_type == IMAGE_ITEMS)
    populate_flowbox_images (flowbox);
}

static void
horizontal_alignment_changed (GtkComboBox   *box,
                              EggFlowBox    *flowbox)
{
  GtkAlign alignment = gtk_combo_box_get_active (box);

  egg_flow_box_set_halign_policy (flowbox, alignment);
}

static void
vertical_alignment_changed (GtkComboBox   *box,
                            EggFlowBox    *flowbox)
{
  GtkAlign alignment = gtk_combo_box_get_active (box);

  egg_flow_box_set_valign_policy (flowbox, alignment);
}

static void
orientation_changed (GtkComboBox   *box,
                     EggFlowBox *flowbox)
{
  GtkOrientation orientation = gtk_combo_box_get_active (box);

  gtk_orientable_set_orientation (GTK_ORIENTABLE (flowbox), orientation);
}

static void
selection_mode_changed (GtkComboBox *box,
                        EggFlowBox  *flowbox)
{
  GtkSelectionMode mode = gtk_combo_box_get_active (box);

  egg_flow_box_set_selection_mode (flowbox, mode);
}

static void
line_length_changed (GtkSpinButton *spin,
                     EggFlowBox *flowbox)
{
  gint length = gtk_spin_button_get_value_as_int (spin);

  egg_flow_box_set_min_children_per_line (flowbox, length);
}

static void
max_line_length_changed (GtkSpinButton *spin,
                         EggFlowBox *flowbox)
{
  gint length = gtk_spin_button_get_value_as_int (spin);

  egg_flow_box_set_max_children_per_line (flowbox, length);
}

static void
spacing_changed (GtkSpinButton *button,
                 gpointer       data)
{
  GtkOrientation orientation = GPOINTER_TO_INT (data);
  gint           state = gtk_spin_button_get_value_as_int (button);

  if (orientation == GTK_ORIENTATION_HORIZONTAL)
    egg_flow_box_set_column_spacing (the_flowbox, state);
  else
    egg_flow_box_set_row_spacing (the_flowbox, state);
}

static void
items_changed (GtkComboBox   *box,
               EggFlowBox *flowbox)
{
  items_type = gtk_combo_box_get_active (box);

  populate_items (flowbox);
}

static void
text_orientation_changed (GtkComboBox   *box,
                          EggFlowBox *flowbox)
{
  text_orientation = gtk_combo_box_get_active (box);

  populate_items (flowbox);
}

static void
homogeneous_toggled (GtkToggleButton *button,
                     EggFlowBox      *flowbox)
{
  gboolean state = gtk_toggle_button_get_active (button);

  egg_flow_box_set_homogeneous (flowbox, state);
}

static void
on_child_activated (EggFlowBox *self,
                    GtkWidget  *child)
{
  const char *id;
  id = g_object_get_data (G_OBJECT (child), "id");
  g_message ("Child activated %p: %s", child, id);
}

static void
selection_foreach (EggFlowBox *self,
                   GtkWidget  *child,
                   gpointer    data)
{
  const char *id;
  id = g_object_get_data (G_OBJECT (child), "id");
  g_message ("Child selected %p: %s", child, id);
}

static void
on_selected_children_changed (EggFlowBox *self)
{
  g_message ("Selection changed");
  egg_flow_box_selected_foreach (self, selection_foreach, NULL);
}

static GtkWidget *
create_window (void)
{
  GtkWidget *window, *hbox, *vbox, *flowbox_cntl, *items_cntl;
  GtkWidget *flowbox, *widget, *expander, *swindow;

  window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
  hbox   = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 6);
  vbox   = gtk_box_new (GTK_ORIENTATION_VERTICAL, 6);

  gtk_container_set_border_width (GTK_CONTAINER (window), 8);

  gtk_widget_show (vbox);
  gtk_widget_show (hbox);
  gtk_container_add (GTK_CONTAINER (window), hbox);
  gtk_box_pack_start (GTK_BOX (hbox), vbox, FALSE, FALSE, 0);

  swindow = gtk_scrolled_window_new (NULL, NULL);
  gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (swindow),
                                  GTK_POLICY_AUTOMATIC, GTK_POLICY_AUTOMATIC);

  gtk_widget_show (swindow);
  gtk_box_pack_start (GTK_BOX (hbox), swindow, TRUE, TRUE, 0);

  flowbox = egg_flow_box_new ();
  the_flowbox = (EggFlowBox *)flowbox;
  egg_flow_box_set_halign_policy (EGG_FLOW_BOX (flowbox), INITIAL_HALIGN);
  egg_flow_box_set_valign_policy (EGG_FLOW_BOX (flowbox), INITIAL_VALIGN);
  egg_flow_box_set_column_spacing (EGG_FLOW_BOX (flowbox), INITIAL_CSPACING);
  egg_flow_box_set_row_spacing (EGG_FLOW_BOX (flowbox), INITIAL_RSPACING);
  egg_flow_box_set_min_children_per_line (EGG_FLOW_BOX (flowbox), INITIAL_MINIMUM_LENGTH);
  egg_flow_box_set_max_children_per_line (EGG_FLOW_BOX (flowbox), INITIAL_MAXIMUM_LENGTH);
  gtk_widget_show (flowbox);
  gtk_container_add (GTK_CONTAINER (swindow), flowbox);

  egg_flow_box_set_adjustment (EGG_FLOW_BOX (flowbox),
                               gtk_scrolled_window_get_vadjustment (GTK_SCROLLED_WINDOW (swindow)));

  g_signal_connect (flowbox, "child-activated", G_CALLBACK (on_child_activated), NULL);
  g_signal_connect (flowbox, "selected-children-changed", G_CALLBACK (on_selected_children_changed), NULL);

  /* Add Flowbox test control frame */
  expander = gtk_expander_new ("Flow Box controls");
  gtk_expander_set_expanded (GTK_EXPANDER (expander), TRUE);
  flowbox_cntl = gtk_box_new (GTK_ORIENTATION_VERTICAL, 2);
  gtk_widget_show (flowbox_cntl);
  gtk_widget_show (expander);
  gtk_container_add (GTK_CONTAINER (expander), flowbox_cntl);
  gtk_box_pack_start (GTK_BOX (vbox), expander, FALSE, FALSE, 0);

  widget = gtk_check_button_new_with_label ("Homogeneous");
  gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (widget), FALSE);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set whether the items should be displayed at the same size");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "toggled",
                    G_CALLBACK (homogeneous_toggled), flowbox);

  /* Add alignment controls */
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Fill");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Start");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "End");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Center");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), INITIAL_HALIGN);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the horizontal alignment policy");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (horizontal_alignment_changed), flowbox);

  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Fill");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Start");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "End");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Center");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), INITIAL_VALIGN);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the vertical alignment policy");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (vertical_alignment_changed), flowbox);

  /* Add Orientation control */
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Horizontal");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Vertical");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), 0);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the flowbox orientation");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (orientation_changed), flowbox);

  /* Add selection mode control */
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "None");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Single");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Browse");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Multiple");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), 1);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the selection mode");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (selection_mode_changed), flowbox);

  /* Add minimum line length in items control */
  widget = gtk_spin_button_new_with_range (1, 10, 1);
  gtk_spin_button_set_value (GTK_SPIN_BUTTON (widget), INITIAL_MINIMUM_LENGTH);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the minimum amount of items per line before wrapping");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (line_length_changed), flowbox);
  g_signal_connect (G_OBJECT (widget), "value-changed",
                    G_CALLBACK (line_length_changed), flowbox);

  /* Add natural line length in items control */
  widget = gtk_spin_button_new_with_range (1, 10, 1);
  gtk_spin_button_set_value (GTK_SPIN_BUTTON (widget), INITIAL_MAXIMUM_LENGTH);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the natural amount of items per line ");
  gtk_box_pack_start (GTK_BOX (flowbox_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (max_line_length_changed), flowbox);
  g_signal_connect (G_OBJECT (widget), "value-changed",
                    G_CALLBACK (max_line_length_changed), flowbox);

  /* Add horizontal/vertical spacing controls */
  hbox = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 2);
  gtk_widget_show (hbox);

  widget = gtk_label_new ("H Spacing");
  gtk_widget_show (widget);
  gtk_box_pack_start (GTK_BOX (hbox), widget, TRUE, TRUE, 0);

  widget = gtk_spin_button_new_with_range (0, 30, 1);
  gtk_spin_button_set_value (GTK_SPIN_BUTTON (widget), INITIAL_CSPACING);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the horizontal spacing between children");
  gtk_box_pack_start (GTK_BOX (hbox), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (spacing_changed), GINT_TO_POINTER (GTK_ORIENTATION_HORIZONTAL));
  g_signal_connect (G_OBJECT (widget), "value-changed",
                    G_CALLBACK (spacing_changed), GINT_TO_POINTER (GTK_ORIENTATION_HORIZONTAL));

  gtk_box_pack_start (GTK_BOX (flowbox_cntl), hbox, FALSE, FALSE, 0);

  hbox = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 2);
  gtk_widget_show (hbox);

  widget = gtk_label_new ("V Spacing");
  gtk_widget_show (widget);
  gtk_box_pack_start (GTK_BOX (hbox), widget, TRUE, TRUE, 0);

  widget = gtk_spin_button_new_with_range (0, 30, 1);
  gtk_spin_button_set_value (GTK_SPIN_BUTTON (widget), INITIAL_RSPACING);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the vertical spacing between children");
  gtk_box_pack_start (GTK_BOX (hbox), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (spacing_changed), GINT_TO_POINTER (GTK_ORIENTATION_VERTICAL));
  g_signal_connect (G_OBJECT (widget), "value-changed",
                    G_CALLBACK (spacing_changed), GINT_TO_POINTER (GTK_ORIENTATION_VERTICAL));

  gtk_box_pack_start (GTK_BOX (flowbox_cntl), hbox, FALSE, FALSE, 0);


  /* Add test items control frame */
  expander = gtk_expander_new ("Test item controls");
  gtk_expander_set_expanded (GTK_EXPANDER (expander), TRUE);
  items_cntl = gtk_box_new (GTK_ORIENTATION_VERTICAL, 2);
  gtk_widget_show (items_cntl);
  gtk_widget_show (expander);
  gtk_container_add (GTK_CONTAINER (expander), items_cntl);
  gtk_box_pack_start (GTK_BOX (vbox), expander, FALSE, FALSE, 0);

  /* Add Items control */
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Simple");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Wrappy");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Stock");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Images");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), 0);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the item set to use");
  gtk_box_pack_start (GTK_BOX (items_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (items_changed), flowbox);


  /* Add Text Orientation control */
  widget = gtk_combo_box_text_new ();
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Horizontal");
  gtk_combo_box_text_append_text (GTK_COMBO_BOX_TEXT (widget), "Vertical");
  gtk_combo_box_set_active (GTK_COMBO_BOX (widget), 0);
  gtk_widget_show (widget);

  gtk_widget_set_tooltip_text (widget, "Set the item's text orientation (cant be done for stock buttons)");
  gtk_box_pack_start (GTK_BOX (items_cntl), widget, FALSE, FALSE, 0);

  g_signal_connect (G_OBJECT (widget), "changed",
                    G_CALLBACK (text_orientation_changed), flowbox);

  populate_items (EGG_FLOW_BOX (flowbox));

  /* This line was added only for the convenience of reproducing
   * a height-for-width inside GtkScrolledWindow bug (bug 629778).
   *   -Tristan
   */
  gtk_window_set_default_size (GTK_WINDOW (window), 390, -1);

  return window;
}

int
main (int argc, char *argv[])
{
  GtkWidget *window;

  gtk_init (&argc, &argv);

  window = create_window ();

  g_signal_connect (window, "delete-event",
                    G_CALLBACK (gtk_main_quit), window);

  gtk_widget_show (window);

  gtk_main ();

  return 0;
}
