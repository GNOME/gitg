copygen = generator(
  find_program('cp'),
  arguments: ['@INPUT@', '@OUTPUT@'],
  output: 'support-@PLAINNAME@',
)

sources = [
  'main.vala',
  'repository.vala',
  'test.vala',
]

support_sources = []

foreach source: sources
  support_sources += copygen.process(source)
endforeach

gitg_assert_dep = declare_dependency(
  include_directories: include_directories('.'),
  dependencies: valac.find_library('gitg-assert', dirs: meson.current_source_dir()),
)
