/*
 * This file is part of gitg
 *
 * Copyright (C) 2026 - Alberto Fanjul
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

using Gtk;
using Gee;

namespace Gitg
{

public class EntryHistory : Gtk.Entry {
    private ArrayList<string> history;
    private int history_position;
    private string current_text;
    private string history_file;
    private Gtk.ListStore completion_store;

    public signal void activated_with_text (string text);

    public EntryHistory (string? history_file_path = null) {
        history = new ArrayList<string> ();
        history_position = -1;
        current_text = "";

        if (history_file_path != null) {
            history_file = history_file_path;
        } else {
            history_file = Path.build_filename (
                Environment.get_user_cache_dir (),
                "gtk_entry_history.txt"
            );
        }

        load_history ();

        setup_completion ();

        activate.connect (on_activate);
        key_press_event.connect (on_key_press);
    }

    private void setup_completion () {
        var completion = new Gtk.EntryCompletion ();

        completion_store = new Gtk.ListStore (1, typeof (string));
        completion.set_model (completion_store);
        completion.set_text_column (0);

        completion.inline_completion = true;
        completion.inline_selection = true;
        completion.popup_completion = true;
        completion.popup_single_match = false;

        this.set_completion (completion);

        update_completion ();
    }

    private void update_completion () {
        completion_store.clear ();

        foreach (string item in history) {
            Gtk.TreeIter iter;
            completion_store.append (out iter);
            completion_store.set (iter, 0, item);
        }
    }

    private void load_history () {
        history.clear ();

        var file = File.new_for_path (history_file);

        if (!file.query_exists ()) {
            return;
        }

        try {
            var dis = new DataInputStream (file.read ());
            string line;

            while ((line = dis.read_line (null)) != null) {
                line = line.strip ();
                if (line.length > 0) {
                    history.add (line);
                }
            }

        } catch (Error e) {
            stderr.printf ("Error loading history: %s\n", e.message);
        }
    }

    private void save_history () {
        var file = File.new_for_path (history_file);

        try {
            var parent = file.get_parent ();
            if (parent != null && !parent.query_exists ()) {
                parent.make_directory_with_parents ();
            }

            var dos = new DataOutputStream (file.replace (null, false,
                FileCreateFlags.REPLACE_DESTINATION));

            foreach (string item in history) {
                dos.put_string (item + "\n");
            }

        } catch (Error e) {
            stderr.printf ("Error saving history: %s\n", e.message);
        }
    }

    private void on_activate () {
        string text = this.text.strip ();

        if (text.length == 0) {
            return;
        }

        if (history.size == 0 || history[history.size - 1] != text) {
            history.remove (text);

            history.add (text);

            while (history.size > 1000) {
                history.remove_at (0);
            }

            save_history ();

            update_completion ();
        }

        history_position = -1;
        current_text = "";

        activated_with_text (text);
    }

    private bool on_key_press (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.Up) {
            navigate_history_up ();
            return true;
        }

        if (event.keyval == Gdk.Key.Down) {
            navigate_history_down ();
            return true;
        }

        if (event.keyval != Gdk.Key.Up &&
            event.keyval != Gdk.Key.Down &&
            event.keyval != Gdk.Key.Return) {
            history_position = -1;
        }

        return false;
    }

    private void navigate_history_up () {
        if (history.size == 0) {
            return;
        }

        if (history_position == -1) {
            current_text = this.text;
            history_position = history.size;
        }

        if (history_position > 0) {
            history_position--;
            this.text = history[history_position];
            this.set_position (-1);
        }
    }

    private void navigate_history_down () {
        if (history.size == 0 || history_position == -1) {
            return;
        }

        history_position++;

        if (history_position >= history.size) {
            // Restore current text
            this.text = current_text;
            history_position = -1;
        } else {
            this.text = history[history_position];
        }

        this.set_position (-1);
    }

    public void clear_history () {
        history.clear ();
        save_history ();
        update_completion ();
    }

    public ArrayList<string> get_history () {
        return history;
    }
}
}
// ex: ts=4 noet
