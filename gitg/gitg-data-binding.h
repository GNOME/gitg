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

