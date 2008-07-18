#ifndef __GITG_LANE_H__
#define __GITG_LANE_H__

#include <glib.h>
#include "gitg-color.h"

typedef struct _GitgLane
{
	GitgColor *color; /** Pointer to color */
	GSList *from; /** List of lanes merging on this lane */
} GitgLane;

GitgLane *gitg_lane_new();
GitgLane *gitg_lane_copy(GitgLane *lane);
GitgLane *gitg_lane_dup(GitgLane *lane);
void gitg_lane_free();

#endif /* __GITG_LANE_H__ */
