subdir('support')
subdir('libgitg')
subdir('gitg')

test_names = [
  'diff-view',
  'repository-list-box',
  'progress-bin',
]

foreach test_name: test_names
  executable(
    'tests-' + test_name,
    sources: test_name + '.vala',
    include_directories: top_inc,
    dependencies: libgitg_dep,
    c_args: warn_flags,
  )
endforeach
