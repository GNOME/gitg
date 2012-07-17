dnl Process this file with autoconf to produce a configure script.

AC_PREREQ([2.64])

m4_define(gitg_major_version, 0)
m4_define(gitg_minor_version, 2)
m4_define(gitg_micro_version, 5)
m4_define(gitg_version, gitg_major_version.gitg_minor_version.gitg_micro_version)

AC_INIT([gitg],
        [gitg_version],
        [https://bugzilla.gnome.org/enter_bug.cgi?product=gitg],
        [gitg],
        [http://live.gnome.org/Gitg])

AC_CONFIG_HEADERS([config.h])
AC_CONFIG_SRCDIR([gitg/gitg.vala])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])

AC_DEFINE(GITG_MAJOR_VERSION, gitg_major_version, [GitG major version])
AC_SUBST(GITG_MAJOR_VERSION, gitg_major_version)
AC_DEFINE(GITG_MINOR_VERSION, gitg_minor_version, [GitG minor version])
AC_SUBST(GITG_MINOR_VERSION, gitg_minor_version)
AC_DEFINE(GITG_MICRO_VERSION, gitg_micro_version, [GitG micro version])
AC_SUBST(GITG_MICRO_VERSION, gitg_micro_version)

AM_INIT_AUTOMAKE([1.11 tar-ustar dist-xz no-dist-gzip -Wno-portability])
AM_MAINTAINER_MODE([enable])

AM_SILENT_RULES([yes])

# Check for programs
AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PATH_PROG(GZIP, gzip)

AM_PATH_PYTHON
AM_PROG_VALAC

AC_PATH_PROG(GLIB_MKENUMS, glib-mkenums)
AC_PATH_PROG(GLIB_COMPILE_RESOURCES, glib-compile-resources)
AC_PATH_PROG(GTK_UPDATE_ICON_CACHE, gtk-update-icon-cache-3.0)

AC_PATH_PROG(VALADOC, valadoc)

# Initialize libtool
LT_PREREQ([2.2])
LT_INIT(disable-static)

# i18n stuff
IT_PROG_INTLTOOL([0.40.0])

AM_GNU_GETTEXT_VERSION([0.17])
AM_GNU_GETTEXT([external])

GETTEXT_PACKAGE=gitg

dnl adl_RECURSIVE_EVAL(VALUE, RESULT)
dnl =================================
dnl Interpolate the VALUE in loop until it doesn't change,
dnl and set the result to $RESULT.
dnl WARNING: It's easy to get an infinite loop with some unsane input.
AC_DEFUN([adl_RECURSIVE_EVAL],
[_lcl_receval="$1"
$2=`(test "x$prefix" = xNONE && prefix="$ac_default_prefix"
     test "x$exec_prefix" = xNONE && exec_prefix="${prefix}"
     _lcl_receval_old=''
     while test "[$]_lcl_receval_old" != "[$]_lcl_receval"; do
       _lcl_receval_old="[$]_lcl_receval"
       eval _lcl_receval="\"[$]_lcl_receval\""
     done
     echo "[$]_lcl_receval")`])

adl_RECURSIVE_EVAL("$datadir/gitg", [GITG_DATADIR])
adl_RECURSIVE_EVAL("$datadir/locale", [GITG_LOCALEDIR])
adl_RECURSIVE_EVAL("$libdir/gitg", [GITG_LIBDIR])

AC_SUBST(GETTEXT_PACKAGE)

AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [Gettext package])
AC_DEFINE_UNQUOTED(GITG_DATADIR,"$GITG_DATADIR", [data dir])
AC_DEFINE_UNQUOTED(GITG_LOCALEDIR,"$GITG_LOCALEDIR", [locale dir])
AC_DEFINE_UNQUOTED(GITG_LIBDIR,"$GITG_LIBDIR", [lib dir])

AC_CHECK_LIB([m], [sinf])

GLIB_REQUIRED_VERSION=2.32
GTK_REQUIRED_VERSION=3.0.0
GTKSOURCEVIEW_REQUIRED_VERSION=3.1.3
INTROSPECTION_REQUIRED=0.10.1

PKG_CHECK_MODULES(LIBGITG, [
	gthread-2.0 >= $GLIB_REQUIRED_VERSION
	glib-2.0 >= $GLIB_REQUIRED_VERSION
	gobject-2.0 >= $GLIB_REQUIRED_VERSION
	gmodule-2.0 >= $GLIB_REQUIRED_VERSION
	gio-2.0 >= $GLIB_REQUIRED_VERSION
	gio-unix-2.0 >= $GLIB_REQUIRED_VERSION
	gobject-introspection-1.0 >= $INTROSPECTION_REQUIRED
	libgit2-glib-1.0
])

AC_ARG_ENABLE(docs,
              [AS_HELP_STRING([--enable-docs],
                              [enable generating documentation [default=no]])],
              [enable_docs=$enableval])

if test "$enable_docs" = "yes"; then
	if test "$VALADOC" = ""; then
		AC_MSG_ERROR([could not find valadoc])
	fi
fi

AM_CONDITIONAL(ENABLE_DOCS, test "$enable_docs" = "yes")

AC_ARG_ENABLE(deprecations,
              [AS_HELP_STRING([--enable-deprecations],
                              [warn about deprecated usages [default=no]])],
              [enable_deprecations=$enableval])

if test "x$USE_MAINTAINER_MODE" = "xyes"; then
LIBGITG_CFLAGS="$LIBGITG_CFLAGS -Wall -Werror -Wuninitialized -Wmissing-declarations"
enable_deprecations="yes"
fi

if test "$enable_deprecations" = "yes"; then
   LIBGITG_CFLAGS="$LIBGITG_CFLAGS \
-DG_DISABLE_DEPRECATED \
-DGDK_DISABLE_DEPRECATED \
-DGTK_DISABLE_DEPRECATED \
-DGDK_PIXBUF_DISABLE_DEPRECATED \
-DGNOME_DISABLE_DEPRECATED \
-DGSEAL_ENABLE"
fi

AC_ARG_ENABLE(debug,
              [AS_HELP_STRING([--disable-debug],
                              [disable debug information [default=yes]])],
              [enable_debug=$enableval], [enable_debug=yes])

GITG_VALAFLAGS="--target-glib 2.32"

if test "x$enable_debug" = "xyes"; then
	LIBGITG_CFLAGS="$LIBGITG_CFLAGS -g -O0"
	GITG_VALAFLAGS="$GITG_VALAFLAGS -g --save-temps"

	AC_DEFINE([ENABLE_DEBUG],[1],[Whether debugging support is enabled])
fi

AC_SUBST(LIBGITG_CFLAGS)
AC_SUBST(LIBGITG_LIBS)

AC_SUBST(GITG_VALAFLAGS)

WEBKITGTK_REQUIRED_VERSION=1.8.0

PKG_CHECK_MODULES(LIBGITG_GTK, [
	gtk+-3.0 >= $GTK_REQUIRED_VERSION
	webkitgtk-3.0 >= $WEBKITGTK_REQUIRED_VERSION
	gee-1.0
	json-glib-1.0
])

LIBGITG_GTK_CFLAGS="$LIBGITG_CFLAGS $LIBGITG_GTK_CFLAGS -DLIBSOUP_USE_UNSTABLE_REQUEST_API"
LIBGITG_GTK_LIBS="$LIBGITG_LIBS $LIBGITG_GTK_LIBS"

AC_SUBST(LIBGITG_GTK_CFLAGS)
AC_SUBST(LIBGITG_GTK_LIBS)

LIBGITG_EXT_CFLAGS="$LIBGITG_GTK_CFLAGS"
LIBGITG_EXT_LIBS="$LIBGITG_GTK_LIBS"

AC_SUBST(LIBGITG_EXT_CFLAGS)
AC_SUBST(LIBGITG_EXT_LIBS)

LIBPEAS_REQUIRED_VERSION=1.2.0
LIBPEAS_GTK_REQUIRED_VERSION=1.2.0

PKG_CHECK_MODULES(GITG, [
	gtksourceview-3.0 >= $GTKSOURCEVIEW_REQUIRED_VERSION
	gsettings-desktop-schemas
	libpeas-1.0 >= $LIBPEAS_REQUIRED_VERSION
	libpeas-gtk-1.0 >= $LIBPEAS_GTK_REQUIRED_VERSION
])

GITG_CFLAGS="$LIBGITG_GTK_CFLAGS $GITG_CFLAGS"
GITG_LIBS="$LIBGITG_GTK_LIBS $GITG_LIBS -lm"

AC_SUBST(GITG_CFLAGS)
AC_SUBST(GITG_LIBS)

GOBJECT_INTROSPECTION_REQUIRE($INTROSPECTION_REQUIRED)
AC_SUBST(INTROSPECTION_REQUIRED)

GNOME_COMPILE_WARNINGS([maximum])

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

GITG_PLUGIN_DATADIR="$datadir/gitg/plugins"
AC_SUBST(GITG_PLUGIN_DATADIR)

GITG_PLUGIN_LIBDIR="$libdir/gitg/plugins"
AC_SUBST(GITG_PLUGIN_LIBDIR)

GITG_PLUGIN_CFLAGS="$GITG_CFLAGS"
GITG_PLUGIN_LIBS="$GITG_LIBS 					\
	\$(top_builddir)/libgitg/libgitg-1.0.la 		\
	\$(top_builddir)/libgitg-ext/libgitg-ext-1.0.la 	\
	\$(top_builddir)/libgitg-gtk/libgitg-gtk-1.0.la"

AC_SUBST(GITG_PLUGIN_CFLAGS)
AC_SUBST(GITG_PLUGIN_LIBS)

GITG_PLUGIN_LIBTOOL_FLAGS="-module -avoid-version"
AC_SUBST(GITG_PLUGIN_LIBTOOL_FLAGS)

GITG_PLUGIN_VALAFLAGS="				\
	--pkg Ggit-1.0 				\
	--pkg libgitg-ext-1.0			\
	--pkg libgitg-1.0			\
	--pkg libgitg-gtk-1.0			\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg libpeas-1.0			\
	--pkg gee-1.0				\
	--pkg json-glib-1.0			\
	--pkg webkitgtk-3.0			\
	--pkg config				\
	\$(GITG_VALAFLAGS)			\
	--vapidir \$(top_srcdir)/vapi		\
	--vapidir \$(top_builddir)/libgitg	\
	--vapidir \$(top_builddir)/libgitg-gtk	\
	--vapidir \$(top_builddir)/libgitg-ext"

AC_SUBST(GITG_PLUGIN_VALAFLAGS)

dnl ===========================================================================
dnl Check for python
dnl ===========================================================================
PYGOBJECT_REQUIRED=3.0.0

AC_ARG_ENABLE([python],
              AS_HELP_STRING([--enable-python[=@<:@no/auto/yes@:>@]],[Build with python support]),
              [enable_python=$enableval],
              [enable_python="auto"])

if test "x$enable_python" = "xauto"; then
        PKG_CHECK_EXISTS([pygobject-3.0 >= $PYGOBJECT_REQUIRED],
                         [enable_python=yes],[enable_python=no])
fi

if test "x$enable_python" = "xyes"; then
        PKG_CHECK_MODULES(PYTHON, [pygobject-3.0 >= $PYGOBJECT_REQUIRED])

        pyoverridesdir=`$PYTHON -c "import gi; print(gi._overridesdir)"`
        AC_SUBST(pyoverridesdir)
fi

AM_CONDITIONAL(ENABLE_PYTHON, test x"$enable_python" = "xyes")

AC_CONFIG_FILES([
Makefile
libgitg/Makefile
libgitg/libgitg-1.0.pc
libgitg-gtk/Makefile
libgitg-gtk/libgitg-gtk-1.0.pc
libgitg-ext/Makefile
libgitg-ext/libgitg-ext-1.0.pc
gitg/Makefile
data/Makefile
data/gitg.desktop.in
data/icons/Makefile
data/org.gnome.gitg.gschema.xml.in
po/Makefile.in
tests/Makefile
plugins/Makefile
plugins/dash/Makefile
plugins/history/Makefile
plugins/diff/Makefile
plugins/diff/icons/Makefile
])

AC_OUTPUT

echo "

Configuration:

	Source code location:	${srcdir}
	Compiler:		${CC}
	Glade catalog:          ${glade_catalog}
	Debug enabled:          ${enable_debug}
	Python support:         ${enable_python}
"
