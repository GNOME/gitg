sources = support_sources + files(
  'main.vala',
  'test-commit.vala',
  'test-date.vala',
  'test-encoding.vala',
  'test-stage.vala',
)

deps = [
  gitg_assert_dep,
  libgitg_dep,
]

vala_flags = '--disable-warnings'

test_unit = 'tests-libgitg'

exe = executable(
  test_unit,
  sources: sources,
  include_directories: top_inc,
  dependencies: deps,
  c_args: warn_flags,
  vala_args: vala_flags,
)

test(test_unit, exe)
