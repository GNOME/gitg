dnl Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 0)
m4_define(gitg_micro_version, 6)
m4_define(gitg_version, gitg_major_version.gitg_minor_version.gitg_micro_version)

AC_INIT(gitg, gitg_version, http://www.icecrew.nl)
AC_CONFIG_SRCDIR(gitg/gitg.c)
AC_CONFIG_MACRO_DIR([m4])

AC_DEFINE(GITG_MAJOR_VERSION, gitg_major_version, [GitG major version])
AC_SUBST(GITG_MAJOR_VERSION, gitg_major_version)
AC_DEFINE(GITG_MINOR_VERSION, gitg_minor_version, [GitG minor version])
AC_SUBST(GITG_MINOR_VERSION, gitg_minor_version)
AC_DEFINE(GITG_MICRO_VERSION, gitg_micro_version, [GitG micro version])
AC_SUBST(GITG_MICRO_VERSION, gitg_micro_version)

AM_INIT_AUTOMAKE([1.8 dist-bzip2 no-dist-gzip])

AM_MAINTAINER_MODE
AC_CONFIG_HEADERS(config.h)
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])

AC_PATH_PROG(GCONFTOOL, gconftool-2)
IT_PROG_INTLTOOL([0.35.0])
AC_PROG_LIBTOOL

AC_ISC_POSIX
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PATH_PROG(GZIP, gzip)

AC_PATH_PROG(GLIB_MKENUMS, glib-mkenums)

dnl make sure we keep ACLOCAL_FLAGS around for maintainer builds to work
AC_SUBST(ACLOCAL_AMFLAGS, "$ACLOCAL_FLAGS -I m4")

GETTEXT_PACKAGE=gitg
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])

AM_GLIB_GNU_GETTEXT

PKG_CHECK_EXISTS([gtk+-3.0 >= 2.90],
		 [
			GTK_REQUIRED=gtk+-3.0
			GTK_REQUIRED_VERSION=2.90.0
		 ],[
			GTK_REQUIRED=gtk+-2.0
			GTK_REQUIRED_VERSION=2.20.0
		 ])

PKG_CHECK_MODULES(GITG, [
	$GTK_REQUIRED >= $GTK_REQUIRED_VERSION
	gthread-2.0
	glib-2.0
	gobject-2.0
	gmodule-2.0
	gio-2.0
	gio-unix-2.0
])

PKG_CHECK_MODULES(PACKAGE, [
	gtksourceview-2.0 >= 2.8
	gconf-2.0
])

AC_PATH_PROG(GLIB_GENMARSHAL, glib-genmarshal)

GNOME_COMPILE_WARNINGS(yes)

if test "x$USE_MAINTAINER_MODE" = "xyes"; then
PACKAGE_CFLAGS="$PACKAGE_CFLAGS -Wall -Werror -Wuninitialized -Wmissing-declarations"
enable_deprecations="yes"
fi


AC_ARG_ENABLE(deprecations,
              [AS_HELP_STRING([--enable-deprecations],
                              [warn about deprecated usages [default=no]])],
              [enable_deprecations=$enableval])

if test "$enable_deprecations" = "yes"; then
   DISABLE_DEPRECATED_CFLAGS="\
-DGSEAL_ENABLE \
-DG_DISABLE_DEPRECATED \
-DGDK_DISABLE_DEPRECATED \
-DGTK_DISABLE_DEPRECATED \
-DGDK_PIXBUF_DISABLE_DEPRECATED \
-DGNOME_DISABLE_DEPRECATED"
   AC_SUBST(DISABLE_DEPRECATED_CFLAGS)
fi

AC_SUBST(PACKAGE_CFLAGS)
AC_SUBST(PACKAGE_LIBS)

AM_GCONF_SOURCE_2

AC_CONFIG_FILES([
Makefile
libgitg-1.0.pc
libgitg/Makefile
gitg/Makefile
data/Makefile
data/gitg.desktop.in
data/icons/Makefile
po/Makefile.in
])

AC_OUTPUT

echo "

Configuration:

	Source code location:	${srcdir}
	Compiler:		${CC}
"
