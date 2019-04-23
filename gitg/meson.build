gitg_sources = files(
  'gitg-action-support.vala',
  'gitg-commit-action-cherry-pick.vala',
  'gitg-ref-action-checkout.vala',
  'gitg-ref-action-merge.vala',
)

sources = gitg_sources + files(
  'commit/gitg-commit-dialog.vala',
  'commit/gitg-commit-paned.vala',
  'commit/gitg-commit-sidebar.vala',
  'commit/gitg-commit-submodule-diff-view.vala',
  'commit/gitg-commit-submodule-history-view.vala',
  'commit/gitg-commit-submodule-info.vala',
  'commit/gitg-commit.vala',
  'history/gitg-history-action-interface.vala',
  'history/gitg-history-command-line.vala',
  'history/gitg-history-paned.vala',
  'history/gitg-history-refs-list.vala',
  'history/gitg-history.vala',
  'preferences/gitg-preferences-commit.vala',
  'preferences/gitg-preferences-dialog.vala',
  'preferences/gitg-preferences-history.vala',
  'preferences/gitg-preferences-interface.vala',
  'gitg-animated-paned.vala',
  'gitg-application.vala',
  'gitg-author-details-dialog.vala',
  'gitg-builder.vala',
  'gitg-clone-dialog.vala',
  'gitg-commit-action-create-branch.vala',
  'gitg-commit-action-create-patch.vala',
  'gitg-commit-action-create-tag.vala',
  'gitg-convert.vala',
  'gitg-create-branch-dialog.vala',
  'gitg-create-tag-dialog.vala',
  'gitg-dash-view.vala',
  'gitg-dirs.vala',
  'gitg-notifications.vala',
  'gitg-plugins-engine.vala',
  'gitg-popup-menu.vala',
  'gitg-recursive-monitor.vala',
  'gitg-recursive-scanner.vala',
  'gitg-ref-action-copy-name.vala',
  'gitg-ref-action-delete.vala',
  'gitg-ref-action-fetch.vala',
  'gitg-ref-action-push.vala',
  'gitg-ref-action-rename.vala',
  'gitg-remote-manager.vala',
  'gitg-remote-notification.vala',
  'gitg-simple-notification.vala',
  'gitg-ui-elements.vala',
  'gitg-window.vala',
  'gitg.vala',
)

deps = [
  config_dep,
  gitg_platform_support_dep,
  gobject_introspection_dep,
  gtksourceview_dep,
  gtkspell_dep,
  libgitg_ext_dep,
  libpeas_dep,
  libdazzle_dep,
]

cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DGITG_DATADIR="@0@"'.format(gitg_pkgdatadir),
  '-DGITG_LOCALEDIR="@0@"'.format(gitg_localedir),
]

ldflags = common_ldflags

resources_conf = configuration_data()
resources_conf.set('PLATFORM_NAME', platform_name)

resources = 'gitg-resources.xml'

resources_in = configure_file(
  input: join_paths('resources', resources + '.in'),
  output: resources,
  configuration: resources_conf,
)

resource_data = files(
  'resources/ui/gitg-author-details-dialog.ui',
  'resources/ui/gitg-clone-dialog.ui',
  'resources/ui/gitg-commit-dialog.ui',
  'resources/ui/gitg-commit-paned.ui',
  'resources/ui/gitg-commit-submodule-diff-view.ui',
  'resources/ui/gitg-commit-submodule-history-view.ui',
  'resources/ui/gitg-commit-submodule-info.ui',
  'resources/ui/gitg-create-branch-dialog.ui',
  'resources/ui/gitg-create-tag-dialog.ui',
  'resources/ui/gitg-dash-view.ui',
  'resources/ui/gitg-history-paned.ui',
  'resources/ui/gitg-history-ref-header.ui',
  'resources/ui/gitg-history-ref-row.ui',
  'resources/ui/gitg-menus.ui',
  'resources/ui/gitg-preferences-commit.ui',
  'resources/ui/gitg-preferences-history.ui',
  'resources/ui/gitg-preferences-interface.ui',
  'resources/ui/gitg-preferences.ui',
  'resources/ui/gitg-remote-notification.ui',
  'resources/ui/gitg-shortcuts.ui',
  'resources/ui/gitg-simple-notification.ui',
  'resources/ui/gitg-window.ui',
  'resources/ui/style.css',
  'resources/ui/style-@0@.css'.format(platform_name),
)

sources += gnome.compile_resources(
  'gitg-resources',
  resources_in,
  source_dir: 'resources',
  dependencies: resource_data,
  export: true,
)

vala_flags = ['--gresourcesdir=' + join_paths(meson.current_source_dir(), 'resources')]

if gtk_shortcuts_window
  vala_flags += '--define=GTK_SHORTCUTS_WINDOW'
endif

if host_system == 'windows'
  sources += windows.compile_resources('gitg.rc')
endif

executable(
  gitg_name,
  sources: sources,
  include_directories: top_inc,
  dependencies: deps,
  c_args: cflags,
  vala_args: vala_flags,
  gui_app: true,
  install: true,
  install_rpath: gitg_libdir,
)
