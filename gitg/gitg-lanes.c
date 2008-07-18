#include "gitg-lanes.h"
#include "gitg-utils.h"

#define GITG_LANES_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_LANES, GitgLanesPrivate))

typedef struct _LaneContainer
{
	GitgLane *lane;
	gchar const *hash;
} LaneContainer;

struct _GitgLanesPrivate
{
	GSList *lanes;
};

G_DEFINE_TYPE(GitgLanes, gitg_lanes, G_TYPE_OBJECT)

static void
lane_container_free(LaneContainer *container)
{
	gitg_lane_free(container->lane);

	g_free(container);
}

static void
free_lanes(GitgLanes *lanes)
{
	GSList *item;
	
	for (item = lanes->priv->lanes; item; item = item->next)
		lane_container_free((LaneContainer *)item->data);
	
	g_slist_free(lanes->priv->lanes);
}

static LaneContainer *
find_lane_by_hash(GitgLanes *lanes, gchar const *hash, gint8 *pos)
{
	GSList *item;
	gint8 p = 0;

	if (!hash)
		return NULL;

	for (item = lanes->priv->lanes; item; item = item->next)
	{
		LaneContainer *container = (LaneContainer *)(item->data);

		if (container && container->hash && gitg_utils_hash_equal(container->hash, hash))
		{
			if (pos)
				*pos = p;
		
			return container;
		}

		++p;
	}
	
	return NULL;
}

/* GitgLanes functions */
static void
gitg_lanes_finalize(GObject *object)
{
	GitgLanes *self = GITG_LANES(object);
	
	free_lanes(self);
	
	G_OBJECT_CLASS(gitg_lanes_parent_class)->finalize(object);
}

static void
gitg_lanes_class_init(GitgLanesClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS(klass);
	
	object_class->finalize = gitg_lanes_finalize;
	
	g_type_class_add_private(object_class, sizeof(GitgLanesPrivate));
}

static void
gitg_lanes_init(GitgLanes *self)
{
	self->priv = GITG_LANES_GET_PRIVATE(self);
}

GitgLanes *
gitg_lanes_new()
{
	return GITG_LANES(g_object_new(GITG_TYPE_LANES, NULL));
}

static LaneContainer *
lane_container_new(gchar const *hash)
{
	LaneContainer *ret = g_new(LaneContainer, 1);
	ret->hash = hash;
	ret->lane = gitg_lane_new();
	
	return ret;
}

static GitgLane **
flatten_lanes(GitgLanes *lanes)
{
	gint len = g_slist_length(lanes->priv->lanes);
	GitgLane **res = g_new(GitgLane *, len + 1);
	GSList *item = lanes->priv->lanes;

	int i;
	for (i = 0; i < len; ++i)
	{
		res[i] = gitg_lane_copy(((LaneContainer *)(item->data))->lane);
		item = item->next;
	}
	
	res[len] = NULL;
	return res;
}

GitgLane **
gitg_lanes_reset(GitgLanes *lanes, gchar const *hash)
{
	free_lanes(lanes);

	gitg_color_reset();
	lanes->priv->lanes = g_slist_prepend(NULL, lane_container_new(hash));
	
	return flatten_lanes(lanes);
}

static void
init_next_layer(GitgLanes *lanes)
{
	GSList *item;
	gint8 index = 0;

	// Initialize new set of lanes based on 'lanes'. It copies the lane (refs
	// the color) and adds the lane index as a merge (so it basicly represents
	// a passthrough)
	for (item = lanes->priv->lanes; item; item = item->next)
	{
		LaneContainer *container = (LaneContainer *)(item->data);
		GitgLane *lane = gitg_lane_copy(container->lane);
		g_slist_free(lane->from);
		
		gitg_lane_free(container->lane);
		container->lane = lane;
		container->lane->from = g_slist_prepend(NULL, GINT_TO_POINTER((gint)(index++)));

		++lanes;
	}
}

GitgLane **
gitg_lanes_next(GitgLanes *lanes, GitgRevision *previous, GitgRevision *current, gint8 *currentpos)
{
	init_next_layer(lanes);

	gint8 mypos;
	LaneContainer *mylane = find_lane_by_hash(lanes, gitg_revision_get_hash(previous), &mypos);
	
	if (mylane)
	{
		GitgColor *nc = gitg_color_copy(mylane->lane->color);
		gitg_color_unref(mylane->lane->color);
		mylane->lane->color = nc;

		mylane->hash = NULL;
	}
	
	guint num;
	Hash *parents = gitg_revision_get_parents_hash(previous, &num);
	int i;
	
	// Iterate over all parents and find them a lane
	for (i = 0; i < num; ++i)
	{
		gint8 lnpos;
		LaneContainer *lane = find_lane_by_hash(lanes, parents[i], &lnpos);

		if (lane)
		{
			// There already is a lane for this parent. This means that we add
			// mypos as a merge for the lane, also this means the color of 
			// this lane incluis the merge should change to one color
			
			lane->lane->from = g_slist_append(lane->lane->from, GINT_TO_POINTER((gint)mypos));
			gitg_color_next_index(lane->lane->color);
			
			continue;
		} 
		else if (mylane && mylane->hash == NULL)
		{
			// There is no parent yet which can proceed on the current
			// revision lane, so set it now
			mylane->hash = (gchar const *)parents[i];
			
			// If there is more than one parent, then also change the color 
			// since this revision is actually a merge
			if (num > 1)
			{
				gitg_color_unref(mylane->lane->color);
				mylane->lane->color = gitg_color_next();
			}
		}
		else
		{
			// Generate a new lane for this parent
			LaneContainer *newlane = lane_container_new(parents[i]);
			
			newlane->lane->from = g_slist_prepend(NULL, GINT_TO_POINTER((gint)mypos));
			lanes->priv->lanes = g_slist_append(lanes->priv->lanes, newlane);
			
			if (!mylane)
				mylane = newlane;
		}
	}
	
	// Remove the current lane if it is no longer needed
	if (mylane && mylane->hash == NULL)
		lanes->priv->lanes = g_slist_remove(lanes->priv->lanes, mylane);
	
	// Determine the lane of the current revision
	LaneContainer *lane = find_lane_by_hash(lanes, gitg_revision_get_hash(current), currentpos);
	
	if (!lane)
	{
		// No lane for this revision reserved, we therefore add a new one
		lanes->priv->lanes = g_slist_append(lanes->priv->lanes, lane_container_new(gitg_revision_get_hash(current)));
		*currentpos = g_slist_length(lanes->priv->lanes) - 1;
	}

	return flatten_lanes(lanes);
}
