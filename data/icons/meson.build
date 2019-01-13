icon_sizes = [
  '16x16',
  '22x22',
  '24x24',
  '32x32',
  '48x48',
  '256x256',
]

foreach icon_size: icon_sizes
  install_data(
    '_'.join(['hicolor', 'apps', icon_size, 'gitg.png']),
    rename: '@0@.png'.format(application_id),
    install_dir: join_paths(gitg_datadir, 'icons', 'hicolor', icon_size, 'apps'),
  )
endforeach

install_data(
  '_'.join(['hicolor', 'apps', 'scalable', 'gitg-symbolic.svg']),
  rename: '@0@-symbolic.svg'.format(application_id),
  install_dir: join_paths(gitg_datadir, 'icons', 'hicolor', 'scalable', 'apps'),
)
