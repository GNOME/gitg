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
	private Gtk.MenuButton d_config;

	private Gd.StackSwitcher d_commit_view_switcher;

	private Gtk.Paned d_paned_views;
	private Gtk.Paned d_paned_panels;

	private Gd.Stack d_stack_view;
	private Gd.Stack d_stack_panel;

	private GitgExt.NavigationTreeView d_navigation;

	public GitgExt.View? current_view
	{
		owned get { return d_views.current; }
	}

	public GitgExt.MessageBus message_bus
	{
		owned get { return d_message_bus; }
	}

	[Notify]
	public Repository? repository
	{
		owned get { return d_repository; }
		set
		{
			close();
			d_repository = value;

			repository_changed();
		}
	}

	private void repository_changed()
	{
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

	private void parser_finished(Gtk.Builder builder)
	{
		// Extract widgets from the builder
		d_header_bar = builder.get_object("header-bar") as Gd.HeaderBar;

		d_paned_views = builder.get_object("paned_views") as Gtk.Paned;
		d_paned_panels = builder.get_object("paned_panels") as Gtk.Paned;

		d_stack_view = builder.get_object("stack_view") as Gd.Stack;
		d_stack_panel = builder.get_object("stack_panel") as Gd.Stack;
		d_commit_view_switcher = builder.get_object("commit-view-switcher") as Gd.StackSwitcher;
		d_commit_view_switcher.stack = d_stack_panel;

		d_navigation = builder.get_object("tree_view_navigation") as GitgExt.NavigationTreeView;
		d_config = builder.get_object("button_config") as Gtk.MenuButton;

		var model = Resource.load_object<MenuModel>("ui/gitg-menus.ui", "win-menu");
		d_config.menu_model = model;

		var search_button = builder.get_object("search-button") as Gd.HeaderToggleButton;
		var revealer = builder.get_object("search-revealer") as Gd.Revealer;
		var entry = builder.get_object("search-entry") as Gd.TaggedEntry;

		search_button.bind_property("active", revealer, "reveal-child");
		search_button.toggled.connect((b) => {
			if (b.get_active())
			{
				entry.grab_focus();
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

		if (view != null)
		{
			// 2) Populate the navigation tree for this view
			d_navigation.model.populate(view.navigation);
			d_navigation.expand_all();

			d_navigation.select_first();
		}

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

				return false;
			}

			return true;
		});
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

		// FIXME: this should happen when updating the repository
		File? workdir = (d_repository != null) ? d_repository.get_workdir() : null;
		if (workdir != null)
		{
			d_header_bar.title = workdir.get_basename();
		}

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

		activate_default_view();
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

	public void open(File path)
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

	public void create(File path)
	{
		// TODO
	}

	public void close()
	{
		// TODO
	}
}

}

// ex:ts=4 noet
