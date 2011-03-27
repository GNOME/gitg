dnl Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 2)
m4_define(gitg_micro_version, 1)
m4_define(gitg_version, gitg_major_version.gitg_minor_version.gitg_micro_version)

AC_INIT([gitg],
        [gitg_version],
        [https://bugzilla.gnome.org/enter_bug.cgi?product=gitg],
        [gitg],
        [http://live.gnome.org/Gitg])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_SRCDIR([gitg/gitg.c])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])

AC_DEFINE(GITG_MAJOR_VERSION, gitg_major_version, [GitG major version])
AC_SUBST(GITG_MAJOR_VERSION, gitg_major_version)
AC_DEFINE(GITG_MINOR_VERSION, gitg_minor_version, [GitG minor version])
AC_SUBST(GITG_MINOR_VERSION, gitg_minor_version)
AC_DEFINE(GITG_MICRO_VERSION, gitg_micro_version, [GitG micro version])
AC_SUBST(GITG_MICRO_VERSION, gitg_micro_version)

AM_INIT_AUTOMAKE([1.11 dist-bzip2 no-dist-gzip])
AM_MAINTAINER_MODE([enable])

AM_SILENT_RULES([yes])

# Check for programs
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PATH_PROG(GZIP, gzip)

AC_PATH_PROG(GLIB_MKENUMS, glib-mkenums)

# Initialize libtool
LT_PREREQ([2.2])
LT_INIT

# i18n stuff
IT_PROG_INTLTOOL([0.40.0])

AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

GETTEXT_PACKAGE=gitg
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])

AC_CHECK_LIB([m], [sinf])

GLIB_REQUIRED_VERSION=2.26
GTK_REQUIRED_VERSION=3.0.0
GTKSOURCEVIEW_REQUIRED_VERSION=2.91.8

PKG_CHECK_MODULES(GITG, [
	gtk+-3.0 >= $GTK_REQUIRED_VERSION
	gthread-2.0 >= $GLIB_REQUIRED_VERSION
	glib-2.0 >= $GLIB_REQUIRED_VERSION
	gobject-2.0 >= $GLIB_REQUIRED_VERSION
	gmodule-2.0 >= $GLIB_REQUIRED_VERSION
	gio-2.0 >= $GLIB_REQUIRED_VERSION
	gio-unix-2.0 >= $GLIB_REQUIRED_VERSION
])

PKG_CHECK_MODULES(PACKAGE, [
	gtksourceview-3.0 >= $GTKSOURCEVIEW_REQUIRED_VERSION
	gsettings-desktop-schemas
])

AC_PATH_PROG(GLIB_GENMARSHAL, glib-genmarshal)

GNOME_COMPILE_WARNINGS([maximum])

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
-DG_DISABLE_DEPRECATED \
-DGDK_DISABLE_DEPRECATED \
-DGTK_DISABLE_DEPRECATED \
-DGDK_PIXBUF_DISABLE_DEPRECATED \
-DGNOME_DISABLE_DEPRECATED \
-DGSEAL_ENABLE"
fi

PACKAGE_LIBS="$PACKAGE_LIBS -lm"


AC_ARG_ENABLE(debug,
              [AS_HELP_STRING([--disable-debug],
                              [disable debug information [default=yes]])],
              [enable_debug=$enableval], [enable_debug=yes])

if test "$enable_debug" = "yes"; then
	PACKAGE_CFLAGS="$PACKAGE_CFLAGS -g"
	AC_DEFINE([ENABLE_DEBUG],[1],[Whether debugging support is enabled])
fi

AC_SUBST(PACKAGE_CFLAGS)
AC_SUBST(PACKAGE_LIBS)

GLIB_GSETTINGS

GLADE_UI_REQUIRED=3.2

AC_ARG_ENABLE([glade-catalog],
              [AS_HELP_STRING([--enable-glade-catalog[=@<:@no/auto/yes@:>@]],
                              [Install a glade catalog file [default=auto]])],
                              [glade_catalog=$enableval],
                              [glade_catalog="no"])

if test "x$glade_catalog" = "xauto"; then
	PKG_CHECK_EXISTS([gladeui-1.0 >= $GLADE_UI_REQUIRED], \
	                 glade_catalog="yes", glade_catalog="no")
fi

AM_CONDITIONAL([GLADE_CATALOG], [test "x$glade_catalog" = xyes])

AS_IF([test "x$glade_catalog" = xyes],
	[PKG_CHECK_MODULES(GLADE, [gladeui-1.0 >= $GLADE_UI_REQUIRED])
	 GLADE_CATALOGDIR=`$PKG_CONFIG --variable=catalogdir gladeui-1.0 2>&AS_MESSAGE_LOG_FD`
	 AC_SUBST(GLADE_CATALOGDIR)])

AC_CONFIG_FILES([
Makefile
libgitg-1.0.pc
libgitg/Makefile
gitg/Makefile
data/Makefile
data/gitg.desktop.in
data/icons/Makefile
data/org.gnome.gitg.gschema.xml.in
po/Makefile.in
tests/Makefile
tools/Makefile
])

AC_OUTPUT

echo "

Configuration:

	Source code location:	${srcdir}
	Compiler:		${CC}
	Glade catalog:          ${glade_catalog}
"
