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
	// Do this to pull in config.h before glib.h (for gettext...)
	private const string version = Gitg.Config.VERSION;

	private Settings d_state_settings;
	private Settings d_interface_settings;
	private Repository? d_repository;
	private RecursiveMonitor? d_repository_monitor;
	private GitgExt.MessageBus d_message_bus;
	private string? d_action;
	private Gee.HashMap<string, string> d_environment;
	private bool d_busy;
	private Gtk.Dialog? d_dialog;
	private Gtk.Widget? d_select_actions;

	private Binding? d_selectable_mode_binding;
	private Binding? d_selectable_available_binding;
	private Binding? d_searchable_available_binding;
	private GitgExt.SelectionMode d_selectable_mode;

	private UIElements<GitgExt.Activity> d_activities;

	private RemoteManager d_remote_manager;
	private Notifications d_notifications;
	private PreferencesDialog d_preferences;

#if GTK_SHORTCUTS_WINDOW
	private Gtk.ShortcutsWindow d_shortcuts;
#endif

	// Widgets
	[GtkChild]
	private Gtk.HeaderBar d_header_bar;
	[GtkChild]
	private Gtk.ToggleButton d_search_button;
	[GtkChild]
	private Gtk.MenuButton d_gear_menu;
	[GtkChild]
	private Gtk.Image gear_image;
	private MenuModel d_activities_model;
	private MenuModel? d_dash_model;

	[GtkChild]
	private Gtk.Grid d_grid_main;

	[GtkChild]
	private Gtk.Grid d_grid_top;

	[GtkChild]
	private Gtk.ToggleButton d_select_button;
	[GtkChild]
	private Gtk.Button d_select_cancel_button;

	[GtkChild]
	private Gtk.Button d_dash_button;
	[GtkChild]
	private Gtk.Button d_clone_button;
	[GtkChild]
	private Gtk.Button d_add_button;
	[GtkChild]
	private Gtk.Image dash_image;
	[GtkChild]
	private Gtk.StackSwitcher d_activities_switcher;

	[GtkChild]
	private Gtk.SearchBar d_search_bar;
	[GtkChild]
	private Gtk.SearchEntry d_search_entry;

	[GtkChild]
	private Gtk.Stack d_main_stack;

	[GtkChild]
	private DashView d_dash_view;

	[GtkChild]
	private Gtk.Stack d_stack_activities;

	[GtkChild]
	private Gtk.InfoBar d_infobar;
	[GtkChild]
	private Gtk.Label d_infobar_primary_label;
	[GtkChild]
	private Gtk.Label d_infobar_secondary_label;

	[GtkChild]
	private Gtk.Overlay d_overlay;

	enum Mode
	{
		DASH,
		ACTIVITY
	}

	private Mode d_mode;

	[Signal(action = true)]
	public virtual signal bool change_to_activity(int i)
	{
		if (d_selectable_mode == GitgExt.SelectionMode.SELECTION)
		{
			return false;
		}

		if (i == 0)
		{
			if (d_mode == Mode.ACTIVITY)
			{
				repository = null;
				return true;
			}
			else
			{
				return false;
			}
		}

		if (d_mode != Mode.ACTIVITY)
		{
			return false;
		}

		var elems = d_activities.get_available_elements();
		i--;

		if (i >= elems.length)
		{
			return false;
		}

		d_activities.current = elems[i];
		return true;
	}

	private const ActionEntry[] win_entries = {
		{"search", on_search_activated, null, "false", null},
		{"gear-menu", on_gear_menu_activated, null, "false", null},
		{"close", on_close_activated},
		{"reload", on_reload_activated},
		{"author-details-repo", on_repo_author_details_activated},
		{"preferences", on_preferences_activated},
		{"select", on_select_activated, null, "false", null}
	};

#if GTK_SHORTCUTS_WINDOW
	private const ActionEntry[] shortcut_window_entries = {
		{"shortcuts", on_shortcuts_activated}
	};
#endif

	[GtkCallback]
	private void dash_button_clicked(Gtk.Button dash)
	{
		repository = null;
	}

	[GtkCallback]
	private void clone_repository_clicked()
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

	[GtkCallback]
	private void add_repository_clicked()
	{
		var chooser = new Gtk.FileChooserDialog(_("Add Repository"),
		                                        this,
		                                        Gtk.FileChooserAction.SELECT_FOLDER,
		                                        _("_Cancel"), Gtk.ResponseType.CANCEL,
		                                        _("_Add"), Gtk.ResponseType.OK);

		var scan_all = new Gtk.CheckButton.with_mnemonic(_("_Scan for all git repositories from this directory"));

		scan_all.halign = Gtk.Align.END;
		scan_all.hexpand = true;
		scan_all.show();

		chooser.extra_widget = scan_all;

		chooser.modal = true;
		chooser.set_default_response(Gtk.ResponseType.OK);

		chooser.response.connect((c, id) => {
			if (id == Gtk.ResponseType.OK)
			{
				var file = chooser.get_file();

				if (file == null)
				{
					file = chooser.get_current_folder_file();
				}

				d_dash_view.add_repository_from_location(file, scan_all.active);
			}

			c.destroy();
		});

		chooser.show();
	}

	[GtkCallback]
	private void search_button_toggled(Gtk.ToggleButton button)
	{
		var searchable = current_activity as GitgExt.Searchable;

		if (button.get_active())
		{
			d_search_entry.grab_focus_without_selecting();

			d_search_entry.text = searchable.search_text;
			searchable.search_visible = true;
			searchable.search_entry = d_search_entry;
		}
		else
		{
			searchable.search_visible = false;
			searchable.search_entry = null;
		}
	}

	[GtkCallback]
	private void search_entry_changed(Gtk.Editable entry)
	{
		var searchable = current_activity as GitgExt.Searchable;
		var ntext = (entry as Gtk.Entry).text;

		if (ntext != searchable.search_text)
		{
			searchable.search_text = ntext;
		}
	}

	[GtkCallback]
	public bool on_key_pressed (Gtk.Widget widget, Gdk.EventKey event) {
		bool ret = d_search_bar.handle_event(event);
		if (ret) {
			d_search_bar.search_mode_enabled = true;
		}
		return ret;
	}

	construct
	{
		if (Gitg.PlatformSupport.use_native_window_controls())
		{
			set_titlebar(null);
			d_grid_top.attach(d_header_bar, 0, 0, 1, 1);
		}
		else
		{
			d_header_bar.show_close_button = true;
			d_header_bar.get_style_context().add_class("titlebar");
		}

		add_action_entries(win_entries, this);

#if GTK_SHORTCUTS_WINDOW
		add_action_entries(shortcut_window_entries, this);
#endif

		d_notifications = new Notifications(d_overlay);

		var selact = lookup_action("select");

		selact.notify["state"].connect(() => {
			var st = selact.get_state().get_boolean();

			if (st)
			{
				selectable_mode = GitgExt.SelectionMode.SELECTION;
			}
			else
			{
				selectable_mode = GitgExt.SelectionMode.NORMAL;
			}
		});

		d_interface_settings = new Settings(Gitg.Config.APPLICATION_ID + ".preferences.interface");

		d_dash_model = Builder.load_object<MenuModel>("ui/gitg-menus.ui", "win-menu-dash");

		d_dash_view.application = this;

		d_activities_model = Builder.load_object<MenuModel>("ui/gitg-menus.ui", "win-menu-views");

		// search bar
		d_search_bar.connect_entry(d_search_entry);
		d_search_button.bind_property("active",
		                              d_search_bar,
		                              "search-mode-enabled",
		                              BindingFlags.BIDIRECTIONAL);

		d_activities_switcher.set_stack(d_stack_activities);

		d_environment = new Gee.HashMap<string, string>();

		foreach (var e in Environment.list_variables())
		{
			d_environment[e] = Environment.get_variable(e);
		}

		if (Gtk.check_version(3, 13, 2) != null &&
		    get_direction () == Gtk.TextDirection.RTL)
		{
			dash_image.icon_name = "go-previous-rtl-symbolic";
		}

		d_header_bar.remove(d_activities_switcher);
		d_header_bar.remove(d_search_button);
		d_header_bar.remove(d_select_button);
		d_header_bar.remove(d_gear_menu);

		d_header_bar.pack_end(d_gear_menu);
		d_header_bar.pack_end(d_activities_switcher);
		d_header_bar.pack_end(d_select_button);
		d_header_bar.pack_end(d_search_button);

		d_infobar.response.connect((w, r) => {
			d_infobar.hide();
		});

		unowned Gtk.BindingSet bset = Gtk.BindingSet.by_class(get_class());

		for (int i = 0; i < 10; i++)
		{
			Gtk.BindingEntry.add_signal(bset,
			                            (Gdk.Key.@0 + i),
			                            Gdk.ModifierType.MOD1_MASK,
			                            "change-to-activity",
			                            1,
			                            typeof(int),
			                            i);
		}

		Gtk.BindingEntry.add_signal(bset,
		                            Gdk.Key.Escape,
		                            0,
		                            "cancel",
		                            0);

		d_interface_settings.bind("enable-monitoring",
		                          this,
		                          "enable-monitoring",
		                          SettingsBindFlags.GET | SettingsBindFlags.SET);
	}

	protected override void style_updated()
	{
		base.style_updated();

		var dark = new Theme().is_theme_dark();

		if (dark)
		{
			get_style_context().add_class("dark");
		}
		else
		{
			get_style_context().remove_class("dark");
		}
	}

	protected override bool delete_event(Gdk.EventAny event)
	{
		var ret = false;

		if (base.delete_event != null)
		{
			ret = base.delete_event(event);
		}

		if (!ret)
		{
			repository = null;
		}

		return ret;
	}

	private void on_close_activated()
	{
		close();
	}

	private void on_search_activated(SimpleAction action)
	{
		if (d_search_button.visible)
		{
			var state = action.get_state().get_boolean();
			action.set_state(new Variant.boolean(!state));
		}
	}

	private void on_gear_menu_activated(SimpleAction action)
	{
		var state = action.get_state().get_boolean();

		action.set_state(new Variant.boolean(!state));
	}

	public GitgExt.Activity? current_activity
	{
		owned get
		{
			if (d_mode == Mode.ACTIVITY)
			{
				return d_activities.current;
			}
			else
			{
				return d_dash_view;
			}
		}
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
			set_repository_internal(value);
			repository_changed();
		}
	}

	public GitgExt.Application open_new(Ggit.Repository repository, string? hint = null)
	{
		var window = Window.create_new(application, (Gitg.Repository)repository, hint);
		base.present();

		return window;
	}

	private void update_title()
	{
		string windowtitle = "gitg";
		string title;
		string? subtitle = null;

		if (d_repository != null)
		{
			File? workdir = d_repository.get_workdir();

			if (workdir != null)
			{
				var parent_path = Utils.replace_home_dir_with_tilde(workdir.get_parent());

				title = @"$(d_repository.name) ($parent_path)";
				windowtitle = @"$(d_repository.name) - gitg";
			}
			else
			{
				title = d_repository.name;
			}

			string? head_name = null;

			try
			{
				var head = repository.get_head();
				head_name = head.parsed_name.shortname;
			}
			catch {}

			if (head_name != null)
			{
				subtitle = Markup.escape_text(head_name);
			}
		}
		else
		{
			title = _("Projects");
		}

		if (Gitg.PlatformSupport.use_native_window_controls())
		{
			d_header_bar.set_title(subtitle);
			this.title = title;
		}
		else
		{
			this.title = windowtitle;
			d_header_bar.set_title(title);
			d_header_bar.set_subtitle(subtitle);
		}
	}

	private void repository_changed()
	{
		update_title();
		d_infobar.hide();

		if (d_repository != null)
		{
			d_mode = Mode.ACTIVITY;

			d_main_stack.transition_type = Gtk.StackTransitionType.SLIDE_LEFT;
			d_main_stack.set_visible_child(d_stack_activities);
			d_activities_switcher.show();
			d_dash_button.show();
			d_clone_button.hide();
			d_add_button.hide();
			d_dash_view.add_repository(d_repository);

			d_gear_menu.menu_model = d_activities_model;
			gear_image.set_from_icon_name ("view-more-symbolic", BUTTON);
			d_gear_menu.show();
			d_gear_menu.sensitive = true;
		}
		else
		{
			d_mode = Mode.DASH;

			d_main_stack.transition_type = Gtk.StackTransitionType.SLIDE_RIGHT;
			d_main_stack.set_visible_child(d_dash_view);
			d_activities_switcher.hide();
			d_dash_button.hide();
			d_clone_button.show();
			d_add_button.show();

			d_gear_menu.menu_model = d_dash_model;
			gear_image.set_from_icon_name ("open-menu-symbolic", BUTTON);
			d_gear_menu.visible = d_dash_model != null;
			d_gear_menu.sensitive = d_dash_model != null;
		}

		d_activities.update();

		if (d_repository != null)
		{
			activate_default_activity();
		}

		if (d_mode == Mode.DASH)
		{
			on_current_activity_changed();
		}
	}

	protected override void realize() {
		if (Environment.get_variable("GITG_GTK_DEBUG_INTERACTIVE") != null) {
			Timeout.add_seconds(1, () => {
				Gtk.Window.set_interactive_debugging(true);
				return false;
			});
		}

		base.realize();
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

	private GitgExt.ExternalChangeHint external_change_hint_from_file(File location)
	{
		var l = d_repository.get_location();

		var refs = l.get_child("refs");
		var index = l.get_child("index");
		var head = l.get_child("HEAD");

		if (location.equal(refs) || location.has_prefix(refs) || location.equal(head))
		{
			return GitgExt.ExternalChangeHint.REFS;
		}
		else if (location.equal(index))
		{
			return GitgExt.ExternalChangeHint.INDEX;
		}
		else
		{
			return GitgExt.ExternalChangeHint.NONE;
		}

	}

	private bool filter_repository_changes(File location)
	{
		return external_change_hint_from_file(location) != GitgExt.ExternalChangeHint.NONE;
	}

	private void set_repository_internal(Repository? repository)
	{
		if (d_repository_monitor != null)
		{
			d_repository_monitor.cancel();
			d_repository_monitor = null;
		}

		d_repository = repository;

		if (d_repository != null)
		{
			update_enable_monitoring();
		}

		d_remote_manager = new RemoteManager(this);
		notify_property("repository");
	}

	private bool d_enable_monitoring;

	public bool enable_monitoring
	{
		get
		{
			return d_enable_monitoring;
		}

		set
		{
			d_enable_monitoring = value;
			update_enable_monitoring();
		}
	}

	private void update_enable_monitoring()
	{
		if (d_repository_monitor != null)
		{
			d_repository_monitor.cancel();
			d_repository_monitor = null;
		}

		if (enable_monitoring && d_repository != null)
		{
			d_repository_monitor = new RecursiveMonitor(d_repository.get_location(), filter_repository_changes);
			d_repository_monitor.changed.connect((files) => {
				var hint = GitgExt.ExternalChangeHint.NONE;

				foreach (var f in files)
				{
					hint |= external_change_hint_from_file(f);
				}

				repository_changed_externally(hint);
			});
		}
	}

	private void on_reload_activated()
	{
		try
		{
			set_repository_internal(new Gitg.Repository(this.repository.get_location(), null));
			update_title();
		}
		catch {}
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

	private void on_preferences_activated()
	{
		unowned List<Gtk.Window> wnds = application.get_windows();

		// Create preferences dialog if needed
		if (d_preferences == null)
		{
			d_preferences = Builder.load_object<PreferencesDialog>("ui/gitg-preferences.ui", "preferences");

			d_preferences.destroy.connect((w) => {
				d_preferences = null;
			});
		}

		if (wnds != null)
		{
			d_preferences.set_transient_for(wnds.data);
		}

		d_preferences.present();
	}

	private void on_shortcuts_activated()
	{
#if GTK_SHORTCUTS_WINDOW

		unowned List<Gtk.Window> wnds = application.get_windows();

		// Create shortcuts window if needed
		if (d_shortcuts == null)
		{
			d_shortcuts = Builder.load_object<Gtk.ShortcutsWindow>("ui/gitg-shortcuts.ui", "shortcuts-gitg");

			d_shortcuts.destroy.connect((w) => {
				d_shortcuts = null;
			});
		}

		if (wnds != null)
		{
			d_shortcuts.set_transient_for(wnds.data);
		}

		d_shortcuts.present();
#endif
	}

	private void on_current_activity_changed()
	{
		notify_property("current_activity");

		var current = current_activity;

		var searchable = current as GitgExt.Searchable;

		d_searchable_available_binding = null;

		if (searchable != null)
		{
			d_search_button.visible = true;
			d_search_entry.text = searchable.search_text;
			d_search_button.active = searchable.search_visible;

			d_searchable_available_binding = searchable.bind_property("search-available",
			                                                          d_search_button,
			                                                          "sensitive",
			                                                          BindingFlags.DEFAULT |
			                                                          BindingFlags.SYNC_CREATE);
		}
		else
		{
			d_search_button.visible = false;
			d_search_button.active = false;
			d_search_button.sensitive = false;
			d_search_entry.text = "";
		}

		var selectable = (current as GitgExt.Selectable);

		d_selectable_mode_binding = null;
		d_selectable_available_binding = null;

		if (selectable != null)
		{
			d_select_button.visible = true;

			var tooltip = selectable.selectable_mode_tooltip;

			if (tooltip == null)
			{
				tooltip = _("Select items");
			}

			d_select_button.tooltip_text = tooltip;

			d_selectable_mode_binding = selectable.bind_property("selectable-mode",
			                                                     this,
			                                                     "selectable-mode",
			                                                     BindingFlags.DEFAULT);

			d_selectable_available_binding = selectable.bind_property("selectable-available",
			                                                         d_select_button,
			                                                         "sensitive",
			                                                         BindingFlags.DEFAULT |
			                                                         BindingFlags.SYNC_CREATE);
		}
		else
		{
			d_select_button.visible = false;
			d_select_button.active = false;
			d_select_button.sensitive = false;
		}
	}

	private bool activate_activity(string? action)
	{
		string default_activity;

		if (action == null || action == "")
		{
			default_activity = d_interface_settings.get_string("default-activity");
		}
		else
		{
			default_activity = action;
		}

		GitgExt.Activity? def = null;

		d_activities.foreach((element) => {
			GitgExt.Activity activity = (GitgExt.Activity)element;

			if (activity.is_default_for(default_activity))
			{
				def = activity;
			}

			return true;
		});

		if (def != null)
		{
			d_activities.current = def;
			return true;
		}

		return false;
	}

	private void activate_default_activity()
	{
		if (!activate_activity(d_action))
		{
			d_activities.foreach((element) => {
				GitgExt.Activity activity = (GitgExt.Activity)element;

				if (activity.is_default_for(""))
				{
					d_activities.current = activity;
					return false;
				}

				return true;
			});
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
		if(Gitg.Config.PROFILE == "development")
		{
			this.get_style_context().add_class("devel");
		}

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
			ret.set_repository_internal(repository);
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
	public GitgExt.Activity? set_activity_by_id(string id)
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

	public GitgExt.Activity? get_activity_by_id(string id)
	{
		return d_activities.lookup(id);
	}

	public void open_repository(File path)
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

			var title = _("“%s” is not a Git repository.").printf(repo_name);
			show_infobar(title, e.message, Gtk.MessageType.WARNING);

			return;
		}

		try
		{
			repository = new Gitg.Repository(repo, null);
		}
		catch {}

		this.repository = repository;
	}

	public void show_infobar(string          title,
	                         string          message,
	                         Gtk.MessageType type)
	{
		Idle.add(() => {
			var primary = "<b>%s</b>".printf(Markup.escape_text(title));
			var secondary = "<small>%s</small>".printf(Markup.escape_text(message));

			d_infobar_primary_label.set_label(primary);
			d_infobar_secondary_label.set_label(secondary);
			d_infobar.message_type = type;

			d_infobar.show();
			return false;
		});
	}

	public async Gtk.ResponseType user_query_async(GitgExt.UserQuery query)
	{
		SourceFunc cb = user_query_async.callback;
		Gtk.ResponseType retval = 0;

		query.response.connect((response) => {
			retval = response;

			Idle.add((owned)cb);
			return true;
		});

		user_query(query);

		yield;

		return retval;
	}

	public void user_query(GitgExt.UserQuery query)
	{
		var dlg = new Gtk.MessageDialog(this,
		                                Gtk.DialogFlags.MODAL,
		                                query.message_type,
		                                Gtk.ButtonsType.NONE,
		                                "");

		var primary = "<b>%s</b>".printf(Markup.escape_text(query.title));
		dlg.set_markup(primary);

		dlg.format_secondary_text("%s", query.message);

		if (query.message_use_markup)
		{
			dlg.secondary_use_markup = true;
		}

		dlg.set_default_response(query.default_response);

		foreach (var response in query.get_responses())
		{
			var button = dlg.add_button(response.text, response.response_type);

			if (response.response_type == query.default_response)
			{
				button.can_default = true;
				button.has_default = true;

				if (query.default_is_destructive)
				{
					button.get_style_context().add_class(Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
				}
				else
				{
					button.get_style_context().add_class(Gtk.STYLE_CLASS_SUGGESTED_ACTION);
				}
			}
		}

		d_dialog = dlg;
		dlg.add_weak_pointer(&d_dialog);

		ulong qid = 0;

		qid = query.quit.connect(() => {
			dlg.destroy();
			query.disconnect(qid);
		});

		dlg.response.connect((w, r) => {
			dlg.sensitive = false;

			if (query.response((Gtk.ResponseType)r))
			{
				dlg.destroy();
				query.disconnect(qid);
			}
		});

		dlg.show();
	}

	public Gee.Map<string, string> environment
	{
		owned get { return d_environment; }
	}

	public Ggit.Signature? get_verified_committer()
	{
		string? user = null;
		string? email = null;
		Ggit.Signature? committer = null;

		try
		{
			committer = repository.get_signature_with_environment(environment, "COMMITTER");

			user = committer.get_name();
			email = committer.get_email();

			if (user == "")
			{
				user = null;
			}

			if (email == "")
			{
				email = null;
			}
		} catch {}

		if (user == null || email == null)
		{
			string secmsg;

			if (user == null && email == null)
			{
				secmsg = _("Your user name and email are not configured yet. Please go to the user configuration and provide your name and email.");
			}
			else if (user == null)
			{
				secmsg = _("Your user name is not configured yet. Please go to the user configuration and provide your name.");
			}
			else
			{
				secmsg = _("Your email is not configured yet. Please go to the user configuration and provide your email.");
			}

			show_infobar(_("Missing author details"), secmsg, Gtk.MessageType.ERROR);
			return null;
		}

		return committer;
	}

	public bool busy
	{
		get { return d_busy; }
		set
		{
			d_busy = value;

			Gdk.Window win;

			if (d_dialog != null)
			{
				win = d_dialog.get_window();
			}
			else
			{
				win = get_window();
			}

			if (d_busy)
			{
				win.set_cursor(new Gdk.Cursor.for_display(get_display(),
				                                          Gdk.CursorType.WATCH));
			}
			else
			{
				win.set_cursor(null);
			}
		}
	}

	public new void present(string? hint, GitgExt.CommandLines? command_lines)
	{
		if (hint != null)
		{
			activate_activity(hint);
		}

		if (command_lines != null)
		{
			command_lines.apply(this);
		}

		base.present();
	}

	private void on_select_activated(SimpleAction action)
	{
		var st = action.get_state().get_boolean();
		action.set_state(new Variant.boolean(!st));
	}

	public GitgExt.SelectionMode selectable_mode
	{
		get { return d_selectable_mode; }
		set
		{
			var selectable = current_activity as GitgExt.Selectable;

			if (selectable == null || d_selectable_mode == value)
			{
				return;
			}

			d_selectable_mode = value;
			selectable.selectable_mode = value;

			var ctx = d_header_bar.get_style_context();

			if (d_selectable_mode == GitgExt.SelectionMode.SELECTION)
			{
				ctx.add_class("selection-mode");

				d_select_actions = selectable.action_widget;

				if (d_select_actions != null)
				{
					d_grid_main.attach(d_select_actions, 0, 3, 1, 1);
					d_select_actions.show();
				}
			}
			else
			{
				ctx.remove_class("selection-mode");

				if (d_select_actions != null)
				{
					d_select_actions.destroy();
					d_select_actions = null;
				}
			}

			var issel = (d_selectable_mode == GitgExt.SelectionMode.SELECTION);
			var searchable = current_activity as GitgExt.Searchable;

			d_header_bar.show_close_button = !Gitg.PlatformSupport.use_native_window_controls() && !issel;
			d_search_button.visible = !issel && searchable != null;
			d_gear_menu.visible = !issel && d_repository != null;
			d_select_button.visible = !issel;
			d_dash_button.visible = !issel && d_repository != null;
			d_clone_button.visible = !issel && d_repository == null;
			d_add_button.visible = !issel && d_repository == null;
			d_activities_switcher.visible = !issel && d_repository != null;
			d_select_cancel_button.visible = issel;

			d_select_button.active = issel;
		}
	}

	[GtkCallback]
	private void on_select_cancel_button_clicked()
	{
		selectable_mode = GitgExt.SelectionMode.NORMAL;
	}

	[Signal(action = true)]
	public virtual signal void cancel()
	{
		if (d_infobar.visible)
		{
			d_infobar.hide();
		}
		else
		{
			selectable_mode = GitgExt.SelectionMode.NORMAL;
		}
	}

	public GitgExt.RemoteLookup remote_lookup
	{
		owned get { return d_remote_manager; }
	}

	public GitgExt.Notifications notifications
	{
		owned get { return d_notifications; }
	}
}

}

// ex:ts=4 noet
