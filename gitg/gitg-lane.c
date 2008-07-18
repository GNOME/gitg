#include "gitg-lane.h"

/* GitgLane functions */
GitgLane *
gitg_lane_copy(GitgLane *lane)
{
	GitgLane *copy = g_new(GitgLane, 1);
	copy->color = gitg_color_ref(lane->color);
	copy->from = g_slist_copy(lane->from);

	return copy;
}

GitgLane *
gitg_lane_dup(GitgLane *lane)
{
	GitgLane *dup = g_new(GitgLane, 1);
	dup->color = gitg_color_copy(lane->color);
	dup->from = g_slist_copy(lane->from);
	
	return dup;
}

void
gitg_lane_free(GitgLane *lane)
{
	gitg_color_unref(lane->color);
	g_slist_free(lane->from);
}

GitgLane *
gitg_lane_new()
{
	GitgLane *lane = g_new(GitgLane, 1);
	lane->color = gitg_color_next();
	lane->from = NULL;
	
	return lane;
}
