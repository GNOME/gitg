#ifndef __GITG_LANE_H__
#define __GITG_LANE_H__

#include <glib.h>
#include "gitg-color.h"

enum {
	GITG_LANE_TYPE_NONE,
	GITG_LANE_TYPE_START,
	GITG_LANE_TYPE_END
};

typedef struct _GitgLane
{
	GitgColor *color; /** Pointer to color */
	GSList *from; /** List of lanes merging on this lane */
	gint8 type;
} GitgLane;

GitgLane *gitg_lane_new();
GitgLane *gitg_lane_new_with_color(GitgColor *color);
GitgLane *gitg_lane_copy(GitgLane *lane);
GitgLane *gitg_lane_dup(GitgLane *lane);
void gitg_lane_free();

#endif /* __GITG_LANE_H__ */
