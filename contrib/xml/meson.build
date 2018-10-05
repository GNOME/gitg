sources = files('xml-reader.c')

deps = [
  gio_dep,
  libxml_dep,
]

libxml_reader = static_library(
  'xml',
  sources: sources,
  include_directories: top_inc,
  dependencies: deps,
)

libxml_reader_dep = declare_dependency(
  include_directories: include_directories('.'),
  dependencies: deps,
  link_with: libxml_reader,
)
