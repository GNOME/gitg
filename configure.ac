dnl Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 0)
m4_define(gitg_micro_version, 8)
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
AC_PROG_LIBTOOL

AC_ISC_POSIX
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PATH_PROG(GZIP, gzip)

AC_PATH_PROG(GLIB_MKENUMS, glib-mkenums)

dnl make sure we keep ACLOCAL_FLAGS around for maintainer builds to work
AC_SUBST(ACLOCAL_AMFLAGS, "$ACLOCAL_FLAGS -I m4")

# i18n stuff
IT_PROG_INTLTOOL([0.40.0])

AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

GETTEXT_PACKAGE=gitg
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])


AC_CHECK_LIB([m], [sinf])

# Which gtk+ API version to compile against

AC_MSG_CHECKING([which gtk+ version to compile against])
AC_ARG_WITH([gtk],
	[AS_HELP_STRING([--with-gtk=2.0|3.0],[which gtk+ version to compile against (default: 2.0)])],
	[case "$with_gtk" in
		2.0|3.0) ;;
		*) AC_MSG_ERROR([invalid gtk version specified]) ;;
	esac],
	[with_gtk=2.0])
AC_MSG_RESULT([$with_gtk])

case "$with_gtk" in
	2.0)
		GTK_REQUIRED=gtk+-2.0
		GTK_REQUIRED_VERSION=2.18.0
		GTKSOURCEVIEW_REQUIRED=gtksourceview-2.0
		GTKSOURCEVIEW_REQUIRED_VERSION=2.8.0
		;;
	3.0)
		GTK_REQUIRED=gtk+-3.0
		GTK_REQUIRED_VERSION=2.90.0
		GTKSOURCEVIEW_REQUIRED=gtksourceview-3.0
		GTKSOURCEVIEW_REQUIRED_VERSION=2.90.0
		;;
esac

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
tests/Makefile
tools/Makefile
])

AC_OUTPUT

gtkversion=`$PKG_CONFIG --modversion $GTK_REQUIRED`

echo "

Configuration:

	Source code location:	${srcdir}
	Compiler:		${CC}
	gtk+ version:           ${gtkversion}
"
