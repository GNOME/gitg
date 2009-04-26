dnl Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 0)
m4_define(gitg_micro_version, 3)
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

PKG_CHECK_MODULES(PACKAGE, [
	gtk+-2.0 >= 2.12.0
	gthread-2.0
	gtksourceview-2.0
	gio-2.0
	gio-unix-2.0
	gmodule-2.0
	gconf-2.0
])

AC_PATH_PROG(GLIB_GENMARSHAL, glib-genmarshal)

AC_ARG_ENABLE([bundle],
	AS_HELP_STRING([--enable-bundle],[Enable building bundle (default: disabled)]),
	[enable_bundle=$enableval],
	[enable_bundle=no])

if test "$enable_bundle" = "yes"; then
	AC_DEFINE([ENABLE_BUNDLE],[1],[Defined if building bundle])
fi

bundledir=gitg-bundle-gitg_version
AC_SUBST(bundledir)

AM_GCONF_SOURCE_2

AC_CONFIG_FILES([
Makefile
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
