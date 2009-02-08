/*
 * gitg-data-binding.h
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

#ifndef __GITG_DATA_BINDING_H__
#define __GITG_DATA_BINDING_H__

#include <glib-object.h>

typedef struct _GitgDataBinding GitgDataBinding;

typedef gboolean (*GitgDataBindingConversion)(GValue const *source, GValue *dest, gpointer userdata);

GitgDataBinding *gitg_data_binding_new(gpointer source, gchar const *source_property, 
									   gpointer dest, gchar const *dest_property);

GitgDataBinding *gitg_data_binding_new_full(gpointer source, gchar const *source_property,
											gpointer dest, gchar const *dest_property,
											GitgDataBindingConversion conversion,
											gpointer userdata);

GitgDataBinding *gitg_data_binding_new_mutual(gpointer source, gchar const *source_property,
											  gpointer dest, gchar const *dest_property);

GitgDataBinding *gitg_data_binding_new_mutual_full(gpointer source, gchar const *source_property,
											       gpointer dest, gchar const *dest_property,
											       GitgDataBindingConversion source_to_dest,
											       GitgDataBindingConversion dest_to_source,
											       gpointer userdata);

void gitg_data_binding_free(GitgDataBinding *binding);

/* conversion utilities */
gboolean gitg_data_binding_color_to_string(GValue const *color, GValue *string, gpointer userdata);
gboolean gitg_data_binding_string_to_color(GValue const *string, GValue *color, gpointer userdata);

#endif /* __GITG_DATA_BINDING_H__ */

