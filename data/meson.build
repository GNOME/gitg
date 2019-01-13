subdir('icons')

desktop = 'org.gnome.gitg.desktop'

desktop_config = configuration_data()
desktop_config.set('icon', application_id)
desktop_config.set('binary', gitg_name)
i18n.merge_file(
  desktop,
  type: 'desktop',
  input: configure_file(
    input: desktop + '.in.in',
    output: desktop + '.in',
    configuration: desktop_config
  ),
  output: '@0@.desktop'.format(application_id),
  po_dir: po_dir,
  install: true,
  install_dir: join_paths(gitg_datadir, 'applications'),
)

schema_conf = configuration_data()
schema_conf.set('GETTEXT_PACKAGE', gitg_gettext)
schema_conf.set('APPLICATION_ID', application_id)
schema_path = '/org/gnome/gitg'
if get_option('profile')  == 'development'
  schema_path = '/org/gnome/gitgDevel'
endif
schema_conf.set('SCHEMA_PATH', schema_path)
schema = 'org.gnome.gitg.gschema.xml'

configure_file(
  input: schema + '.in',
  output: '@0@.gschema.xml'.format(application_id),
  configuration: schema_conf,
  install: true,
  install_dir: join_paths(gitg_datadir, 'glib-2.0', 'schemas'),
)

appdata = 'org.gnome.gitg.appdata.xml'
appdata_config = configuration_data()
appdata_config.set('app-id', application_id)
appdata_config.set('gettext', gitg_name)
i18n.merge_file(
  appdata,
  type: 'xml',
  input: configure_file(
    input: appdata + '.in.in',
    output: appdata + '.in',
    configuration: appdata_config
  ),
  output: '@0@.appdata.xml'.format(application_id),
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
