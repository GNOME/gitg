common_deps = [
  gio_dep,
  glib_dep,
]

sources = files(
  'ide-doap.c',
  'ide-doap-person.c',
)

deps = common_deps + [libxml_reader_dep]

libide = static_library(
  'ide',
  sources: sources,
  include_directories: top_inc,
  dependencies: deps,
)

libide_dep = declare_dependency(
  include_directories: include_directories('.'),
  dependencies: common_deps + [valac.find_library('ide', dirs: meson.current_source_dir())],
  link_with: libide,
)
