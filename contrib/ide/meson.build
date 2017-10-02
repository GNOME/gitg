sources = files(
  'ide-doap.c',
  'ide-doap-person.c'
)

libide = static_library(
  'ide',
  sources: sources,
  include_directories: top_inc,
  dependencies: libxml_dep
)

libide_dep = declare_dependency(
  link_with: libide,
  include_directories: include_directories('.'),
  dependencies: valac.find_library('ide', dirs: meson.current_source_dir())
)
