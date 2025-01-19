project(
  'gitg', ['c', 'vala'],
  version: '45.alpha',
  license: 'GPL2+',
  default_options: 'buildtype=debugoptimized',
  meson_version: '>= 0.50.0',
)
application_id = 'org.gnome.gitg'
gitg_name = meson.project_name()

if get_option('profile') == 'development'
  application_id = 'org.gnome.gitgDevel'
  gitg_name = meson.project_name() + 'Devel'
endif

gitg_version = meson.project_version()
version_array = gitg_version.split('.')

gitg_api_version = '1.0'

windows = import('windows')
host_system = host_machine.system()

gitg_gettext = gitg_name

gitg_prefix = get_option('prefix')
gitg_bindir = join_paths(gitg_prefix, get_option('bindir'))
gitg_datadir = join_paths(gitg_prefix, get_option('datadir'))
gitg_includedir = join_paths(gitg_prefix, get_option('includedir'))
gitg_libdir = join_paths(gitg_prefix, get_option('libdir'))
gitg_localedir = join_paths(gitg_prefix, get_option('localedir'))

gitg_pkgdatadir = join_paths(gitg_datadir, gitg_name)
gitg_pkglibdir = join_paths(gitg_libdir, gitg_name)

gitg_girepositorydir = join_paths(gitg_libdir, 'girepository-1.0')

soversion = 0
current = 0
revision = 0
libversion = '@0@.@1@.@2@'.format(soversion, current, revision)

gitg_debug = get_option('buildtype').contains('debug')

cc = meson.get_compiler('c')
valac = meson.get_compiler('vala')

gnome = import('gnome')
i18n = import('i18n')
pkg = import('pkgconfig')

source_root = meson.current_source_dir()
build_root = meson.current_build_dir()

libgitg_dir = join_paths(source_root, 'libgitg')
po_dir = join_paths(source_root, 'po')
vapi_dir = join_paths(source_root, 'vapi')

top_inc = include_directories('.')

config_h = configuration_data()

# defines
set_defines = [
  # package
  ['PACKAGE_NAME', gitg_name],
  ['PACKAGE_URL', 'https://wiki.gnome.org/Apps/Gitg'],
  ['VERSION', gitg_version],
  ['APPLICATION_ID', application_id],
  ['PROFILE', get_option('profile')],
  # i18n
  ['GETTEXT_PACKAGE', gitg_gettext],
  # gitg
  ['GITG_DATADIR', gitg_pkgdatadir],
  ['GITG_LIBDIR', gitg_pkglibdir],
  ['GITG_LOCALEDIR', gitg_localedir],
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
    '-DGSEAL_ENABLE',
  ]
endif

if gitg_debug
  warn_flags += cc.get_supported_arguments([
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
    '-Wuninitialized',
  ])
endif

add_project_arguments(common_flags, language: 'c')
add_project_arguments(['-DG_LOG_DOMAIN="gitg"'], language: 'c')

# vala compiler flags
add_project_arguments('--vapidir=' + vapi_dir, language: 'vala')

symbol_map = join_paths(source_root, 'libgitg.map')
common_ldflags = cc.get_supported_link_arguments('-Wl,--version-script,@0@'.format(symbol_map))

glib_req_version = '>= 2.68'

hdy_dep = dependency('libhandy-1', version: '>= 1.5.0')
gee_dep = dependency('gee-0.8')
gio_dep = dependency('gio-2.0', version: glib_req_version)
glib_dep = dependency('glib-2.0', version: glib_req_version)
gobject_introspection_dep = dependency('gobject-introspection-1.0', version: '>= 0.10.1')
gsettings_desktop_schemas_dep = dependency('gsettings-desktop-schemas')
gtk_dep = dependency('gtk+-3.0', version: '>= 3.20.0')
gspell_dep = dependency('gspell-1', version: '>= 1.8.1')
gtksourceview_dep = dependency('gtksourceview-4', version: '>= 4.0.3')
libgit2_glib_dep = dependency('libgit2-glib-1.0', version: ['>= 1.2.0'])
libpeas_dep = dependency('libpeas-1.0')
libsecret_dep = dependency('libsecret-1')
libxml_dep = dependency('libxml-2.0', version: '>= 2.9.0')
json_glib_dependency = dependency('json-glib-1.0')
gpgme_dependency = dependency('gpgme')

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
  'please recompile a threadsafe version of libgit2 (-DTHREADSAFE:BOOL=ON)',
)

# gtk required version is set to 3.20, so this will be always true
gtk_shortcuts_window = gtk_dep.version().version_compare('>= 3.19')

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

module_suffix = []
# Keep the autotools convention for shared module suffix because GModule
# depends on it: https://gitlab.gnome.org/GNOME/glib/issues/520
if ['darwin', 'ios'].contains(host_machine.system())
  module_suffix = 'so'
endif

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
  configuration: config_h,
)

meson.add_install_script(
  'meson_post_install.py',
  gitg_name,
  gitg_datadir
)

output = '\nConfiguration:\n\n'
output += '        Source code location:   ' + source_root + '\n'
output += '        Compiler:               ' + cc.get_id() + '\n'
output += '        Glade catalog:          ' + enable_glade_catalog.to_string() + '\n'
output += '        Debug enabled:          ' + gitg_debug.to_string() + '\n'
output += '        Python support:         ' + enable_python.to_string() + '\n'
output += '        Profile:                ' + get_option('profile') + '\n'
message(output)
