name = gitg_name + '-ext'
api_name = '@0@-@1@'.format(name, gitg_api_version)

lib_name = 'lib' + name
lib_api_name = 'lib' + api_name

gir_ns = 'GitgExt'
gir_api_name = '@0@-@1@'.format(gir_ns, gitg_gir_version)
gir_name = gir_api_name + '.gir'
gir_typelib = gir_api_name + '.typelib'

sources = files(
  'gitg-ext-action.vala',
  'gitg-ext-activity.vala',
  'gitg-ext-application.vala',
  'gitg-ext-assembly-info.vala',
  'gitg-ext-command-line.vala',
  'gitg-ext-command-lines.vala',
  'gitg-ext-commit-action.vala',
  'gitg-ext-history-panel.vala',
  'gitg-ext-history.vala',
  'gitg-ext-message-bus.vala',
  'gitg-ext-message-id.vala',
  'gitg-ext-message.vala',
  'gitg-ext-notification.vala',
  'gitg-ext-notifications.vala',
  'gitg-ext-preferences.vala',
  'gitg-ext-ref-action-interface.vala',
  'gitg-ext-ref-action.vala',
  'gitg-ext-remote-lookup.vala',
  'gitg-ext-searchable.vala',
  'gitg-ext-selectable.vala',
  'gitg-ext-ui-element.vala',
  'gitg-ext-ui.vala',
  'gitg-ext-user-query.vala'
)

deps = [
  gee_dep,
  gtk_dep,
  libgit2_glib_dep,
  libgitg_dep
]

cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DLIBDIR="@0@"'.format(gitg_libdir)
]

ldflags = []

if have_version_script
  ldflags += '-Wl,--version-script,' + symbol_map
endif

libgitg_ext = shared_library(
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

libgitg_ext_dep = declare_dependency(
  link_with: libgitg_ext,
  include_directories: include_directories('.')
)

pkg.generate(
  libraries: libgitg_ext,
  version: gitg_version,
  name: lib_name,
  description: gitg_name + ' extensions library',
  filebase: lib_api_name,
  subdirs: lib_api_name,
  requires: [
    'gio-2.0',
    'glib-2.0',
    'gmodule-2.0',
    'gobject-2.0',
    'gtk+-3.0',
    'gthread-2.0',
    'libgit2-glib-1.0',
    'libgitg-1.0',
    gio_system_pkg
  ],
  variables: 'exec_prefix=' + gitg_prefix,
  install_dir: join_paths(gitg_libdir, 'pkgconfig')
)

# FIXME: does not work due to missing proper valadoc support
if enable_docs
  vala_pkgs = [
    '--pkg', 'ggit-1.0',
    '--pkg', 'gio-2.0',
    '--pkg', 'gtk+-3.0',
    '--pkg', 'libsoup-2.4',
    '--pkg', 'gee-0.8'
  ]

  valaproc_cmd = [
    valadoc,
    '--directory', join_paths(meson.source_root(), 'docs'),
    '--package-name', 'gitgext',
    vala_pkgs,
    '--basedir', meson.source_root(),
    '--vapidir', join_paths(meson.build_root(), 'gitg'),
    sources
  ]

  run_target(
    'libgitg-ext-docs',
    command: valaproc_cmd
  )
endif

custom_target(
  gir_typelib,
  output: gir_typelib,
  command: [g_ir_compiler, '--shared-library', libgitg_ext.full_path(), '--includedir', libgitg_dir, '--output', '@OUTPUT@', join_paths(meson.current_build_dir(), gir_name)],
  depends: [
    libgitg,
    libgitg_ext
  ],
  install: true,
  install_dir: gitg_girepositorydir
)

enable_python = get_option('python')
if enable_python
  python = import('python3')

  install_data(
    'GitgExt.py',
    install_dir: join_paths(python.sysconfig_path('purelib'), 'gi', 'overrides')
  )
endif
