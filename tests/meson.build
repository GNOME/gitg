subdir('support')
subdir('libgitg')
subdir('gitg')

deps = [
  gee_dep,
  gtk_dep,
  libgit2_glib_dep,
  libgitg_dep
]

test_names = [
  'diff-view',
  'repository-list-box',
  'progress-bin'
]

foreach test_name: test_names
  executable(
    'tests-' + test_name,
    sources: test_name + '.vala',
    include_directories: top_inc,
    dependencies: deps,
    c_args: warn_flags
  )
endforeach
