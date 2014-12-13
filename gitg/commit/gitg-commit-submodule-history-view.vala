/*
 * This file is part of gitg
 *
 * Copyright (C) 2014 - Jesse van den Kieboom
 *
 * gitg is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * gitg is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with gitg. If not, see <http://www.gnu.org/licenses/>.
 */

namespace GitgCommit
{

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-submodule-history-view.ui")]
class SubmoduleHistoryView : Gtk.Paned
{
  [GtkChild (name = "commit_list_view")]
  private Gitg.CommitListView d_commit_list_view;

  [GtkChild (name = "diff_view")]
  private Gitg.DiffView d_diff_view;

  public Gitg.CommitListView commit_list_view
  {
    get { return d_commit_list_view; }
  }

  public Gitg.DiffView diff_view
  {
    get { return d_diff_view; }
  }
}

}