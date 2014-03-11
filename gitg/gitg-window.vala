/*
 * This file is part of gitg
 *
 * Copyright (C) 2012 - Jesse van den Kieboom
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

[GtkTemplate (ui = "/org/gnome/gitg/ui/gitg-window.ui")]
public class Window : Gtk.ApplicationWindow, GitgExt.Application, Initable
{
	private Settings d_state_settings;
	private Settings d_interface_settings;
	private Repository? d_repository;
	private GitgExt.MessageBus d_message_bus;
	private string? d_action;
	private Gee.HashMap<string, string> d_environment;

	private UIElements<GitgExt.Activity> d_activities;

	// Widgets
	[GtkChild]
	private Gtk.HeaderBar d_header_bar;
	[GtkChild]
	private Gtk.ToggleButton d_search_button;
	[GtkChild]
	private Gtk.MenuButton d_gear_menu;
	private MenuModel d_dash_model;
	private MenuModel d_activities_model;



	[GtkChild]
	private Gtk.Button d_dash_button;
	[GtkChild]
	private Gtk.Image dash_image;
	[GtkChild]
	private Gtk.StackSwitcher d_activities_switcher;

	[GtkChild]
	private Gtk.SearchBar d_search_bar;
	[GtkChild]
	private Gd.TaggedEntry d_search_entry;

	[GtkChild]
	private Gtk.Stack d_main_stack;

	[GtkChild]
	private Gtk.ScrolledWindow d_dash_scrolled_window;
	[GtkChild]
	private Gitg.RepositoryListBox d_dash_view;

	[GtkChild]
	private Gtk.Stack d_stack_activities;

	[GtkChild]
	private Gtk.Revealer d_infobar_revealer;
	[GtkChild]
	private Gtk.InfoBar d_infobar;
	[GtkChild]
	private Gtk.Label d_infobar_primary_label;
	[GtkChild]
	private Gtk.Label d_infobar_secondary_label;
	[GtkChild]
	private Gtk.Button d_infobar_close_button;

	private static const ActionEntry[] win_entries = {
		{"search", on_search_activated, null, "false", null},
		{"gear-menu", on_gear_menu_activated, null, "false", null},
		{"open-repository", on_open_repository},
		{"clone-repository", on_clone_repository},
		{"close", on_close_activated},
		{"reload", on_reload_activated},
		{"author-details-global", on_global_author_details_activated},
		{"author-details-repo", on_repo_author_details_activated},
	};

	[GtkCallback]
	private void dash_button_clicked(Gtk.Button dash)
	{
		repository = null;
	}

	[GtkCallback]
	private void search_button_toggled(Gtk.ToggleButton button)
	{
		if (button.get_active())
		{
			d_search_entry.grab_focus();
		}
		else
		{
			d_search_entry.set_text("");
		}
	}

	[GtkCallback]
	private void search_entry_changed(Gtk.Editable entry)
	{
		// FIXME: this is a weird way to know the dash is visible
		if (d_repository == null)
		{
			d_dash_view.filter_text((entry as Gtk.Entry).text);
		}
	}

	[GtkCallback]
	private void dash_view_repository_activated(Repository r)
	{
		repository = r;
	}

	[GtkCallback]
	private void dash_view_show_error(string primary_msg, string secondary_message)
	{
		show_infobar(primary_msg, secondary_message, Gtk.MessageType.ERROR);
	}

	construct
	{
		add_action_entries(win_entries, this);

		d_interface_settings = new Settings("org.gnome.gitg.preferences.interface");

		string menuname;

		if (Gtk.Settings.get_default().gtk_shell_shows_app_menu)
		{
			menuname = "win-menu";
		}
		else
		{
			menuname = "app-win-menu";
		}

		d_dash_model = Resource.load_object<MenuModel>("ui/gitg-menus.ui", menuname + "-dash");
		d_activities_model = Resource.load_object<MenuModel>("ui/gitg-menus.ui", menuname + "-views");

		// search bar
		d_search_bar.connect_entry(d_search_entry);
		d_search_button.bind_property("active", d_search_bar, "search-mode-enabled", BindingFlags.BIDIRECTIONAL);

		d_activities_switcher.set_stack(d_stack_activities);

		d_environment = new Gee.HashMap<string, string>();

		foreach (var e in Environment.list_variables())
		{
			d_environment[e] = Environment.get_variable(e);
		}

		if (get_direction () == Gtk.TextDirection.RTL)
		{
			dash_image.icon_name = "go-previous-rtl-symbolic";
		}
		else
		{
			dash_image.icon_name = "go-previous-symbolic";
		}

		// temporary check for 3.11 to switch header bar buttons. This check can
		// be removed when we bump the gtk+ requirement to 3.12
		if (Gtk.check_version(3, 11, 0) == null)
		{
			d_header_bar.remove(d_activities_switcher);
			d_header_bar.remove(d_search_button);
			d_header_bar.remove(d_gear_menu);

			d_header_bar.pack_end(d_gear_menu);
			d_header_bar.pack_end(d_search_button);
			d_header_bar.pack_end(d_activities_switcher);
		}
	}

	private void on_close_activated()
	{
		close();
	}

	private void on_search_activated(SimpleAction action)
	{
		var state = action.get_state().get_boolean();

		action.set_state(new Variant.boolean(!state));
	}

	private void on_gear_menu_activated(SimpleAction action)
	{
		var state = action.get_state().get_boolean();

		action.set_state(new Variant.boolean(!state));
	}

	public GitgExt.Activity? current_activity
	{
		owned get { return d_activities.current; }
	}

	public GitgExt.MessageBus message_bus
	{
		owned get { return d_message_bus; }
	}

	[CCode(notify = false)]
	public Repository? repository
	{
		owned get { return d_repository; }
		set
		{
			d_repository = value;

			notify_property("repository");
			repository_changed();
		}
	}

	private void repository_changed()
	{
		if (d_repository != null)
		{
			// set title
			File? workdir = d_repository.get_workdir();

			if (workdir != null)
			{
				string parent_path = workdir.get_parent().get_path();
				bool contains_home_dir = parent_path.has_prefix(Environment.get_home_dir());

				if (contains_home_dir)
				{
					parent_path = parent_path.replace(Environment.get_home_dir(), "~");
				}

				title = @"$(d_repository.name) ($parent_path) - gitg";
				d_infobar_revealer.set_reveal_child(false);
			}

			d_header_bar.set_title(d_repository.name);

			string? head_name = null;

			try
			{
				var head = repository.get_head();
				head_name = head.parsed_name.shortname;
			}
			catch {}

			d_header_bar.set_subtitle(Markup.escape_text(head_name));

			d_main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT;
			d_main_stack.set_visible_child(d_stack_activities);
			d_activities_switcher.show();
			d_dash_button.show();
			d_dash_view.add_repository(d_repository);
			d_gear_menu.menu_model = d_activities_model;
		}
		else
		{
			title = "gitg";

			d_header_bar.set_title(_("Projects"));
			d_header_bar.set_subtitle(null);

			d_main_stack.transition_type = Gtk.StackTransitionType.SLIDE_RIGHT;
			d_main_stack.set_visible_child(d_dash_scrolled_window);
			d_activities_switcher.hide();
			d_dash_button.hide();
			d_gear_menu.menu_model = d_dash_model;
		}

		d_activities.update();

		if (d_repository != null)
		{
			activate_default_activity();
		}
	}

	protected override bool window_state_event(Gdk.EventWindowState event)
	{
		d_state_settings.set_int("state", event.new_window_state);
		return base.window_state_event(event);
	}

	protected override bool configure_event(Gdk.EventConfigure event)
	{
		if (this.get_realized() && !(Gdk.WindowState.MAXIMIZED in get_window().get_state()))
		{
			d_state_settings.set("size", "(ii)", event.width, event.height);
		}

		return base.configure_event(event);
	}

	private void on_open_repository()
	{
		var chooser = new Gtk.FileChooserDialog (_("Open Repository"), this,
		                                         Gtk.FileChooserAction.SELECT_FOLDER,
		                                         _("_Cancel"), Gtk.ResponseType.CANCEL,
		                                         _("_Open"), Gtk.ResponseType.OK);

		chooser.modal = true;

		chooser.response.connect((c, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				var file = chooser.get_file();

				if (file == null)
				{
					file = chooser.get_current_folder_file();
				}

				open_repository(file);
			}

			c.destroy();
		});

		chooser.show();
	}

	private void on_reload_activated()
	{
		try
		{
			d_repository = new Gitg.Repository(this.repository.get_location(),
			                                   null);

			notify_property("repository");
			d_activities.current.reload();
		}
		catch {}
	}

	private void on_clone_repository()
	{
		var dlg = new CloneDialog(this);

		dlg.response.connect((d, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				d_dash_view.clone_repository(dlg.url, dlg.location, dlg.is_bare);
			}

			d.destroy();
		});

		dlg.show();
	}

	private void on_global_author_details_activated()
	{
		Ggit.Config global_config = null;

		try
		{
			global_config = new Ggit.Config.default();
		}
		catch (Error e)
		{
			return;
		}

		var author_details = new AuthorDetailsDialog(this, global_config, null);
		author_details.show();
	}

	private void on_repo_author_details_activated()
	{
		Ggit.Config repo_config = null;

		try
		{
			repo_config = d_repository.get_config();
		}
		catch (Error e)
		{
			return;
		}

		var author_details = new AuthorDetailsDialog(this, repo_config, d_repository.name);
		author_details.show();
	}

	private void on_current_activity_changed(Object obj, ParamSpec pspec)
	{
		notify_property("current_activity");
	}

	private void activate_default_activity()
	{
		GitgExt.Activity? def = null;

		d_activities.foreach((element) => {
				GitgExt.Activity activity = (GitgExt.Activity)element;

				if (activity.is_default_for(d_action != null ? d_action : ""))
				{
					def = activity;
				}

				return true;
		});

		if (def != null)
		{
			d_activities.current = def;
		}
	}

	private bool init(Cancellable? cancellable)
	{
		// Settings
		var app = application as Gitg.Application;
		d_state_settings = app.state_settings;

		// Setup message bus
		d_message_bus = new GitgExt.MessageBus();

		// Initialize peas extensions set for activities
		var engine = PluginsEngine.get_default();

		var builtins = new GitgExt.Activity[] {
			new GitgHistory.Activity(this),
			new GitgCommit.Activity(this)
		};

		var extset = new Peas.ExtensionSet(engine,
		                                   typeof(GitgExt.Activity),
		                                   "application",
		                                   this);

		d_activities = new UIElements<GitgExt.Activity>.with_builtin(builtins,
		                                                             extset,
		                                                             d_stack_activities);

		d_activities.notify["current"].connect(on_current_activity_changed);

		// Setup window geometry saving
		Gdk.WindowState window_state = (Gdk.WindowState)d_state_settings.get_int("state");

		if (Gdk.WindowState.MAXIMIZED in window_state)
		{
			maximize();
		}

		int width;
		int height;

		d_state_settings.get("size", "(ii)", out width, out height);
		resize(width, height);

		return true;
	}

	public void set_environment(string[] environment)
	{
		d_environment = new Gee.HashMap<string, string>();

		foreach (var e in environment)
		{
			string[] parts = e.split("=", 2);

			if (parts.length == 1)
			{
				d_environment[parts[0]] = "";
			}
			else
			{
				d_environment[parts[0]] = parts[1];
			}
		}
	}

	public static Window? create_new(Gtk.Application app,
	                                 Repository? repository,
	                                 string? action)
	{
		Window? ret = new Window();

		if (ret != null)
		{
			ret.application = app;
			ret.d_repository = repository;
			ret.d_action = action;
		}

		try
		{
			((Initable)ret).init(null);
		} catch {}

		ret.repository_changed();
		return ret;
	}

	/* public API implementation of GitgExt.Application */
	public GitgExt.Activity? activity(string id)
	{
		GitgExt.Activity? v = d_activities.lookup(id);

		if (v != null)
		{
			d_activities.current = v;
		}

		if (d_activities.current == v)
		{
			return v;
		}
		else
		{
			return null;
		}
	}

	private void open_repository(File path)
	{
		File repo;
		Gitg.Repository? repository = null;

		if (d_repository != null &&
		    d_repository.get_location().equal(path))
		{
			return;
		}

		try
		{
			repo = Ggit.Repository.discover(path);
		}
		catch (Error e)
		{
			string repo_name = path.get_basename();

			var primary_msg = _("'%s' is not a Git repository.").printf(repo_name);
			show_infobar(primary_msg, e.message, Gtk.MessageType.WARNING);

			return;
		}

		try
		{
			repository = new Gitg.Repository(repo, null);
		}
		catch {}

		this.repository = repository;
	}

	public void show_infobar(string          primary_msg,
	                         string          secondary_msg,
	                         Gtk.MessageType type)
	{
		d_infobar.message_type = type;

		var primary = "<b>%s</b>".printf(Markup.escape_text(primary_msg));
		var secondary = "<small>%s</small>".printf(Markup.escape_text(secondary_msg));

		d_infobar_primary_label.set_label(primary);
		d_infobar_secondary_label.set_label(secondary);
		d_infobar_revealer.set_reveal_child(true);

		d_infobar_close_button.clicked.connect(() => {
			d_infobar_revealer.set_reveal_child(false);
		});
	}

	public Gee.Map<string, string> environment
	{
		owned get { return d_environment; }
	}
}

}

// ex:ts=4 noet
