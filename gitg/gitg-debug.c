#include "gitg-debug.h"
#include <glib.h>

static guint debug_enabled = GITG_DEBUG_NONE;

#define DEBUG_FROM_ENV(name) 			\
	{									\
		if (g_getenv(#name))			\
			debug_enabled |= name;		\
	}

void gitg_debug_init()
{
	DEBUG_FROM_ENV(GITG_DEBUG_RUNNER);
}

gboolean gitg_debug_enabled(guint debug)
{
	return debug_enabled & debug;
}
