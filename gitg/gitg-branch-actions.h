/*
 * gitg-branch-actions.h
 * This file is part of gitg
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

#ifndef __GITG_BRANCH_ACTIONS_H__
#define __GITG_BRANCH_ACTIONS_H__

#include "gitg-window.h"
#include "gitg-ref.h"

G_BEGIN_DECLS

GitgRunner *gitg_branch_actions_remove (GitgWindow *window, GitgRef *ref);
GitgRunner *gitg_branch_actions_rename (GitgWindow *window, GitgRef *ref);
gboolean gitg_branch_actions_checkout (GitgWindow *window, GitgRef *ref);

GitgRunner *gitg_branch_actions_merge (GitgWindow *window, GitgRef *source, GitgRef *dest);
GitgRunner *gitg_branch_actions_rebase (GitgWindow *window, GitgRef *source, GitgRef *dest);

GitgRunner *gitg_branch_actions_push (GitgWindow *window, GitgRef *source, GitgRef *dest);
GitgRunner *gitg_branch_actions_push_remote (GitgWindow *window, GitgRef *source, gchar const *remote, gchar const *branch);

gboolean gitg_branch_actions_apply_stash (GitgWindow *window, GitgRef *stash, GitgRef *branch);

gboolean gitg_branch_actions_tag (GitgWindow *window, gchar const *sha1, gchar const *name, gchar const *message, gboolean sign);

G_END_DECLS

#endif /* __GITG_BRANCH_ACTIONS_H__ */

