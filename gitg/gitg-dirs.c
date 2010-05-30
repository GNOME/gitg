/*
 * gitg-dirs.c
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
 * Foundation, Inc., 51 Franklin St, Fifth Floor,
 * Boston, MA  02110-1301  USA
 */

#include "gitg-dirs.h"
#include "config.h"

gchar const *
gitg_dirs_get_data_dir (void)
{
	static gchar *datadir = NULL;

	if (!datadir)
	{
		datadir = g_strdup (GITG_DATADIR);
	}

	return datadir;
}

gchar *
gitg_dirs_get_data_filename(gchar const *first, ...)
{
	gchar const *datadir = gitg_dirs_get_data_dir();
	gchar *ret;

	ret = g_build_filename(datadir, first, NULL);
	gchar const *item;

	va_list ap;
	va_start(ap, first);

	while ((item = va_arg(ap, gchar const *)))
	{
		gchar *tmp = ret;
		ret = g_build_filename(ret, item, NULL);
		g_free(tmp);
	}

	va_end(ap);
	return ret;
}

void
gitg_dirs_initialize(int argc, char **argv)
{
	gchar *path = g_path_get_dirname(argv[0]);

	if (!g_path_is_absolute(path))
	{
		gchar *tmp = path;
		gchar *cwd = g_get_current_dir();

		path = g_build_filename(cwd, tmp, NULL);
		g_free(tmp);
		g_free(cwd);
	}

	g_free(path);
}
