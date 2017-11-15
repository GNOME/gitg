name = gitg_name
api_name = '@0@-@1@'.format(name, gitg_api_version)

lib_name = 'lib' + name
lib_api_name = 'lib' + api_name

gir_ns = 'Gitg'
gir_api_name = '@0@-@1@'.format(gir_ns, gitg_gir_version)
gir_name = gir_api_name + '.gir'
gir_typelib = gir_api_name + '.typelib'

sources = files(
  'gitg-assembly-info.vala',
  'gitg-async.vala',
  'gitg-authentication-dialog.vala',
  'gitg-avatar-cache.vala',
  'gitg-branch-base.vala',
  'gitg-branch.vala',
  'gitg-cell-renderer-lanes.vala',
  'gitg-color.vala',
  'gitg-commit-list-view.vala',
  'gitg-commit-model.vala',
  'gitg-commit.vala',
  'gitg-credentials-manager.vala',
  'gitg-date.vala',
  'gitg-diff-image-composite.vala',
  'gitg-diff-image-difference.vala',
  'gitg-diff-image-overlay.vala',
  'gitg-diff-image-side-by-side.vala',
  'gitg-diff-image-slider.vala',
  'gitg-diff-image-surface-cache.vala',
  'gitg-diff-selectable.vala',
  'gitg-diff-stat.vala',
  'gitg-diff-view-commit-details.vala',
  'gitg-diff-view-file-info.vala',
  'gitg-diff-view-file-renderer-binary.vala',
  'gitg-diff-view-file-renderer-image.vala',
  'gitg-diff-view-file-renderer-text.vala',
  'gitg-diff-view-file-renderer.vala',
  'gitg-diff-view-file-selectable.vala',
  'gitg-diff-view-file.vala',
  'gitg-diff-view-lines-renderer.vala',
  'gitg-diff-view-options.vala',
  'gitg-diff-view.vala',
  'gitg-hook.vala',
  'gitg-init.vala',
  'gitg-label-renderer.vala',
  'gitg-lanes.vala',
  'gitg-lane.vala',
  'gitg-progress-bin.vala',
  'gitg-ref-base.vala',
  'gitg-ref.vala',
  'gitg-remote.vala',
  'gitg-repository-list-box.vala',
  'gitg-repository.vala',
  'gitg-resource.vala',
  'gitg-sidebar.vala',
  'gitg-stage-status-enumerator.vala',
  'gitg-stage.vala',
  'gitg-utils.vala',
  'gitg-when-mapped.vala'
)

resource_data = files(
  'resources/ui/gitg-authentication-dialog.ui',
  'resources/ui/gitg-diff-view-commit-details.ui',
  'resources/ui/gitg-diff-view-file-renderer-binary.ui',
  'resources/ui/gitg-diff-view-file-renderer-image.ui',
  'resources/ui/gitg-diff-view-file-renderer-text.ui',
  'resources/ui/gitg-diff-view-file.ui',
  'resources/ui/gitg-diff-view-options-spacing.ui',
  'resources/ui/gitg-diff-view-options.ui',
  'resources/ui/gitg-diff-view.ui',
  'resources/ui/gitg-repository-list-box-row.ui',
  'resources/ui/gitg-sidebar.ui',
  'resources/ui/libgitg-style.css'
)

sources += gnome.compile_resources(
  'libgitg-resources',
  'resources/resources.xml',
  source_dir: 'resources',
  dependencies: resource_data
)

deps = [
  gee_dep,
  gitg_platform_support_dep,
  glib_dep,
  gtk_dep,
  gtksourceview_dep,
  libgit2_glib_dep,
  libide_dep,
  libsoup_dep,
  m_dep,
  dependency('gsettings-desktop-schemas'),
  dependency('libsecret-1')
]

cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DLIBDIR="@0@"'.format(gitg_libdir),
  '-DGETTEXT_PACKAGE="@0@"'.format(gitg_gettext)
]

ldflags = []

if have_version_script
  ldflags += '-Wl,--version-script,' + symbol_map
endif

test_ldflags = []
if gdk_targets.contains('quartz')
  sources += files('gitg-platform-support-osx.c')
  gio_system_pkg = 'gio-unix-2.0'
  deps += [
    dependency(gio_system_pkg),
    find_library('objc')
  ]
  cflags += '-xobjective-c'

  test_ldflags += [
    '-framework Foundation',
    '-framework AppKit'
  ]
elif gdk_targets.contains('win32')
  sources += files('gitg-platform-support-win32.c')
  gio_system_pkg = 'gio-windows-2.0'
  deps += dependency(gio_system_pkg)
else
  sources += files('gitg-platform-support.c')
  gio_system_pkg = 'gio-unix-2.0'
  deps += dependency(gio_system_pkg)
endif

foreach test_ldflag: test_ldflags
  if cc.has_argument(test_ldflag)
    ldflags += test_ldflag
  endif
endforeach

libgitg = shared_library(
  api_name,
  sources: sources,
  version: libversion,
  soversion: soversion,
  include_directories: top_inc,
  dependencies: deps,
  c_args: cflags,
  vala_header: lib_name + '.h',
  vala_vapi: lib_api_name + '.vapi',
  vala_gir: gir_name,
  link_args: ldflags,
  link_depends: symbol_map,
  install: true,
  install_dir: [
    get_option('libdir'),
    join_paths(gitg_includedir, lib_api_name, lib_name),
    true,
    true
  ]
)

libgitg_dep = declare_dependency(
  link_with: libgitg,
  include_directories: include_directories('.')
)

pkg.generate(
  libraries: libgitg,
  version: gitg_version,
  name: gitg_name,
  description: gitg_name + ' library',
  filebase: lib_api_name,
  subdirs: lib_api_name,
  requires: [
    'gio-2.0',
    'glib-2.0',
    'gmodule-2.0',
    'gobject-2.0',
    'gthread-2.0',
    'gtk+-3.0',
    'libgit2-glib-1.0',
    gio_system_pkg
  ],
  variables: 'exec_prefix=' + gitg_prefix,
  install_dir: join_paths(gitg_libdir, 'pkgconfig')
)

libgitg_dir = meson.current_build_dir()

custom_target(
  gir_typelib,
  output: gir_typelib,
  command: [g_ir_compiler, '--shared-library', libgitg.full_path(), '--output', '@OUTPUT@', join_paths(libgitg_dir, gir_name)],
  depends: libgitg,
  install: true,
  install_dir: gitg_girepositorydir
)
