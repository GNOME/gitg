#include "gitg-lane.h"

/* GitgLane functions */
GitgLane *
gitg_lane_copy(GitgLane *lane)
{
	GitgLane *copy = g_new0(GitgLane, 1);
	copy->color = gitg_color_ref(lane->color);
	copy->from = g_slist_copy(lane->from);
	copy->type = lane->type;

	return copy;
}

GitgLane *
gitg_lane_dup(GitgLane *lane)
{
	GitgLane *dup = g_new0(GitgLane, 1);
	dup->color = gitg_color_copy(lane->color);
	dup->from = g_slist_copy(lane->from);
	dup->type = lane->type;
	
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
	return gitg_lane_new_with_color(gitg_color_next());
}

GitgLane *
gitg_lane_new_with_color(GitgColor *color)
{
	GitgLane *lane = g_new0(GitgLane, 1);
	lane->color = color;
	lane->from = NULL;
	
	return lane;
}
