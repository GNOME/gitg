project(
  'gitg', ['c', 'vala'],
  version: '3.26.0',
  license: 'GPL2+',
  default_options: 'buildtype=debugoptimized',
  meson_version: '>= 0.43.0'
)

gitg_name = meson.project_name()

gitg_version = meson.project_version()
version_array = gitg_version.split('.')
gitg_major_version = version_array[0].to_int()
gitg_minor_version = version_array[1].to_int()
gitg_micro_version = version_array[2].to_int()

gitg_api_version = '1.0'
gitg_gir_version = '1.0'

gitg_gettext = gitg_name

gitg_prefix = get_option('prefix')
gitg_bindir = join_paths(gitg_prefix, get_option('bindir'))
gitg_datadir = join_paths(gitg_prefix, get_option('datadir'))
gitg_includedir = join_paths(gitg_prefix, get_option('includedir'))
gitg_libdir = join_paths(gitg_prefix, get_option('libdir'))
gitg_localedir = join_paths(gitg_prefix, get_option('localedir'))
gitg_mandir = join_paths(gitg_prefix, get_option('mandir'))

gitg_pkgdatadir = join_paths(gitg_datadir, gitg_name)
gitg_pkglibdir = join_paths(gitg_libdir, gitg_name)

gitg_girepositorydir = join_paths(gitg_libdir, 'girepository-' + gitg_gir_version)

soversion = 0
current = 0
revision = 0
libversion = '@0@.@1@.@2@'.format(soversion, current, revision)

gitg_debug = get_option('buildtype').contains('debug')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

config_h = configuration_data()

# defines
set_defines = [
  # package
  ['PACKAGE_NAME', gitg_name],
  ['PACKAGE_URL', 'https://wiki.gnome.org/Apps/Gitg'],
  ['PACKAGE_VERSION', gitg_version],
  ['VERSION', gitg_version],
  # i18n
  ['GETTEXT_PACKAGE', gitg_gettext],
  # gitg
  ['GITG_DATADIR', gitg_pkgdatadir],
  ['GITG_LIBDIR', gitg_pkglibdir],
  ['GITG_LOCALEDIR', gitg_localedir]
]

foreach define: set_defines
  config_h.set_quoted(define[0], define[1])
endforeach

# c compiler flags
common_flags = ['-DHAVE_CONFIG_H']
warn_flags = []

if get_option('deprecations')
  warn_flags += [
    '-DG_DISABLE_DEPRECATED',
    '-DGDK_DISABLE_DEPRECATED',
    '-DGTK_DISABLE_DEPRECATED',
    '-DGDK_PIXBUF_DISABLE_DEPRECATED',
    '-DGNOME_DISABLE_DEPRECATED',
    '-DGSEAL_ENABLE'
  ]
endif

if gitg_debug
  test_cflags = [
    '-Werror=format=2',
    '-Werror=implicit-function-declaration',
    '-Werror=init-self',
    '-Werror=missing-include-dirs',
    '-Werror=missing-prototypes',
    '-Werror=pointer-arith',
    '-Werror=return-type',
    '-Wmissing-declarations',
    '-Wnested-externs',
    '-Wstrict-prototypes',
    '-Wuninitialized'
  ]

  warn_flags += cc.get_supported_arguments(test_cflags)
endif

add_project_arguments(common_flags, language: 'c')

# vala compiler flags
vapi_dir = join_paths(meson.source_root(), 'vapi')

common_flags = '--vapidir=' + vapi_dir

add_project_arguments(common_flags, language: 'vala')

ldflag = '-Wl,--version-script'
have_version_script = host_machine.system().contains('linux') and cc.has_argument(ldflag)

symbol_map = join_paths(meson.source_root(), 'libgitg.map')

glib_req_version = '>= 2.38'

gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0', version: glib_req_version)
glib_dep = dependency('glib-2.0', version: glib_req_version)
gtk_dep = dependency('gtk+-3.0', version: '>= 3.20.0')
gtksourceview_dep = dependency('gtksourceview-3.0', version: '>= 3.10')
libgit2_glib_dep = dependency('libgit2-glib-1.0', version: ['>= 0.25.0', '< 0.27.0'])
libpeas_dep = dependency('libpeas-1.0')
libsoup_dep = dependency('libsoup-2.4')

config_dep = valac.find_library('config', dirs: vapi_dir)
gitg_platform_support_dep = valac.find_library('gitg-platform-support', dirs: vapi_dir)

# ggit threads
ggit_threads = '''
  #include <libgit2-glib/ggit.h>
  int
  main(int argc, const char *argv[])
  {
    ggit_init ();
    return ((ggit_get_features () & GGIT_FEATURE_THREADS) != 0) ? 0 : 1;
  };
'''

res = cc.run(ggit_threads, dependencies: libgit2_glib_dep)
assert(
  res.compiled() and (res.returncode() == 0),
  'please recompile a threadsafe version of libgit2 (-DTHREADSAFE:BOOL=ON)'
)

# gtk required version is set to 3.20, so this will be always true
gtk_shortcuts_window = gtk_dep.version().version_compare('3.19')

m_dep = cc.find_library('m', required: false)

gdk_dep = dependency('gdk-3.0')
gdk_targets = gdk_dep.get_pkgconfig_variable('targets')

if gdk_targets.contains('quartz')
  platform_name = 'osx'
elif gdk_targets.contains('x11')
  platform_name = 'unix'
elif gdk_targets.contains('win32')
  platform_name = 'win32'
else
  error('Unknown Gdk targets: ' + gdk_targets)
endif
config_h.set_quoted('PLATFORM_NAME', platform_name)

g_ir_compiler = find_program('g-ir-compiler')

enable_docs = get_option('docs')
if enable_docs
  docs_dir = join_paths(meson.source_root(), 'docs')
  valadoc = find_program('valadoc')
endif

gnome = import('gnome')
i18n = import('i18n')
pkg = import('pkgconfig')

po_dir = join_paths(meson.source_root(), 'po')

intltool_merge = find_program('intltool-merge')
intltool_cache = join_paths(po_dir, '.intltool-merge-cache')
intltool_desktop_cmd = [intltool_merge, '-d', '-u', '-c', intltool_cache, po_dir, '@INPUT@', '@OUTPUT@']
intltool_xml_cmd = [intltool_merge, '-x', '-u', '-c', intltool_cache, po_dir, '@INPUT@', '@OUTPUT@']

top_inc = include_directories('.')

subdir('po')
subdir('contrib/xml')
subdir('contrib/ide')
subdir('libgitg')
subdir('libgitg-ext')
subdir('plugins')
subdir('gitg')
subdir('data')
subdir('tests')

configure_file(
  output: 'config.h',
  configuration: config_h
)

meson.add_install_script(
  'meson_post_install.py',
  gitg_datadir,
  (enable_python ? 'python' : ''),
  gitg_libdir
)

output = '\nConfiguration:\n\n'
output += '        Source code location:   ' + meson.source_root() + '\n'
output += '        Compiler:               ' + cc.get_id() + '\n'
output += '        Glade catalog:          ' + enable_glade_catalog.to_string() + '\n'
output += '        Debug enabled:          ' + gitg_debug.to_string() + '\n'
output += '        Python support:         ' + enable_python.to_string() + '\n'
message(output)
