/*
 * gitg-utils.h
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

#ifndef __GITG_UTILS_H__
#define __GITG_UTILS_H__

#include <glib.h>
#include <gio/gio.h>
#include <gtksourceview/gtksourcelanguagemanager.h>
#include <gtksourceview/gtksourcelanguage.h>

#include <libgitg/gitg-repository.h>
#include <libgitg/gitg-revision.h>

gchar *gitg_utils_get_content_type(GFile *file);
gboolean gitg_utils_can_display_content_type(gchar const *content_type);
gchar *gitg_utils_guess_content_type(GtkTextBuffer *buffer);

gboolean gitg_utils_export_files(GitgRepository *repository, GitgRevision *revision,
gchar const *todir, gchar * const *paths);

GtkSourceLanguage *gitg_utils_get_language(gchar const *filename, gchar const *content_type);

gchar *gitg_utils_get_monospace_font_name(void);
void gitg_utils_set_monospace_font(GtkWidget *widget);

GtkBuilder *gitg_utils_new_builder (gchar const *filename);

gint gitg_utils_sort_names(gchar const *s1, gchar const *s2);

void gitg_utils_menu_position_under_widget(GtkMenu *menu, gint *x, gint *y,	gboolean *push_in, gpointer user_data);
void gitg_utils_menu_position_under_tree_view(GtkMenu *menu, gint *x, gint *y, gboolean *push_in, gpointer user_data);

gchar *gitg_utils_rewrite_hunk_counters (gchar const *hunk, guint old_count, guint new_count);

GtkCellRenderer *gitg_utils_find_cell_at_pos (GtkTreeView *tree_view, GtkTreeViewColumn *column, GtkTreePath *path, gint x);

void gitg_utils_restore_pane_position (GtkPaned *paned, gint position, gboolean reversed);

void gitg_utils_rounded_rectangle (cairo_t *ctx, gdouble x, gdouble y, gdouble width, gdouble height, gdouble radius);

#endif /* __GITG_UTILS_H__ */
