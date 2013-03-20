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

public class Window : Gtk.ApplicationWindow, GitgExt.Application, Initable, Gtk.Buildable
{
	private Settings d_state_settings;
	private Repository? d_repository;
	private GitgExt.MessageBus d_message_bus;
	private string? d_action;

	private UIElements<GitgExt.View> d_views;
	private UIElements<GitgExt.Panel> d_panels;


	// Widgets
	private Gd.HeaderBar d_header_bar;
	private Gtk.MenuButton d_gear_menu;

	private Gtk.Box d_dash_buttons_box;
	private Gd.HeaderSimpleButton d_button_dash;
	private Gd.StackSwitcher d_commit_view_switcher;

	private Gd.TaggedEntry d_search_entry;

	private Gd.Stack d_main_stack;

	private Gtk.ScrolledWindow d_dash_scrolled_window;
	private GitgGtk.DashView d_dash_view;

	private Gtk.Paned d_paned_views;
	private Gtk.Paned d_paned_panels;

	private Gd.Stack d_stack_view;
	private Gd.Stack d_stack_panel;

	private GitgExt.NavigationTreeView d_navigation;

	private static const ActionEntry[] win_entries = {
		{"search", on_search_activated, null, "false", null},
		{"gear-menu", on_gear_menu_activated, null, "false", null},
		{"close", on_close_activated},
	};

	construct
	{
		add_action_entries(win_entries, this);
	}

	private void on_close_activated()
	{
		destroy();
	}

	private void on_search_activated(SimpleAction action) {
		var state = action.get_state().get_boolean();
		action.set_state(new Variant.boolean(!state));
	}

	private void on_gear_menu_activated(SimpleAction action) {
		var state = action.get_state().get_boolean();
		action.set_state(new Variant.boolean(!state));
	}

	public GitgExt.View? current_view
	{
		owned get { return d_views.current; }
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
				title = "(%s) - gitg".printf(workdir.get_parse_name());
			}

			d_main_stack.transition_type = Gd.StackTransitionType.SLIDE_LEFT;
			d_main_stack.set_visible_child(d_paned_views);
			d_commit_view_switcher.show();
			d_button_dash.show();
			d_dash_buttons_box.hide();
			d_dash_view.add_repository(d_repository);
		}
		else
		{
			title = "gitg";

			d_main_stack.transition_type = Gd.StackTransitionType.SLIDE_RIGHT;
			d_main_stack.set_visible_child(d_dash_scrolled_window);
			d_commit_view_switcher.hide();
			d_button_dash.hide();
			d_dash_buttons_box.show();
		}

		d_views.update();
		activate_default_view();
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

	private void on_open_repository(Gtk.Button button)
	{
		var chooser = new Gtk.FileChooserDialog (_("Select Repository"), this,
		                                         Gtk.FileChooserAction.SELECT_FOLDER,
		                                         Gtk.Stock.CANCEL, Gtk.ResponseType.CANCEL,
		                                         Gtk.Stock.OPEN, Gtk.ResponseType.OK);
		chooser.modal = true;

		chooser.response.connect((c, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				open(chooser.get_current_folder_file());
			}

			c.destroy();
		});

		chooser.show();
	}

	private void on_clone_repository(Gtk.Button button)
	{
		var ret = GitgExt.UI.from_builder("ui/gitg-clone-dialog.ui",
		                                  "dialog-clone",
		                                  "entry-url",
		                                  "filechooserbutton-location",
		                                  "ok-button");

		var dlg = ret["dialog-clone"] as Gtk.Dialog;
		var entry_url = ret["entry-url"] as Gtk.Entry;
		var chooser = ret["filechooserbutton-location"] as Gtk.FileChooserButton;
		var ok_button = ret["ok-button"] as Gtk.Button;

		dlg.modal = true;
		dlg.set_transient_for(this);

		entry_url.changed.connect((e) => {
			ok_button.set_sensitive(entry_url.text_length != 0);
		});

		dlg.response.connect((d, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				//FIXME
			}

			d.destroy();
		});

		dlg.show();
	}

	private void parser_finished(Gtk.Builder builder)
	{
		// Extract widgets from the builder
		d_header_bar = builder.get_object("header-bar") as Gd.HeaderBar;

		d_dash_buttons_box = builder.get_object("dash_buttons_box") as Gtk.Box;
		var button_open_repository = builder.get_object("button_open_repository") as Gd.HeaderSimpleButton;
		button_open_repository.clicked.connect(on_open_repository);
		var button_clone_repository = builder.get_object("button_clone_repository") as Gd.HeaderSimpleButton;
		button_clone_repository.clicked.connect(on_clone_repository);

		d_button_dash = builder.get_object("button_dash") as Gd.HeaderSimpleButton;
		d_button_dash.clicked.connect((b) => {
			repository = null;
		});

		d_main_stack = builder.get_object("main_stack") as Gd.Stack;

		d_dash_scrolled_window = builder.get_object("dash_scrolled_window") as Gtk.ScrolledWindow;
		d_dash_view = builder.get_object("dash_view") as GitgGtk.DashView;
		d_dash_view.repository_activated.connect((r) => {
			repository = r;
		});

		d_paned_views = builder.get_object("paned_views") as Gtk.Paned;
		d_paned_panels = builder.get_object("paned_panels") as Gtk.Paned;

		d_stack_view = builder.get_object("stack_view") as Gd.Stack;
		d_stack_panel = builder.get_object("stack_panel") as Gd.Stack;
		d_commit_view_switcher = builder.get_object("commit-view-switcher") as Gd.StackSwitcher;
		d_commit_view_switcher.stack = d_stack_panel;

		d_navigation = builder.get_object("tree_view_navigation") as GitgExt.NavigationTreeView;
		d_gear_menu = builder.get_object("gear-menubutton") as Gtk.MenuButton;

		string menuname;

		if (Gtk.Settings.get_default().gtk_shell_shows_app_menu)
		{
			menuname = "win-menu";
		}
		else
		{
			menuname = "app-win-menu";
		}

		var model = Resource.load_object<MenuModel>("ui/gitg-menus.ui", menuname);
		d_gear_menu.menu_model = model;

		var search_button = builder.get_object("search-button") as Gd.HeaderToggleButton;
		var revealer = builder.get_object("search-revealer") as Gd.Revealer;
		d_search_entry = builder.get_object("search-entry") as Gd.TaggedEntry;

		search_button.bind_property("active", revealer, "reveal-child");
		search_button.toggled.connect((b) => {
			if (b.get_active())
			{
				d_search_entry.grab_focus();
			}
			else
			{
				d_search_entry.set_text("");
			}
		});

		d_search_entry.changed.connect((e) => {
			// FIXME: this is a weird way to know the dash is visible
			if (d_repository == null)
			{
				d_dash_view.filter_text((e as Gtk.Entry).text);
			}
		});

		var settings = new Settings("org.gnome.gitg.preferences.interface");

		settings.bind("orientation",
		              d_paned_panels,
		              "orientation",
		              SettingsBindFlags.GET);

		base.parser_finished(builder);
	}

	private void on_view_activated(UIElements elements,
	                               GitgExt.UIElement element)
	{
		GitgExt.View? view = (GitgExt.View?)element;

		// 1) Clear the navigation tree
		d_navigation.model.clear();

		if (view != null && view.navigation != null)
		{
			d_navigation.set_show_expanders(view.navigation.show_expanders);

			if (view.navigation.show_expanders)
			{
				d_navigation.set_level_indentation(0);
			}
			else
			{
				d_navigation.set_level_indentation(12);
			}

			// 2) Populate the navigation tree for this view
			d_navigation.model.populate(view.navigation);
		}
		
		d_navigation.expand_all();
		d_navigation.select_first();

		// Update panels
		d_panels.update();
		notify_property("current_view");
	}

	private void on_panel_activated(UIElements elements,
	                                GitgExt.UIElement element)
	{
	}

	private void activate_default_view()
	{
		bool didactivate = false;

		d_views.foreach((element) => {
			GitgExt.View view = (GitgExt.View)element;

			if (view.is_default_for(d_action != null ? d_action : ""))
			{
				if (d_views.current == view)
				{
					on_view_activated(d_views, view);
				}
				else
				{
					d_views.current = view;
				}

				didactivate = true;
				return false;
			}

			return true;
		});

		if (!didactivate && d_views.current != null)
		{
			on_view_activated(d_views, d_views.current);
		}
	}

	private bool init(Cancellable? cancellable)
	{
		// Settings
		var app = application as Gitg.Application;
		d_state_settings = app.state_settings;

		// Setup message bus
		d_message_bus = new GitgExt.MessageBus();

		// Initialize peas extensions set for views
		var engine = PluginsEngine.get_default();

		d_views = new UIElements<GitgExt.View>(new Peas.ExtensionSet(engine,
		                                                            typeof(GitgExt.View),
		                                                            "application",
		                                                            this),
		                                       d_stack_view);

		d_views.activated.connect(on_view_activated);

		d_panels = new UIElements<GitgExt.Panel>(new Peas.ExtensionSet(engine,
		                                                               typeof(GitgExt.Panel),
		                                                               "application",
		                                                               this),
		                                         d_stack_panel);

		d_panels.activated.connect(on_panel_activated);

		// Setup window geometry saving
		Gdk.WindowState window_state = (Gdk.WindowState)d_state_settings.get_int("state");
		if (Gdk.WindowState.MAXIMIZED in window_state) {
			maximize ();
		}

		int width, height;
		d_state_settings.get ("size", "(ii)", out width, out height);
		resize (width, height);

		d_state_settings.bind("paned-views-position",
		                      d_paned_views,
		                      "position",
		                      SettingsBindFlags.GET | SettingsBindFlags.SET);

		d_state_settings.bind("paned-panels-position",
		                      d_paned_panels,
		                      "position",
		                      SettingsBindFlags.GET | SettingsBindFlags.SET);

		return true;
	}

	public static Window? create_new(Gtk.Application app,
	                                 Repository? repository,
	                                 string? action)
	{
		Window? ret = Resource.load_object<Window>("ui/gitg-window.ui", "window");

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
	public GitgExt.View? view(string id)
	{
		GitgExt.View? v = d_views.lookup(id);

		if (v != null)
		{
			d_views.current = v;
		}

		if (d_views.current == v)
		{
			return v;
		}
		else
		{
			return null;
		}
	}

	private void open(File path)
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
		catch
		{
			// TODO: make error thingie
			return;
		}

		try
		{
			repository = new Gitg.Repository(repo, null);
		}
		catch {}

		this.repository = repository;
	}
}

}

// ex:ts=4 noet
