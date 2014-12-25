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

namespace Gitg
{

class RefActionCopyName : GitgExt.UIElement, GitgExt.Action, GitgExt.RefAction, Object
{
  // Do this to pull in config.h before glib.h (for gettext...)
  private const string version = Gitg.Config.VERSION;

  public GitgExt.Application? application { owned get; construct set; }
  public GitgExt.RefActionInterface action_interface { get; construct set; }
  public Gitg.Ref reference { get; construct set; }

  public RefActionCopyName(GitgExt.Application        application,
                           GitgExt.RefActionInterface action_interface,
                           Gitg.Ref                   reference)
  {
    Object(application:      application,
           action_interface: action_interface,
           reference:        reference);
  }

  public string id
  {
    owned get { return "/org/gnome/gitg/ref-actions/copy-name"; }
  }

  public string display_name
  {
    owned get { return _("Copy name"); }
  }

  public string description
  {
    owned get { return _("Copy the name of the reference to the clipboard"); }
  }

  public bool enabled
  {
    get { return true; }
  }

  public void activate()
  {
    var clip = ((Gtk.Widget)application).get_clipboard(Gdk.SELECTION_CLIPBOARD);
    clip.set_text(reference.parsed_name.shortname, -1);

    clip = ((Gtk.Widget)application).get_clipboard(Gdk.SELECTION_PRIMARY);
    clip.set_text(reference.parsed_name.shortname, -1);
  }
}

}

// ex:set ts=4 noet
