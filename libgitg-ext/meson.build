libgitg_ext_api_name = 'libgitg-ext-' + gitg_api_version
libgitg_ext_gir_api_name = 'GitgExt-' + gitg_api_version

libgitg_ext_vapi_name = libgitg_ext_api_name + '.vapi'
libgitg_ext_gir_name = libgitg_ext_gir_api_name + '.gir'
libgitg_ext_typelib_name = libgitg_ext_gir_api_name + '.typelib'

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
  'gitg-ext-user-query.vala',
)

cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DLIBDIR="@0@"'.format(gitg_libdir),
]

libgitg_ext = shared_library(
  'gitg-ext-' + gitg_api_version,
  sources: sources,
  version: libversion,
  soversion: soversion,
  include_directories: top_inc,
  dependencies: libgitg_dep,
  c_args: cflags,
  vala_header: 'libgitg-ext.h',
  vala_vapi: libgitg_ext_vapi_name,
  vala_gir: libgitg_ext_gir_name,
  link_args: common_ldflags,
  link_depends: symbol_map,
  install: true,
  install_dir: [
    true,
    join_paths(gitg_includedir, libgitg_ext_api_name, 'libgitg-ext'),
    true,
    true
  ]
)

deps = [
  gee_dep,
  gio_dep,
  glib_dep,
  gtk_dep,
  libgit2_glib_dep,
]

libgitg_ext_dep = declare_dependency(
  include_directories: include_directories('.'),
  dependencies: deps + [libgitg_dep],
  link_with: libgitg_ext,
)

pkg.generate(
  libraries: libgitg_ext,
  version: gitg_version,
  name: 'libgitg-ext',
  description: 'gitg extensions library',
  filebase: libgitg_ext_api_name,
  subdirs: libgitg_ext_api_name,
  requires: deps +  [libgitg_api_name],
  variables: 'exec_prefix=' + gitg_prefix,
)

# FIXME: does not work due to missing proper valadoc support
if get_option('docs')
  vala_pkgs = [
    '--pkg', 'ggit-1.0',
    '--pkg', 'gio-2.0',
    '--pkg', 'gtk+-3.0',
    '--pkg', 'gee-0.8',
  ]

  valaproc_cmd = [
    find_program('valadoc'),
    '--directory', join_paths(source_root, 'docs'),
    '--package-name', 'gitgext',
    vala_pkgs,
    '--basedir', source_root,
    '--vapidir', vapi_dir,
    '--vapidir', libgitg_dir,
    sources + [join_paths(libgitg_build_dir, libgitg_vapi_name)],
  ]

  run_target(
    'libgitg-ext-docs',
    command: valaproc_cmd,
    depends: libgitg,
  )
endif

custom_target(
  libgitg_ext_typelib_name,
  output: libgitg_ext_typelib_name,
  command: [g_ir_compiler, '--shared-library', libgitg_ext_api_name, '--includedir', libgitg_build_dir, '--output', '@OUTPUT@', join_paths(meson.current_build_dir(), libgitg_ext_gir_name)],
  depends: [
    libgitg,
    libgitg_ext,
  ],
  install: true,
  install_dir: gitg_girepositorydir,
)

enable_python = get_option('python')
if enable_python
  python = import('python')
  purelib_path = python.find_installation().get_install_dir()

  install_data(
    'GitgExt.py',
    install_dir: join_paths(purelib_path, 'gi', 'overrides'),
  )
endif
