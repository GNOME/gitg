#include "gitg-lanes.h"
#include "gitg-utils.h"

#define GITG_LANES_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE((object), GITG_TYPE_LANES, GitgLanesPrivate))

#define INACTIVE_MAX 15
#define INACTIVE_COLLAPSE 5

typedef struct
{
	GitgLane *lane;
	guint8 inactive;
	gchar const *hash;
} LaneContainer;

typedef struct 
{
	GitgColor *color;
	gint8 index;
} InactiveLane;

struct _GitgLanesPrivate
{
	/* list of last N GitgRevisions used to backtrack in case of lane 
	   collapse/reactivation */
	GSList *previous;
	
	/* list of LaneContainer resembling the current lanes state for the 
	   next revision */
	GSList *lanes;
	
	/* hash table of rev hash -> InactiveLane where rev hash is the hash
	   to be expected on the lane */
	GHashTable *inactive;
};

G_DEFINE_TYPE(GitgLanes, gitg_lanes, G_TYPE_OBJECT)

static void
lane_container_free(LaneContainer *container)
{
	gitg_lane_free(container->lane);
	g_slice_free(LaneContainer, container);
}

static void
inactive_lane_free(InactiveLane *lane)
{
	gitg_color_unref(lane->color);
	g_slice_free(InactiveLane, lane);
}

static void
free_lanes(GitgLanes *lanes)
{
	g_slist_foreach(lanes->priv->lanes, (GFunc)lane_container_free, NULL);
	g_slist_free(lanes->priv->lanes);
	
	lanes->priv->lanes = NULL;
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
	
	gitg_lanes_reset(self);
	
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
	self->priv->inactive = g_hash_table_new_full(gitg_utils_hash_hash, gitg_utils_hash_equal, NULL, (GDestroyNotify)inactive_lane_free);
}

GitgLanes *
gitg_lanes_new()
{
	return GITG_LANES(g_object_new(GITG_TYPE_LANES, NULL));
}

static LaneContainer *
lane_container_new(gchar const *hash)
{
	LaneContainer *ret = g_slice_new(LaneContainer);
	ret->hash = hash;
	ret->lane = gitg_lane_new();
	ret->inactive = 0;

	return ret;
}

GSList *
lanes_list(GitgLanes *lanes)
{
	GSList *lns = NULL;
	GSList *item;
	
	for (item = lanes->priv->lanes; item; item = item->next)
		lns = g_slist_prepend(lns, gitg_lane_copy(((LaneContainer*)item->data)->lane));
	
	return g_slist_reverse(lns);
}

void
gitg_lanes_reset(GitgLanes *lanes)
{
	free_lanes(lanes);
	gitg_color_reset();
	
	g_slist_foreach(lanes->priv->previous, (GFunc)gitg_revision_unref, NULL);
	g_slist_free(lanes->priv->previous);
	lanes->priv->previous = NULL;
	
	g_hash_table_remove_all(lanes->priv->inactive);
}

static gboolean
lane_container_next(LaneContainer *container, gint index)
{
	GitgLane *lane = gitg_lane_copy(container->lane);
	lane->type = GITG_LANE_TYPE_NONE;
	g_slist_free(lane->from);
	
	gitg_lane_free(container->lane);

	container->lane = lane;
	container->lane->from = g_slist_prepend(NULL, GINT_TO_POINTER((gint)(index)));
	
	++container->inactive;
}

static void
update_lane_merge_indices(GSList *from, gint8 index)
{
	GSList *item;
	
	for (item = from; item; item = g_slist_next(item))
	{
		gint8 idx = GPOINTER_TO_INT(item->data);
		
		if (idx >= index)
			item->data = GINT_TO_POINTER(idx - 1);
	}
}

static void
update_merge_indices(GSList *lanes, gint8 index)
{
	GSList *item;
	
	for (item = lanes; item; item = g_slist_next(item))
	{
		GitgLane *lane = (GitgLane *)item->data;
		
		update_lane_merge_indices(lane->from, index);
	}
}

static void
collapse_lane(GitgLanes *lanes, LaneContainer *container, gint8 index)
{
	/* backtrack for INACTIVE_COLLAPSE revisions and remove this container from
	   those revisions, appropriately updating merge indices etc */
	GSList *item;

	for (item = lanes->priv->previous; item; item = g_slist_next(item))
	{
		GitgRevision *revision = GITG_REVISION(item->data);
		GSList *lns = gitg_revision_get_lanes(revision);
		gint8 newindex = index;
		
		/* remove lane at 'index' and update merge indices for the lanes
		   after 'index' in the list */
		if (item->next)
		{
			GSList *collapsed = g_slist_nth(lns, index);
			GitgLane *lane = (GitgLane *)collapsed->data;

			gint8 newindex = GPOINTER_TO_INT(lane->from->data);

			lns = gitg_revision_remove_lane(revision, lane);
			
			if (item->next->next)
				update_merge_indices(lns, index);
			
			gint mylane = gitg_revision_get_mylane(revision);
			
			if (mylane >= index)
				gitg_revision_set_mylane(revision, mylane - 1);
	
			index = newindex;
		}
		else
		{
			/* the last item we keep, and set the style of the lane to END */
			GitgLane *lane = (GitgLane *)g_slist_nth_data(lns, index);
			lane->type = GITG_LANE_TYPE_END;
		}
	}	
}

static void
update_current_lanes_merge_indices(GitgLanes *lanes, gint8 index)
{
	GSList *item;
	
	for (item = lanes->priv->lanes; item; item = g_slist_next(item))
		update_lane_merge_indices(((LaneContainer *)item->data)->lane->from, index);
}

static gint8
collapse_lanes(GitgLanes *lanes)
{
	GSList *item = lanes->priv->lanes;
	gint8 index = 0;
	gint8 collapsed = 0;
	
	/* Initialize new set of lanes based on 'lanes'. It copies the lane (refs
	   the color) and adds the lane index as a merge (so it basicly represents
	   a passthrough) */
	while (item)
	{
		LaneContainer *container = (LaneContainer *)item->data;
		
		if (container->inactive != INACTIVE_MAX)
		{
			item = g_slist_next(item);
			++index;
			continue;
		}

		collapse_lane(lanes, container, index);
		
		update_current_lanes_merge_indices(lanes, index);
		
		GSList *next = g_slist_next(item);
		lane_container_free(container);

		lanes->priv->lanes = g_slist_remove_link(lanes->priv->lanes, item);
		item = next;
		
		++collapsed;
	}
	
	return collapsed;
}

static void
init_next_layer(GitgLanes *lanes)
{
	GSList *item = lanes->priv->lanes;
	gint8 index = 0;
	
	/* Initialize new set of lanes based on 'lanes'. It copies the lane (refs
	   the color) and adds the lane index as a merge (so it basicly represents
	   a passthrough) */
	for (item = lanes->priv->lanes; item; item = g_slist_next(item))
	{
		LaneContainer *container = (LaneContainer *)item->data;

		lane_container_next(container, index++);
	}
}

static void
prepare_lanes(GitgLanes *lanes, GitgRevision *next, gint8 *pos)
{
	LaneContainer *mylane;
	guint num;
	Hash *parents = gitg_revision_get_parents_hash(next, &num);
	guint i;
	
	/* prepare the next layer */
	init_next_layer(lanes);
	
	mylane = (LaneContainer *)g_slist_nth_data(lanes->priv->lanes, *pos);
	
	/* Iterate over all parents and find them a lane */
	for (i = 0; i < num; ++i)
	{
		gint8 lnpos;
		LaneContainer *container = find_lane_by_hash(lanes, parents[i], &lnpos);
		
		if (container)
		{
			/* There already is a lane for this parent. This means that we add
			   mypos as a merge for the lane, also this means the color of 
			   this lane incluis the merge should change to one color */
			container->lane->from = g_slist_append(container->lane->from, GINT_TO_POINTER((gint)*pos));
			gitg_color_next_index(container->lane->color);
			
			continue;
		} 
		else if (mylane && mylane->hash == NULL)
		{
			/* There is no parent yet which can proceed on the current
			   revision lane, so set it now */
			mylane->hash = (gchar const *)parents[i];
	
			/* If there is more than one parent, then also change the color 
			   since this revision is a merge */
			if (num > 1)
			{
				gitg_color_unref(mylane->lane->color);
				mylane->lane->color = gitg_color_next();
			}
			else
			{
				GitgColor *nc = gitg_color_copy(mylane->lane->color);
				gitg_color_unref(mylane->lane->color);
				mylane->lane->color = nc;
			}
		}
		else
		{
			/* Generate a new lane for this parent */
			LaneContainer *newlane = lane_container_new(parents[i]);
			newlane->lane->from = g_slist_prepend(NULL, GINT_TO_POINTER((gint)*pos));
			lanes->priv->lanes = g_slist_append(lanes->priv->lanes, newlane);
		}
	}
	
	/* Remove the current lane if it is no longer needed */
	if (mylane && mylane->hash == NULL)
		lanes->priv->lanes = g_slist_remove(lanes->priv->lanes, mylane);

	/* Store new revision in our track list */
	if (g_slist_length(lanes->priv->previous) == INACTIVE_COLLAPSE + 1)
	{
		GSList *last = g_slist_last(lanes->priv->previous);
		gitg_revision_unref(GITG_REVISION(last->data));
		
		lanes->priv->previous = g_slist_remove_link(lanes->priv->previous, last);
	}

	lanes->priv->previous = g_slist_prepend(lanes->priv->previous, gitg_revision_ref(next));
}

GSList *
gitg_lanes_next(GitgLanes *lanes, GitgRevision *next, gint8 *nextpos)
{
	LaneContainer *mylane;
	GSList *res;
	
	collapse_lanes(lanes);
	mylane = find_lane_by_hash(lanes, gitg_revision_get_hash(next), nextpos);

	if (!mylane)
	{
		/* apparently, there is no lane reserved for this revision, we
		   add a new one */
		lanes->priv->lanes = g_slist_append(lanes->priv->lanes, lane_container_new(NULL));
		*nextpos = g_slist_length(lanes->priv->lanes) - 1;
	}
	else
	{
		/* copy the color here because this represents a new stop */
		GitgColor *nc = gitg_color_copy(mylane->lane->color);
		gitg_color_unref(mylane->lane->color);

		mylane->lane->color = nc;
		mylane->hash = NULL;
		mylane->inactive = 0;
	}
	
	res = lanes_list(lanes);
	prepare_lanes(lanes, next, nextpos);

	return res;
}
