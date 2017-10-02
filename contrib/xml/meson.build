sources = files('xml-reader.c')

deps = [
  gio_dep,
  dependency('libxml-2.0', version: '>= 2.9.0')
]

libxml = static_library(
  'xml',
  sources: sources,
  include_directories: top_inc,
  dependencies: deps
)

libxml_dep = declare_dependency(
  link_with: libxml,
  include_directories: include_directories('.'),
  dependencies: deps
)
