/*
 * gitg-spinner.c
 * This file is part of gitg
 *
 * Copyright (C) 2009 - Jesse van den kieboom
 * Copyright (C) 2005 - Paolo Maggi 
 * Copyright (C) 2002-2004 Marco Pesenti Gritti
 * Copyright (C) 2004 Christian Persch
 * Copyright (C) 2000 - Eazel, Inc. 
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
 
/*
 * This widget was originally written by Andy Hertzfeld <andy@eazel.com> for
 * Nautilus. It was then modified by Marco Pesenti Gritti and Christian Persch
 * for Epiphany.
 *
 * Modified by the gitg Team, 2005. See the AUTHORS file for a 
 * list of people on the gitg Team.  
 * See the ChangeLog files for a list of changes. 
 *
 * Modified by the gitg team, 2009.
 *
 * $Id$
 */

#ifdef HAVE_CONFIG_H
#include <config.h>
#endif

#include "gitg-spinner.h"

#include <gdk-pixbuf/gdk-pixbuf.h>

/* Spinner cache implementation */

#define GITG_TYPE_SPINNER_CACHE		(gitg_spinner_cache_get_type())
#define GITG_SPINNER_CACHE(object)		(G_TYPE_CHECK_INSTANCE_CAST((object), GITG_TYPE_SPINNER_CACHE, GitgSpinnerCache))
#define GITG_SPINNER_CACHE_CLASS(klass) 	(G_TYPE_CHECK_CLASS_CAST((klass), GITG_TYPE_SPINNER_CACHE, GitgSpinnerCacheClass))
#define GITG_IS_SPINNER_CACHE(object)		(G_TYPE_CHECK_INSTANCE_TYPE((object), GITG_TYPE_SPINNER_CACHE))
#define GITG_IS_SPINNER_CACHE_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE((klass), GITG_TYPE_SPINNER_CACHE))
#define GITG_SPINNER_CACHE_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS((obj), GITG_TYPE_SPINNER_CACHE, GitgSpinnerCacheClass))

typedef struct _GitgSpinnerCache		GitgSpinnerCache;
typedef struct _GitgSpinnerCacheClass		GitgSpinnerCacheClass;
typedef struct _GitgSpinnerCachePrivate	GitgSpinnerCachePrivate;

struct _GitgSpinnerCacheClass
{
	GObjectClass parent_class;
};

struct _GitgSpinnerCache
{
	GObject parent_object;

	/*< private >*/
	GitgSpinnerCachePrivate *priv;
};

#define GITG_SPINNER_CACHE_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE ((object), GITG_TYPE_SPINNER_CACHE, GitgSpinnerCachePrivate))

struct _GitgSpinnerCachePrivate
{
	/* Hash table of GdkScreen -> GitgSpinnerCacheData */
	GHashTable *hash;
};

typedef struct
{
	guint        ref_count;
	GtkIconSize  size;
	gint         width;
	gint         height;
	GdkPixbuf  **animation_pixbufs;
	guint        n_animation_pixbufs;
} GitgSpinnerImages;

#define LAST_ICON_SIZE			GTK_ICON_SIZE_DIALOG + 1
#define SPINNER_ICON_NAME		"process-working"
#define SPINNER_FALLBACK_ICON_NAME	"gnome-spinner"
#define GITG_SPINNER_IMAGES_INVALID	((GitgSpinnerImages *) 0x1)

typedef struct
{
	GdkScreen          *screen;
	GtkIconTheme       *icon_theme;
	GitgSpinnerImages  *images[LAST_ICON_SIZE];
} GitgSpinnerCacheData;

static void gitg_spinner_cache_class_init	(GitgSpinnerCacheClass *klass);
static void gitg_spinner_cache_init		(GitgSpinnerCache      *cache);

static GObjectClass *gitg_spinner_cache_parent_class;

static GType
gitg_spinner_cache_get_type (void)
{
	static GType type = 0;

	if (G_UNLIKELY (type == 0))
	{
		const GTypeInfo our_info =
		{
			sizeof (GitgSpinnerCacheClass),
			NULL,
			NULL,
			(GClassInitFunc) gitg_spinner_cache_class_init,
			NULL,
			NULL,
			sizeof (GitgSpinnerCache),
			0,
			(GInstanceInitFunc) gitg_spinner_cache_init
		};

		type = g_type_register_static (G_TYPE_OBJECT,
					       "GitgSpinnerCache",
					       &our_info, 0);
	}

	return type;
}

static GitgSpinnerImages *
gitg_spinner_images_ref (GitgSpinnerImages *images)
{
	g_return_val_if_fail (images != NULL, NULL);

	images->ref_count++;

	return images;
}

static void
gitg_spinner_images_unref (GitgSpinnerImages *images)
{
	g_return_if_fail (images != NULL);

	images->ref_count--;

	if (images->ref_count == 0)
	{
		guint i;

		/* LOG ("Freeing spinner images %p for size %d", images, images->size); */

		for (i = 0; i < images->n_animation_pixbufs; ++i)
		{
			g_object_unref (images->animation_pixbufs[i]);
		}
		
		g_free (images->animation_pixbufs);
		g_free (images);
	}
}

static void
gitg_spinner_cache_data_unload (GitgSpinnerCacheData *data)
{
	GtkIconSize size;
	GitgSpinnerImages *images;

	g_return_if_fail (data != NULL);

	/* LOG ("GitgSpinnerDataCache unload for screen %p", data->screen); */

	for (size = GTK_ICON_SIZE_INVALID; size < LAST_ICON_SIZE; ++size)
	{
		images = data->images[size];
		data->images[size] = NULL;

		if (images != NULL && images != GITG_SPINNER_IMAGES_INVALID)
		{
			gitg_spinner_images_unref (images);
		}
	}
}

static GdkPixbuf *
extract_frame (GdkPixbuf *grid_pixbuf,
	       int x,
	       int y,
	       int size)
{
	GdkPixbuf *pixbuf;

	if (x + size > gdk_pixbuf_get_width (grid_pixbuf) ||
	    y + size > gdk_pixbuf_get_height (grid_pixbuf))
	{
		return NULL;
	}

	pixbuf = gdk_pixbuf_new_subpixbuf (grid_pixbuf,
					   x, y,
					   size, size);
	g_return_val_if_fail (pixbuf != NULL, NULL);

	return pixbuf;
}

static GdkPixbuf *
scale_to_size (GdkPixbuf *pixbuf,
	       int dw,
	       int dh)
{
	GdkPixbuf *result;
	int pw, ph;

	g_return_val_if_fail (pixbuf != NULL, NULL);

	pw = gdk_pixbuf_get_width (pixbuf);
	ph = gdk_pixbuf_get_height (pixbuf);

	if (pw != dw || ph != dh)
	{
		result = gdk_pixbuf_scale_simple (pixbuf, dw, dh,
						  GDK_INTERP_BILINEAR);
		g_object_unref (pixbuf);
		return result;
	}

	return pixbuf;
}

static GitgSpinnerImages *
gitg_spinner_images_load (GdkScreen    *screen,
                          GtkIconTheme *icon_theme,
                          GtkIconSize   icon_size)
{
	GitgSpinnerImages *images;
	GdkPixbuf *icon_pixbuf, *pixbuf;
	GtkIconInfo *icon_info = NULL;
	int grid_width, grid_height, x, y, requested_size, size, isw, ish, n;
	const char *icon;
	GSList *list = NULL, *l;

	/* LOG ("GitgSpinnerCacheData loading for screen %p at size %d", screen, icon_size); */

	/* START_PROFILER ("loading spinner animation") */
	
	if (screen == NULL)
		screen = gdk_screen_get_default ();

	if (!gtk_icon_size_lookup_for_settings (gtk_settings_get_for_screen (screen),
						icon_size, &isw, &ish))
		goto loser;
 
	requested_size = MAX (ish, isw);

	/* Load the animation. The 'rest icon' is the 0th frame */
	icon_info = gtk_icon_theme_lookup_icon (icon_theme,
						SPINNER_ICON_NAME,
						requested_size, 0);

	if (icon_info == NULL)
	{
		g_warning ("Throbber animation not found");

		/* If the icon naming spec compliant name wasn't found, try the old name */
		icon_info = gtk_icon_theme_lookup_icon (icon_theme,
							SPINNER_FALLBACK_ICON_NAME,
						        requested_size, 0);
		if (icon_info == NULL)
		{
			g_warning ("Throbber fallback animation not found either");
			goto loser;
	 	}
	}

	g_assert (icon_info != NULL);

	size = gtk_icon_info_get_base_size (icon_info);
	icon = gtk_icon_info_get_filename (icon_info);

	if (icon == NULL)
		goto loser;

	icon_pixbuf = gdk_pixbuf_new_from_file (icon, NULL);
	gtk_icon_info_free (icon_info);
	icon_info = NULL;

	if (icon_pixbuf == NULL)
	{
		g_warning ("Could not load the spinner file");
		goto loser;
	}

	grid_width = gdk_pixbuf_get_width (icon_pixbuf);
	grid_height = gdk_pixbuf_get_height (icon_pixbuf);

	n = 0;
	for (y = 0; y < grid_height; y += size)
	{
		for (x = 0; x < grid_width ; x += size)
		{
			pixbuf = extract_frame (icon_pixbuf, x, y, size);

			if (pixbuf)
			{
				list = g_slist_prepend (list, pixbuf);
				++n;
			}
			else
			{
				g_warning ("Cannot extract frame (%d, %d) from the grid\n", x, y);
			}
		}
	}

	g_object_unref (icon_pixbuf);

	if (list == NULL)
		goto loser;

	/* g_assert (n > 0); */

	if (size > requested_size)
	{
		for (l = list; l != NULL; l = l->next)
		{
			l->data = scale_to_size (l->data, isw, ish);
		}
 	}

	/* Now we've successfully got all the data */
	images = g_new (GitgSpinnerImages, 1);
	images->ref_count = 1;
 
	images->size = icon_size;
	images->width = images->height = requested_size;

	images->n_animation_pixbufs = n;
	images->animation_pixbufs = g_new (GdkPixbuf *, n);

	for (l = list; l != NULL; l = l->next)
	{
		g_assert (l->data != NULL);
		images->animation_pixbufs[--n] = l->data;
	}
	g_assert (n == 0);

	g_slist_free (list);

	/* STOP_PROFILER ("loading spinner animation") */
	return images;
 
loser:
	if (icon_info)
	{
		gtk_icon_info_free (icon_info);
 	}

	g_slist_foreach (list, (GFunc) g_object_unref, NULL);

	/* STOP_PROFILER ("loading spinner animation") */

	return NULL;
}

static GitgSpinnerCacheData *
gitg_spinner_cache_data_new (GdkScreen *screen)
{
	GitgSpinnerCacheData *data;

	data = g_new0 (GitgSpinnerCacheData, 1);

	data->screen = screen;
	data->icon_theme = gtk_icon_theme_get_for_screen (screen);

	g_signal_connect_swapped (data->icon_theme,
				  "changed",
				  G_CALLBACK (gitg_spinner_cache_data_unload),
				  data);

	return data;
}

static void
gitg_spinner_cache_data_free (GitgSpinnerCacheData *data)
{
	g_return_if_fail (data != NULL);
	g_return_if_fail (data->icon_theme != NULL);

	g_signal_handlers_disconnect_by_func (data->icon_theme,
					      G_CALLBACK (gitg_spinner_cache_data_unload),
					      data);

	gitg_spinner_cache_data_unload (data);

	g_free (data);
}

static GitgSpinnerImages *
gitg_spinner_cache_get_images (GitgSpinnerCache *cache,
                               GdkScreen        *screen,
                               GtkIconSize       icon_size)
{
	GitgSpinnerCachePrivate *priv = cache->priv;
	GitgSpinnerCacheData *data;
	GitgSpinnerImages *images;

	g_return_val_if_fail (icon_size >= 0 && icon_size < LAST_ICON_SIZE, NULL);

	data = g_hash_table_lookup (priv->hash, screen);

	if (data == NULL)
	{
		data = gitg_spinner_cache_data_new (screen);

		/* FIXME: think about what happens when the screen's display is closed later on */
		g_hash_table_insert (priv->hash, screen, data);
	}

	images = data->images[icon_size];

	if (images == GITG_SPINNER_IMAGES_INVALID)
	{
		/* Load failed, but don't try endlessly again! */
		return NULL;
	}

	if (images != NULL)
	{
		/* Return cached data */
		return gitg_spinner_images_ref (images);
	}

	images = gitg_spinner_images_load (screen, data->icon_theme, icon_size);

	if (images == NULL)
 	{
		/* Mark as failed-to-load */
		data->images[icon_size] = GITG_SPINNER_IMAGES_INVALID;
 
		return NULL;
 	}

	data->images[icon_size] = images;

	return gitg_spinner_images_ref (images);
}

static void
gitg_spinner_cache_init (GitgSpinnerCache *cache)
{
	GitgSpinnerCachePrivate *priv;

	priv = cache->priv = GITG_SPINNER_CACHE_GET_PRIVATE (cache);

	/* LOG ("GitgSpinnerCache initialising"); */

	priv->hash = g_hash_table_new_full (g_direct_hash,
					    g_direct_equal,
					    NULL,
					    (GDestroyNotify) gitg_spinner_cache_data_free);
}

static void
gitg_spinner_cache_finalize (GObject *object)
{
	GitgSpinnerCache *cache = GITG_SPINNER_CACHE (object); 
	GitgSpinnerCachePrivate *priv = cache->priv;

	g_hash_table_destroy (priv->hash);

	/* LOG ("GitgSpinnerCache finalised"); */

	G_OBJECT_CLASS (gitg_spinner_cache_parent_class)->finalize (object);
}

static void
gitg_spinner_cache_class_init (GitgSpinnerCacheClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	gitg_spinner_cache_parent_class = g_type_class_peek_parent (klass);

	object_class->finalize = gitg_spinner_cache_finalize;

	g_type_class_add_private (object_class, sizeof (GitgSpinnerCachePrivate));
}

static GitgSpinnerCache *spinner_cache = NULL;

static GitgSpinnerCache *
gitg_spinner_cache_ref (void)
{
	if (spinner_cache == NULL)
	{
		GitgSpinnerCache **cache_ptr;

		spinner_cache = g_object_new (GITG_TYPE_SPINNER_CACHE, NULL);
		cache_ptr = &spinner_cache;
		g_object_add_weak_pointer (G_OBJECT (spinner_cache),
					   (gpointer *) cache_ptr);

		return spinner_cache;
	}

	return g_object_ref (spinner_cache);
}

/* Spinner implementation */

#define SPINNER_TIMEOUT 50 /* ms */

#define GITG_SPINNER_GET_PRIVATE(object)(G_TYPE_INSTANCE_GET_PRIVATE ((object), GITG_TYPE_SPINNER, GitgSpinnerPrivate))

struct _GitgSpinnerPrivate
{
	GdkScreen          *screen;
	GitgSpinnerCache   *cache;
	GtkIconSize         size;
	GitgSpinnerImages  *images;
	guint               current_image;
	guint               timeout;
	guint               timer_task;
	guint               spinning : 1;
	guint               need_load : 1;
};

enum
{
	FRAME,
	NUM_SIGNALS
};

static guint spinner_signals[NUM_SIGNALS] = {0,};

static void gitg_spinner_class_init	(GitgSpinnerClass *class);
static void gitg_spinner_init		(GitgSpinner      *spinner);

static GObjectClass *parent_class;

GType
gitg_spinner_get_type (void)
{
	static GType type = 0;

	if (G_UNLIKELY (type == 0))
	{
		const GTypeInfo our_info =
		{
			sizeof (GitgSpinnerClass),
			NULL, /* base_init */
			NULL, /* base_finalize */
			(GClassInitFunc) gitg_spinner_class_init,
			NULL,
			NULL, /* class_data */
			sizeof (GitgSpinner),
			0, /* n_preallocs */
			(GInstanceInitFunc) gitg_spinner_init
		};

		type = g_type_register_static (G_TYPE_OBJECT,
					       "GitgSpinner",
					       &our_info, 0);
	}

	return type;
}

static gboolean
gitg_spinner_load_images (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	if (priv->need_load)
	{
		priv->images = gitg_spinner_cache_get_images (priv->cache, priv->screen, priv->size);

		priv->current_image = 0; /* 'rest' icon */
		priv->need_load = FALSE;
	}

	return priv->images != NULL;
}

static void
gitg_spinner_unload_images (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	if (priv->images != NULL)
	{
		gitg_spinner_images_unref (priv->images);
		priv->images = NULL;
	}

	priv->current_image = 0;
	priv->need_load = TRUE;
}

static void
gitg_spinner_init (GitgSpinner *spinner)
{
	spinner->priv = GITG_SPINNER_GET_PRIVATE (spinner);

	spinner->priv->cache = gitg_spinner_cache_ref ();
	spinner->priv->size = GTK_ICON_SIZE_MENU;
	spinner->priv->timeout = SPINNER_TIMEOUT;
	spinner->priv->need_load = TRUE;
}

static gboolean
bump_spinner_frame_cb (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	/* This can happen when we've unloaded the images on a theme
	 * change, but haven't been in the queued size request yet.
	 * Just skip this update.
	 */
	if (priv->images == NULL)
	{
		if (!gitg_spinner_load_images (spinner))
		{
			return FALSE;
		}
	}

	priv->current_image++;

	if (priv->current_image >= priv->images->n_animation_pixbufs)
	{
		/* the 0th frame is the 'rest' icon */
		priv->current_image = MIN (1, priv->images->n_animation_pixbufs);
	}

	g_signal_emit (spinner, spinner_signals[FRAME], 0, priv->images->animation_pixbufs[priv->current_image]);

	/* run again */
	return TRUE;
}

/**
 * gitg_spinner_start:
 * @spinner: a #GitgSpinner
 *
 * Start the spinner animation.
 **/
void
gitg_spinner_start (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	priv->spinning = TRUE;

	if (priv->timer_task == 0 && gitg_spinner_load_images (spinner))
	{
		/* the 0th frame is the 'rest' icon */
		priv->current_image = MIN (0, priv->images->n_animation_pixbufs);

		priv->timer_task = g_timeout_add_full (G_PRIORITY_LOW,
						       priv->timeout,
						       (GSourceFunc) bump_spinner_frame_cb,
						       spinner,
						       NULL);

		bump_spinner_frame_cb (spinner);
	}
}

static void
gitg_spinner_remove_update_callback (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	if (priv->timer_task != 0)
	{
		g_source_remove (priv->timer_task);
		priv->timer_task = 0;
	}
}

/**
 * gitg_spinner_stop:
 * @spinner: a #GitgSpinner
 *
 * Stop the spinner animation.
 **/
void
gitg_spinner_stop (GitgSpinner *spinner)
{
	GitgSpinnerPrivate *priv = spinner->priv;

	priv->spinning = FALSE;
	priv->current_image = 0;

	if (priv->timer_task != 0)
	{
		gitg_spinner_remove_update_callback (spinner);
	}
}

void
gitg_spinner_set_screen (GitgSpinner *spinner, GdkScreen *screen)
{
	g_return_if_fail (GITG_IS_SPINNER (spinner));
	g_return_if_fail (GDK_IS_SCREEN (screen));

	if (spinner->priv->screen != screen)
	{
		gitg_spinner_unload_images (spinner);
		
		if (spinner->priv->screen)
		{
			g_object_unref (spinner->priv->screen);
		}
		
		spinner->priv->screen = g_object_ref (screen);
	}
}

static void
gitg_spinner_dispose (GObject *object)
{
	//GitgSpinner *spinner = GITG_SPINNER (object);

	G_OBJECT_CLASS (parent_class)->dispose (object);
}

static void
gitg_spinner_finalize (GObject *object)
{
	GitgSpinner *spinner = GITG_SPINNER (object);

	gitg_spinner_remove_update_callback (spinner);
	gitg_spinner_unload_images (spinner);

	g_object_unref (spinner->priv->cache);

	G_OBJECT_CLASS (parent_class)->finalize (object);
}

static void
gitg_spinner_class_init (GitgSpinnerClass *class)
{
	GObjectClass *object_class =  G_OBJECT_CLASS (class);

	parent_class = g_type_class_peek_parent (class);

	object_class->dispose = gitg_spinner_dispose;
	object_class->finalize = gitg_spinner_finalize;
	
	spinner_signals[FRAME] =
   		g_signal_new ("frame",
			      G_OBJECT_CLASS_TYPE (object_class),
			      G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (GitgSpinnerClass, frame),
			      NULL, NULL,
			      g_cclosure_marshal_VOID__OBJECT,
			      G_TYPE_NONE,
			      1,
			      GDK_TYPE_PIXBUF);

	g_type_class_add_private (object_class, sizeof (GitgSpinnerPrivate));
}

GitgSpinner *
gitg_spinner_new (GtkIconSize size)
{
	GitgSpinner *spinner = g_object_new (GITG_TYPE_SPINNER, NULL);
	
	spinner->priv->size = size;
	return spinner;
}

GdkPixbuf *
gitg_spinner_get_pixbuf (GitgSpinner *spinner)
{
	g_return_val_if_fail (GITG_IS_SPINNER (spinner), NULL);
	
	if (spinner->priv->timer_task == 0)
	{
		return NULL;
	}
	
	return g_object_ref (spinner->priv->images->animation_pixbufs[spinner->priv->current_image]);
}
