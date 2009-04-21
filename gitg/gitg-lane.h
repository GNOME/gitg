/*
 * gitg-lane.h
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
	GITG_LANE_SIGN_RIGHT = 1 << 3,
	GITG_LANE_SIGN_STASH = 1 << 4,
	GITG_LANE_SIGN_STAGED = 1 << 5,
	GITG_LANE_SIGN_UNSTAGED = 1 << 6,
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
