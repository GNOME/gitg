install_data(
  'icons/diff-symbolic.svg',
  install_dir: join_paths(gitg_pkgdatadir, 'icons', 'hicolor', 'scalable', 'actions'),
)

install_data(
  'diff.plugin',
  install_dir: plugin_dir,
)

sources = files('gitg-diff.vala')

libdiff = shared_module(
  'diff',
  sources: sources,
  include_directories: top_inc,
  dependencies: plugin_deps,
  c_args: plugin_cflags,
  install: true,
  install_dir: plugin_dir,
  name_suffix: module_suffix,
)
