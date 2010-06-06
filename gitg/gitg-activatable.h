#ifndef __GITG_ACTIVATABLE_H__
#define __GITG_ACTIVATABLE_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define GITG_TYPE_ACTIVATABLE			(gitg_activatable_get_type ())
#define GITG_ACTIVATABLE(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_ACTIVATABLE, GitgActivatable))
#define GITG_IS_ACTIVATABLE(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_ACTIVATABLE))
#define GITG_ACTIVATABLE_GET_INTERFACE(obj)	(G_TYPE_INSTANCE_GET_INTERFACE ((obj), GITG_TYPE_ACTIVATABLE, GitgActivatableInterface))

typedef struct _GitgActivatable			GitgActivatable;
typedef struct _GitgActivatableInterface	GitgActivatableInterface;

struct _GitgActivatableInterface
{
	GTypeInterface parent;

	gchar     *(*get_id)    (GitgActivatable *panel);
	gboolean   (*activate)  (GitgActivatable *panel,
	                         gchar const     *cmd);
};

GType gitg_activatable_get_type (void) G_GNUC_CONST;

gchar     *gitg_activatable_get_id    (GitgActivatable *panel);
gboolean   gitg_activatable_activate  (GitgActivatable *panel,
                                       gchar const     *action);

G_END_DECLS

#endif /* __GITG_ACTIVATABLE_H__ */
