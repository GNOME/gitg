#ifndef __GITG_LANE_H__
#define __GITG_LANE_H__

#include <glib.h>
#include "gitg-color.h"
#include "gitg-types.h"
#define GITG_IS_LANE_BOUNDARY(lane) (lane->type & GITG_LANE_TYPE_START || lane->type & GITG_LANE_TYPE_END)

typedef enum
{
	GITG_LANE_TYPE_NONE,
	GITG_LANE_TYPE_START = 1 << 0,
	GITG_LANE_TYPE_END = 1 << 1,
	GITG_LANE_SIGN_LEFT = 1 << 2,
	GITG_LANE_SIGN_RIGHT = 1 << 3
} GitgLaneType;

typedef struct
{
	GitgColor *color; /** Pointer to color */
	GSList *from; /** List of lanes merging on this lane */
	gint8 type;
} GitgLane;

typedef struct
{
	GitgLane lane;
	Hash hash;
} GitgLaneBoundary;

GitgLane *gitg_lane_new();
GitgLane *gitg_lane_new_with_color(GitgColor *color);
GitgLane *gitg_lane_copy(GitgLane *lane);
GitgLane *gitg_lane_dup(GitgLane *lane);

void gitg_lane_free(GitgLane *lane);
GitgLaneBoundary *gitg_lane_convert_boundary(GitgLane *lane, GitgLaneType type);

#endif /* __GITG_LANE_H__ */
