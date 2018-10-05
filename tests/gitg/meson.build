sources = gitg_sources + support_sources + files(
  'application-mock.vala',
  'main.vala',
  'notifications-mock.vala',
  'ref-action-interface-mock.vala',
  'simple-notification-mock.vala',
  'test-checkout-ref.vala',
  'test-cherry-pick-commit.vala',
  'test-merge-ref.vala',
)

deps = [
  config_dep,
  gitg_assert_dep,
  libgitg_ext_dep,
]

vala_flags = '--disable-warnings'

test_unit = 'tests-gitg'

exe = executable(
  test_unit,
  sources: sources,
  include_directories: top_inc,
  dependencies: deps,
  c_args: warn_flags,
  vala_args: vala_flags,
)

test(test_unit, exe)
