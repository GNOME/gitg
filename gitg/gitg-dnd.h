#ifndef __GITG_DND_H__
#define __GITG_DND_H__

#include <gtk/gtk.h>
#include "gitg-ref.h"
#include "gitg-revision.h"

G_BEGIN_DECLS

typedef gboolean (*GitgDndCallback)(GitgRef *source, GitgRef *dest, gboolean dropped, gpointer callback_data);
typedef gboolean (*GitgDndRevisionCallback)(GitgRevision *source, GitgRef *dest, gboolean dropped, gpointer callback_data);

void gitg_dnd_enable (GtkTreeView *tree_view,
                      GitgDndCallback callback,
                      GitgDndRevisionCallback revision_callback,
                      gpointer callback_data);

void gitg_dnd_disable (GtkTreeView *tree_view);

G_END_DECLS

#endif /* __GITG_DND_H__ */

