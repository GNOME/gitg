dnl Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 1)
m4_define(gitg_micro_version, 2)
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

# Which gtk+ API version to compile against

GTK_REQUIRED=gtk+-2.0
GTK_REQUIRED_VERSION=2.18.0
GTKSOURCEVIEW_REQUIRED=gtksourceview-2.0
GTKSOURCEVIEW_REQUIRED_VERSION=2.8.0

GLIB_REQUIRED_VERSION=2.26

PKG_CHECK_MODULES(GITG, [
	$GTK_REQUIRED >= $GTK_REQUIRED_VERSION
	gthread-2.0 >= $GLIB_REQUIRED_VERSION
	glib-2.0 >= $GLIB_REQUIRED_VERSION
	gobject-2.0 >= $GLIB_REQUIRED_VERSION
	gmodule-2.0 >= $GLIB_REQUIRED_VERSION
	gio-2.0 >= $GLIB_REQUIRED_VERSION
	gio-unix-2.0 >= $GLIB_REQUIRED_VERSION
])

PKG_CHECK_MODULES(PACKAGE, [
	$GTKSOURCEVIEW_REQUIRED >= $GTKSOURCEVIEW_REQUIRED_VERSION
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
-DGNOME_DISABLE_DEPRECATED"
fi

if $PKG_CONFIG --atleast-version 2.19.0 $GTK_REQUIRED; then
	gtkatleast=
else
	gtkatleast=no
fi

AM_CONDITIONAL(BUILD_SPINNER, test "$gtkatleast" = "no")
if test "$gtkatleast" = "no"; then
	AC_DEFINE([BUILD_SPINNER],[1],[Whether to use GitgSpinner instead of GtkSpinner])
fi

if $PKG_CONFIG --atleast-version 2.21.0 $GTK_REQUIRED; then
	gtkatleast=yes
else
	gtkatleast=
fi

if test "$gtkatleast" = "yes"; then
	DISABLE_DEPRECATED_CFLAGS="$DISABLE_DEPRECATED_CFLAGS -DGSEAL_ENABLE"
fi

AC_SUBST(DISABLE_DEPRECATED_CFLAGS)

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
                              [Install a glade catalog file [default=no]])],
                              [glade_catalog=$enableval],
                              [glade_catalog="no"])

AM_CONDITIONAL([GLADE_CATALOG], [ test "$glade_catalog" = "yes" ])

AS_IF([ test "$glade_catalog" = "yes" ],
	[PKG_CHECK_EXISTS(GLADE, [gladeui-2.0 >= $GLADE_UI_REQUIRED])
	 AC_MSG_CHECKING([for Glade catalog dir])
	 GLADE_CATALOG_DIR=`$PKG_CONFIG --variable=catalogdir gladeui-2.0 2>&AS_MESSAGE_LOG_FD`
	 AC_MSG_RESULT([$GLADE_CATALOG_DIR])
	 AC_SUBST(GLADE_CATALOG_DIR)])

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
