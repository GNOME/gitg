#ifndef __GITG_URI_H__
#define __GITG_URI_H__

#include <glib.h>

G_BEGIN_DECLS

gboolean gitg_uri_parse (gchar const  *uri,
                         gchar       **work_tree,
                         gchar       **selection,
                         gchar       **activatable,
                         gchar       **action);

G_END_DECLS

#endif /* __GITG_URI_H__ */

