lib_LTLIBRARIES = libgitg-gtk-1.0.la

INCLUDES =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(LIBGITG_CFLAGS)						\
	$(LIBGITG_GTK_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

libgitg_gtk_1_0_la_LDFLAGS = 		\
	-export-dynamic -no-undefined -export-symbols-regex "^[^_].*"

libgitg_gtk_1_0_la_LIBADD = 				\
	$(LIBGITG_LIBS)					\
	$(LIBGITG_GTK_LIBS)				\
	$(top_builddir)/libgitg/libgitg-1.0.la

INST_H_FILES =				\
	libgitg-gtk.h

VALAFLAGS = 				\
	--pkg Ggit-1.0 			\
	--pkg Gitg-1.0			\
	--pkg gtk+-3.0			\
	--pkg gio-2.0			\
	$(GITG_VALAFLAGS)		\
	--header libgitg-gtk.h		\
	--includedir libgitg-gtk	\
	--basedir $(top_srcdir)		\
	--gir GitgGtk-1.0.gir		\
	--library libgitg-gtk-1.0	\
	--girdir "$(top_builddir)/libgitg"

GitgGtk-1.0.gir: libgitg-gtk-1.0.la
libgitg-gtk.h: libgitg-gtk-1.0.la

VALA_FILES =					\
	gitg-gtk-commit-model.vala		\
	gitg-gtk-label-renderer.vala		\
	gitg-gtk-cell-renderer-lanes.vala	\
	gitg-gtk-commit-list-view.vala

# Ignore all warnings for vala code...
libgitg_gtk_1_0_la_CFLAGS =		\
	-w

libgitg_gtk_1_0_la_SOURCES = 		\
	$(VALA_FILES)

headerdir = $(prefix)/include/libgitg-gtk-1.0/libgitg-gtk
header_DATA = $(INST_H_FILES)

girdir = $(INTROSPECTION_GIRDIR)
gir_DATA = GitgGtk-1.0.gir

typelibdir = $(INTROSPECTION_TYPELIBDIR)
typelib_DATA = GitgGtk-1.0.typelib

%.typelib: %.gir
	$(INTROSPECTION_COMPILER) $(INTROSPECTION_COMPILER_ARGS) --includedir=. --includedir="$(top_builddir)/libgitg" -o $@ $<

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libgitg-gtk-1.0.pc

BUILT_SOURCES = \
	$(gir_DATA) \
	libgitg-gtk.h

EXTRA_DIST = $(pkgconfig_DATA)
CLEANFILES = $(VALA_FILES:.vala=.c)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)

-include $(top_srcdir)/git.mk
