/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2009 Mathias Hasselmann
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __GITG_AVATAR_CACHE_H__
#define __GITG_AVATAR_CACHE_H__

#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>

G_BEGIN_DECLS

#define GITG_TYPE_AVATAR_CACHE            (gitg_avatar_cache_get_type ())
#define GITG_AVATAR_CACHE(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_AVATAR_CACHE, GitgAvatarCache))
#define GITG_AVATAR_CACHE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_AVATAR_CACHE, GitgAvatarCacheClass))
#define GITG_IS_AVATAR_CACHE(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_AVATAR_CACHE))
#define GITG_IS_AVATAR_CACHE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_AVATAR_CACHE))
#define GITG_AVATAR_CACHE_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_AVATAR_CACHE, GitgAvatarCacheClass))

typedef struct _GitgAvatarCache        GitgAvatarCache;
typedef struct _GitgAvatarCachePrivate GitgAvatarCachePrivate;
typedef struct _GitgAvatarCacheClass   GitgAvatarCacheClass;

struct _GitgAvatarCache
{
	GObject parent_instance;

	GitgAvatarCachePrivate *priv;
};

struct _GitgAvatarCacheClass
{
	GObjectClass parent_class;
};

GType               gitg_avatar_cache_get_type         (void) G_GNUC_CONST;

GitgAvatarCache    *gitg_avatar_cache_new              (void);

void                gitg_avatar_cache_load_uri_async   (GitgAvatarCache   *cache,
                                                        const gchar         *uri,
                                                        gint                 io_priority,
                                                        GCancellable        *cancellable,
                                                        GAsyncReadyCallback  callback,
                                                        gpointer             user_data);

GdkPixbuf          *gitg_avatar_cache_load_finish      (GitgAvatarCache   *cache,
                                                        GAsyncResult        *result,
                                                        GError             **error);

gchar              *gitg_avatar_cache_get_gravatar_uri (GitgAvatarCache   *cache,
                                                        const gchar         *gravatar_id);

G_END_DECLS

#endif /* __GITG_AVATAR_CACHE_H__ */

