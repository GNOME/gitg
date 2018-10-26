subdir('icons')

desktop = 'gitg.desktop'

i18n.merge_file(
  desktop,
  type: 'desktop',
  input: desktop + '.in',
  output: desktop,
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(gitg_datadir, 'applications'),
)

schema_conf = configuration_data()
schema_conf.set('GETTEXT_PACKAGE', gitg_gettext)

schema = 'org.gnome.gitg.gschema.xml'

configure_file(
  input: schema + '.in',
  output: schema,
  configuration: schema_conf,
  install: true,
  install_dir: join_paths(gitg_datadir, 'glib-2.0', 'schemas'),
)

appdata = 'gitg.appdata.xml'

i18n.merge_file(
  appdata,
  type: 'xml',
  input: appdata + '.in',
  output: appdata,
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(gitg_datadir, 'metainfo'),
)

install_man(
  'gitg.1',
)

enable_glade_catalog = get_option('glade_catalog')
if enable_glade_catalog
  install_data(
    'gitg-glade.xml',
    install_dir: join_paths(gitg_datadir, 'glade', 'catalogs'),
  )
endif
