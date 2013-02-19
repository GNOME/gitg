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

#ifndef __EGG_LIST_BOX_ACCESSIBLE_H__
#define __EGG_LIST_BOX_ACCESSIBLE_H__

#include <gtk/gtk-a11y.h>

G_BEGIN_DECLS

#define EGG_TYPE_LIST_BOX_ACCESSIBLE                   (egg_list_box_accessible_get_type ())
#define EGG_LIST_BOX_ACCESSIBLE(obj)                   (G_TYPE_CHECK_INSTANCE_CAST ((obj), EGG_TYPE_LIST_BOX_ACCESSIBLE, EggListBoxAccessible))
#define EGG_LIST_BOX_ACCESSIBLE_CLASS(klass)           (G_TYPE_CHECK_CLASS_CAST ((klass), EGG_TYPE_LIST_BOX_ACCESSIBLE, EggListBoxAccessibleClass))
#define EGG_IS_LIST_BOX_ACCESSIBLE(obj)                (G_TYPE_CHECK_INSTANCE_TYPE ((obj), EGG_TYPE_LIST_BOX_ACCESSIBLE))
#define EGG_IS_LIST_BOX_ACCESSIBLE_CLASS(klass)        (G_TYPE_CHECK_CLASS_TYPE ((klass), EGG_TYPE_LIST_BOX_ACCESSIBLE))
#define EGG_LIST_BOX_ACCESSIBLE_GET_CLASS(obj)         (G_TYPE_INSTANCE_GET_CLASS ((obj), EGG_TYPE_LIST_BOX_ACCESSIBLE, EggListBoxAccessibleClass))

typedef struct _EggListBoxAccessible        EggListBoxAccessible;
typedef struct _EggListBoxAccessibleClass   EggListBoxAccessibleClass;
typedef struct _EggListBoxAccessiblePrivate EggListBoxAccessiblePrivate;

struct _EggListBoxAccessible
{
  GtkContainerAccessible parent;

  EggListBoxAccessiblePrivate *priv;
};

struct _EggListBoxAccessibleClass
{
  GtkContainerAccessibleClass parent_class;
};

GType egg_list_box_accessible_get_type (void);

void _egg_list_box_accessible_update_selected (EggListBox *box, GtkWidget *child);
void _egg_list_box_accessible_update_cursor   (EggListBox *box, GtkWidget *child);

G_END_DECLS

#endif /* __EGG_LIST_BOX_ACCESSIBLE_H__ */
