#ifndef __GITG_DEBUG_H__
#define __GITG_DEBUG_H__

#include <glib.h>

enum
{
	GITG_DEBUG_NONE = 0,
	GITG_DEBUG_RUNNER = 1 << 0
};

void gitg_debug_init();
gboolean gitg_debug_enabled(guint debug);

#endif /* __GITG_DEBUG_H__ */

