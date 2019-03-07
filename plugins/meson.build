plugin_cflags = warn_flags + [
  '-DDATADIR="@0@"'.format(gitg_datadir),
  '-DLIBDIR="@0@"'.format(gitg_libdir),
]

plugin_deps = [
  config_dep,
  gee_dep,
  libgit2_glib_dep,
  gtk_dep,
  gtksourceview_dep,
  libgitg_dep,
  libgitg_ext_dep,
  libpeas_dep,
  libdazzle_dep,
]

plugin_dir = join_paths(gitg_pkglibdir, 'plugins')

subdir('diff')
subdir('files')
