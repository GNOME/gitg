/*
 * gitg-config.h
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

#ifndef __GITG_CONFIG_H__
#define __GITG_CONFIG_H__

#include <glib-object.h>
#include <libgitg/gitg-repository.h>

G_BEGIN_DECLS

#define GITG_TYPE_CONFIG		(gitg_config_get_type ())
#define GITG_CONFIG(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CONFIG, GitgConfig))
#define GITG_CONFIG_CONST(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GITG_TYPE_CONFIG, GitgConfig const))
#define GITG_CONFIG_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GITG_TYPE_CONFIG, GitgConfigClass))
#define GITG_IS_CONFIG(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GITG_TYPE_CONFIG))
#define GITG_IS_CONFIG_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GITG_TYPE_CONFIG))
#define GITG_CONFIG_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GITG_TYPE_CONFIG, GitgConfigClass))

typedef struct _GitgConfig		GitgConfig;
typedef struct _GitgConfigClass		GitgConfigClass;
typedef struct _GitgConfigPrivate	GitgConfigPrivate;

struct _GitgConfig
{
	GObject parent;

	GitgConfigPrivate *priv;
};

struct _GitgConfigClass
{
	GObjectClass parent_class;
};

GType       gitg_config_get_type        (void) G_GNUC_CONST;
GitgConfig *gitg_config_new             (GitgRepository *repository);

gchar      *gitg_config_get_value       (GitgConfig     *config,
                                         gchar const    *key);

gchar      *gitg_config_get_value_regex (GitgConfig     *config,
                                         gchar const    *regex,
                                         gchar const    *value_regex);

gboolean    gitg_config_rename          (GitgConfig     *config,
                                         gchar const    *old,
                                         gchar const    *nw);

gboolean    gitg_config_set_value       (GitgConfig     *config,
                                         gchar const    *key,
                                         gchar const    *value);

G_END_DECLS

#endif /* __GITG_CONFIG_H__ */
