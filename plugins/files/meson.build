install_data(
  'files.plugin',
  install_dir: plugin_dir,
)

sources = files(
  'gitg-files.vala',
  'gitg-files-tree-store.vala',
)

resource_data = files('resources/view-files.ui')

sources += gnome.compile_resources(
  'gitg-files-resources',
  'resources/resources.xml',
  source_dir: 'resources',
  dependencies: resource_data,
)

libfiles = shared_module(
  'files',
  sources: sources,
  include_directories: top_inc,
  dependencies: plugin_deps,
  c_args: plugin_cflags,
  install: true,
  install_dir: plugin_dir,
  name_suffix: module_suffix,
)
