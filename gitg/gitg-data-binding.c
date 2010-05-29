/*
 * gitg-data-bindinh.c
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

#include "gitg-data-binding.h"

#include <gdk/gdk.h>

typedef struct
{
	GObject *object;

	gchar *property;
	GType type;

	guint notify_id;
	GitgDataBindingConversion conversion;
	gpointer userdata;
} Binding;

typedef enum
{
	GITG_DATA_BINDING_NONE = 0,
	GITG_DATA_BINDING_MUTUAL = 1 << 0
} GitgDataBindingFlags;

struct _GitgDataBinding
{
	Binding source;
	Binding dest;
	GitgDataBindingFlags flags;
};

static void on_data_binding_destroy(GitgDataBinding *binding, GObject *source);
static void gitg_data_binding_finalize(GitgDataBinding *binding);

static void on_data_binding_changed(GObject *source, GParamSpec *spec, GitgDataBinding *binding);

static void
binding_connect(GitgDataBinding *binding, Binding *bd)
{
	gchar *nid = g_strconcat("notify::", bd->property, NULL);
	bd->notify_id = g_signal_connect_after(bd->object, nid, G_CALLBACK(on_data_binding_changed), binding);
	g_free(nid);
}

static void
binding_fill(Binding *binding, gpointer object, gchar const *property, GType type, GitgDataBindingConversion conversion, gpointer userdata)
{
	binding->object = G_OBJECT(object);
	binding->property = g_strdup(property);
	binding->type = type;
	binding->conversion = conversion ? conversion : (GitgDataBindingConversion)g_value_transform;
	binding->userdata = userdata;
}

static GitgDataBinding *
gitg_data_binding_create(gpointer source, gchar const *source_property, 
						 gpointer dest, gchar const *dest_property, 
						 GitgDataBindingConversion source_to_dest,
						 GitgDataBindingConversion dest_to_source,
						 gpointer userdata,
						 GitgDataBindingFlags flags)
{
	g_return_val_if_fail(G_IS_OBJECT(source), NULL);
	g_return_val_if_fail(G_IS_OBJECT(dest), NULL);

	GObjectClass *sclass = G_OBJECT_GET_CLASS(source);
	GObjectClass *dclass = G_OBJECT_GET_CLASS(dest);

	GParamSpec *sspec = g_object_class_find_property(sclass, source_property);

	if (!sspec)
	{
		g_warning("No such source property found: %s", source_property);
		return NULL;
	}

	GParamSpec *dspec = g_object_class_find_property(dclass, dest_property);

	if (!dspec)
	{
		g_warning("No such dest property found: %s", dest_property);
		return NULL;
	}

	GitgDataBinding *binding = g_slice_new0(GitgDataBinding);

	binding->flags = flags;

	binding_fill(&binding->source, source, source_property, G_PARAM_SPEC_VALUE_TYPE(sspec), source_to_dest, userdata);
	binding_fill(&binding->dest, dest, dest_property, G_PARAM_SPEC_VALUE_TYPE(dspec), dest_to_source, userdata);

	binding_connect(binding, &binding->source);

	if (flags & GITG_DATA_BINDING_MUTUAL)
		binding_connect(binding, &binding->dest);

	g_object_weak_ref(binding->source.object, (GWeakNotify)on_data_binding_destroy, binding);
	g_object_weak_ref(binding->dest.object, (GWeakNotify)on_data_binding_destroy, binding);

	/* initial value */
	on_data_binding_changed(binding->source.object, NULL, binding);
	return binding;
}

GitgDataBinding *
gitg_data_binding_new_full(gpointer source, gchar const *source_property,
						   gpointer dest, gchar const *dest_property,
						   GitgDataBindingConversion conversion,
						   gpointer userdata)
{
	return gitg_data_binding_create(source, source_property,
									dest, dest_property,
									conversion, NULL,
									userdata,
									GITG_DATA_BINDING_NONE);
}

GitgDataBinding *
gitg_data_binding_new(gpointer source, gchar const *source_property,
					  gpointer dest, gchar const *dest_property)
{
	return gitg_data_binding_new_full(source, source_property,
									  dest, dest_property,
									  NULL, NULL);
}

GitgDataBinding *
gitg_data_binding_new_mutual_full(gpointer source, gchar const *source_property,
					              gpointer dest, gchar const *dest_property,
					              GitgDataBindingConversion source_to_dest,
					              GitgDataBindingConversion dest_to_source,
					              gpointer userdata)
{
	return gitg_data_binding_create(source, source_property,
									dest, dest_property,
									source_to_dest, dest_to_source,
									userdata,
									GITG_DATA_BINDING_MUTUAL);
}

GitgDataBinding *
gitg_data_binding_new_mutual(gpointer source, gchar const *source_property,
					         gpointer dest, gchar const *dest_property)
{
	return gitg_data_binding_new_mutual_full(source, source_property,
									         dest, dest_property,
									         NULL, NULL,
									         NULL);
}
static void
gitg_data_binding_finalize(GitgDataBinding *binding)
{
	g_free(binding->source.property);
	g_free(binding->dest.property);

	g_slice_free(GitgDataBinding, binding);
}

void
gitg_data_binding_free(GitgDataBinding *binding)
{
	if (binding->source.notify_id)
		g_signal_handler_disconnect(binding->source.object, binding->source.notify_id);

	if (binding->dest.notify_id)
		g_signal_handler_disconnect(binding->dest.object, binding->dest.notify_id);

	g_object_weak_unref(binding->source.object, (GWeakNotify)on_data_binding_destroy, binding);
	g_object_weak_unref(binding->dest.object, (GWeakNotify)on_data_binding_destroy, binding);

	gitg_data_binding_finalize(binding);
}

static void
on_data_binding_destroy(GitgDataBinding *binding, GObject *object)
{
	Binding *bd = binding->source.object == object ? &binding->dest : &binding->source;

	/* disconnect notify handler */
	if (bd->notify_id)
		g_signal_handler_disconnect(bd->object, bd->notify_id);

	/* remove weak ref */
	g_object_weak_unref(bd->object, (GWeakNotify)on_data_binding_destroy, binding);

	/* finalize binding */
	gitg_data_binding_finalize(binding);
}

static void 
on_data_binding_changed(GObject *object, GParamSpec *spec, GitgDataBinding *binding)
{
	Binding *source = binding->source.object == object ? &binding->source : &binding->dest;
	Binding *dest = binding->source.object == object ? &binding->dest : &binding->source;

	/* Transmit to dest */
	GValue value = { 0, };
	g_value_init(&value, dest->type);

	GValue svalue = { 0, };
	g_value_init(&svalue, source->type);

	g_object_get_property(source->object, source->property, &svalue);
	g_object_get_property(dest->object, dest->property, &value);

	if (source->conversion(&svalue, &value, source->userdata))
	{
		if (dest->notify_id)
			g_signal_handler_block(dest->object, dest->notify_id);

		g_object_set_property(dest->object, dest->property, &value);

		if (dest->notify_id)
			g_signal_handler_unblock(dest->object, dest->notify_id);
	}

	g_value_unset(&value);
	g_value_unset(&svalue);
}

/* conversion utilities */
gboolean 
gitg_data_binding_color_to_string(GValue const *color, GValue *string, gpointer userdata)
{
	GdkColor *clr = g_value_get_boxed(color);
	gchar *s = gdk_color_to_string(clr);

	g_value_take_string(string, s);
	return TRUE;
}

gboolean 
gitg_data_binding_string_to_color(GValue const *string, GValue *color, gpointer userdata)
{
	gchar const *s = g_value_get_string(string);
	GdkColor clr;

	gdk_color_parse(s, &clr);
	g_value_set_boxed(color, &clr);
	return TRUE;
}

