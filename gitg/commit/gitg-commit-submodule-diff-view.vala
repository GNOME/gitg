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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-commit-submodule-diff-view.ui")]
class SubmoduleDiffView : Gtk.Box
{
  [GtkChild (name = "info")]
  private SubmoduleInfo d_info;

  [GtkChild (name = "diff_view_staged")]
  private Gitg.DiffView d_diff_view_staged;

  [GtkChild (name = "diff_view_unstaged")]
  private Gitg.DiffView d_diff_view_unstaged;

  [GtkChild (name = "box_diffs")]
  private Gtk.Box d_box_diffs;

  construct
  {
    var interface_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

    interface_settings.bind("orientation",
                            d_box_diffs,
                            "orientation",
                            SettingsBindFlags.GET);
  }

  public SubmoduleInfo info
  {
    get { return d_info; }
  }

  public Gitg.DiffView diff_view_staged
  {
    get { return d_diff_view_staged; }
  }

  public Gitg.DiffView diff_view_unstaged
  {
    get { return d_diff_view_unstaged; }
  }
}

}