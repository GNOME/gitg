libgitg_build_dir = meson.current_build_dir()

libgitg_api_name = 'libgitg-' + gitg_api_version
libgitg_gir_api_name = 'Gitg-' + gitg_api_version

libgitg_vapi_name = libgitg_api_name + '.vapi'
libgitg_gir_name = libgitg_gir_api_name + '.gir'
libgitg_typelib_name = libgitg_gir_api_name + '.typelib'

common_deps = [
  gee_dep,
  gio_dep,
  glib_dep,
  gtk_dep,
  libgit2_glib_dep,
  gpgme_dependency,
]

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
  'gitg-diff-view-file-renderer-textable.vala',
  'gitg-diff-view-file-renderer-text-split.vala',
  'gitg-diff-view-file-renderer.vala',
  'gitg-diff-view-file-selectable.vala',
  'gitg-diff-view-file.vala',
  'gitg-diff-view-lines-renderer.vala',
  'gitg-diff-view-options.vala',
  'gitg-diff-view.vala',
  'gitg-font-manager.vala',
  'gitg-gpg-utils.vala',
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
  'gitg-textconv.vala',
  'gitg-theme.vala',
  'gitg-utils.vala',
  'gitg-when-mapped.vala',
)

resource_data = files(
  'resources/ui/gitg-authentication-dialog.ui',
  'resources/ui/gitg-diff-view-commit-details.ui',
  'resources/ui/gitg-diff-view-file-renderer-binary.ui',
  'resources/ui/gitg-diff-view-file-renderer-image.ui',
  'resources/ui/gitg-diff-view-file-renderer-text.ui',
  'resources/ui/gitg-diff-view-file-renderer-text-split.ui',
  'resources/ui/gitg-diff-view-file.ui',
  'resources/ui/gitg-diff-view-options-spacing.ui',
  'resources/ui/gitg-diff-view-options.ui',
  'resources/ui/gitg-diff-view.ui',
  'resources/ui/gitg-repository-list-box-row.ui',
  'resources/ui/gitg-sidebar.ui',
  'resources/ui/libgitg-style.css',
)

sources += gnome.compile_resources(
  'libgitg-resources',
  'resources/resources.xml',
  source_dir: 'resources',
  dependencies: resource_data,
)

deps = common_deps + [
  config_dep,
  gitg_platform_support_dep,
  gsettings_desktop_schemas_dep,
  gtksourceview_dep,
  libide_dep,
  libsecret_dep,
  m_dep,
]

cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DLIBDIR="@0@"'.format(gitg_libdir),
  '-DGETTEXT_PACKAGE="@0@"'.format(gitg_gettext),
]

ldflags = common_ldflags

if gdk_targets.contains('quartz')
  sources += files('gitg-platform-support-osx.c')
  deps += [
    dependency('gio-unix-2.0'),
    dependency('appleframeworks', modules : ['Foundation', 'AppKit'])
  ]
  cflags += '-xobjective-c'
elif gdk_targets.contains('win32')
  sources += files('gitg-platform-support-win32.c')
  deps += dependency('gio-windows-2.0')
else
  sources += files('gitg-platform-support.c')
  deps += dependency('gio-unix-2.0')
endif

libgitg = shared_library(
  'gitg-' + gitg_api_version,
  sources: sources,
  version: libversion,
  soversion: soversion,
  include_directories: top_inc,
  dependencies: deps,
  c_args: cflags,
  vala_header: 'libgitg.h',
  vala_vapi: libgitg_vapi_name,
  vala_gir: libgitg_gir_name,
  link_args: ldflags,
  link_depends: symbol_map,
  install: true,
  install_dir: [
    true,
    join_paths(gitg_includedir, libgitg_api_name, 'libgitg'),
    true,
    true
  ]
)

libgitg_dep = declare_dependency(
  include_directories: include_directories('.'),
  dependencies: common_deps + [m_dep],
  link_with: libgitg,
)

# FIXME: libgitg_dep requires m_dep because math.h and float.h includes are exposed
#        However, meson is not able to append it
pkg.generate(
  libraries: libgitg,
  version: gitg_version,
  name: 'gitg',
  description: 'gitg library',
  filebase: libgitg_api_name,
  subdirs: libgitg_api_name,
  requires: common_deps,
  variables: 'exec_prefix=' + gitg_prefix,
)

custom_target(
  libgitg_typelib_name,
  output: libgitg_typelib_name,
  command: [g_ir_compiler, '--shared-library', libgitg_api_name, '--output', '@OUTPUT@', join_paths(libgitg_build_dir, libgitg_gir_name)],
  depends: libgitg,
  install: true,
  install_dir: gitg_girepositorydir,
)
