/*
 * gitg-lane.c
 * This file is part of gitg - git repository viewer
 *
 * Copyright (C) 2009 - Jesse van den Kieboom
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, 
 * Boston, MA 02111-1307, USA.
 */

#include "gitg-lane.h"

/* GitgLane functions */
GitgLane *
gitg_lane_copy(GitgLane *lane)
{
	GitgLane *copy = g_slice_new(GitgLane);
	copy->color = gitg_color_ref(lane->color);
	copy->from = g_slist_copy(lane->from);
	copy->type = lane->type;

	return copy;
}

GitgLane *
gitg_lane_dup(GitgLane *lane)
{
	GitgLane *dup = g_slice_new(GitgLane);
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
	
	if (GITG_IS_LANE_BOUNDARY(lane))
		g_slice_free(GitgLaneBoundary, (GitgLaneBoundary *)lane);
	else
		g_slice_free(GitgLane, lane);
}

GitgLane *
gitg_lane_new()
{
	return gitg_lane_new_with_color(NULL);
}

GitgLane *
gitg_lane_new_with_color(GitgColor *color)
{
	GitgLane *lane = g_slice_new0(GitgLane);
	lane->color = color ? gitg_color_ref(color) : gitg_color_next();
	
	return lane;
}

GitgLaneBoundary *
gitg_lane_convert_boundary(GitgLane *lane, GitgLaneType type)
{
	GitgLaneBoundary *boundary = g_slice_new(GitgLaneBoundary);
	
	boundary->lane = *lane;
	boundary->lane.type |= type;
	
	g_slice_free(GitgLane, lane);
	
	return boundary;
}
