subdir('icons')

desktop_conf = configuration_data()
desktop_conf.set('VERSION', gitg_version)

desktop = 'gitg.desktop'

desktop_in = configure_file(
  input: desktop + '.in.in',
  output: desktop + '.in',
  configuration: desktop_conf
)

custom_target(
  desktop,
  input: desktop_in,
  output: desktop,
  command: intltool_desktop_cmd,
  install: true,
  install_dir: join_paths(gitg_datadir, 'applications')
)

schema_conf = configuration_data()
schema_conf.set('GETTEXT_PACKAGE', gitg_gettext)

schema = 'org.gnome.gitg.gschema.xml'

schema_in = configure_file(
  input: schema + '.in.in',
  output: schema + '.in',
  configuration: schema_conf
)

custom_target(
  schema,
  input: schema_in,
  output: schema,
  command: [intltool_merge, '-x', '-u', '--no-translations', '@INPUT@', '@OUTPUT@'],
  install: true,
  install_dir: join_paths(gitg_datadir, 'glib-2.0', 'schemas')
)

install_data(
  'gitg.appdata.xml',
  install_dir: join_paths(gitg_datadir, 'metainfo')
)

install_data(
  'gitg.1',
  install_dir: join_paths(gitg_mandir, 'man1')
)

enable_glade_catalog = get_option('glade_catalog')
if enable_glade_catalog
  install_data(
    'gitg-glade.xml',
    install_dir: join_paths(gitg_datadir, 'glade', 'catalogs')
  )
endif
