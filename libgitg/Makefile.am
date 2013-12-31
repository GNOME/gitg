SUBDIRS = tests

lib_LTLIBRARIES = libgitg-1.0.la

AM_CPPFLAGS =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(LIBGITG_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"					\
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\"

libgitg_1_0_la_LDFLAGS = 		\
	-export-dynamic -no-undefined -export-symbols-regex "^[^_].*"

libgitg_1_0_la_LIBADD = $(LIBGITG_LIBS)

AM_VALAFLAGS = 				\
	--pkg Ggit-1.0 			\
	--pkg gtk+-3.0			\
	--pkg gio-2.0			\
	--pkg libsoup-2.4		\
	--pkg webkit2gtk-3.0		\
	--pkg gee-0.8			\
	--pkg json-glib-1.0		\
	--pkg gio-unix-2.0		\
	$(GITG_VALAFLAGS)		\
	--vapidir $(top_srcdir)/vapi	\
	--header libgitg.h		\
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir Gitg-1.0.gir		\
	--library libgitg-1.0		\
	--gresources "$(top_srcdir)/libgitg/resources/resources.xml"

Gitg-1.0.gir: libgitg-1.0.la
libgitg-1.0.vapi: libgitg-1.0.la
libgitg.h: libgitg-1.0.la

VALA_FILES =					\
	gitg-assembly-info.vala			\
	gitg-async.vala				\
	gitg-branch.vala			\
	gitg-branch-base.vala			\
	gitg-repository.vala			\
	gitg-ref.vala				\
	gitg-ref-base.vala			\
	gitg-lane.vala				\
	gitg-lanes.vala				\
	gitg-color.vala				\
	gitg-init.vala				\
	gitg-commit.vala			\
	gitg-commit-model.vala			\
	gitg-label-renderer.vala		\
	gitg-cell-renderer-lanes.vala		\
	gitg-commit-list-view.vala		\
	gitg-diff-view.vala			\
	gitg-diff-view-request.vala		\
	gitg-diff-view-request-resource.vala	\
	gitg-diff-view-request-patch.vala	\
	gitg-diff-view-request-diff.vala	\
	gitg-repository-list-box.vala		\
	gitg-when-mapped.vala			\
	gitg-progress-bin.vala			\
	gitg-stage.vala				\
	gitg-stage-status-enumerator.vala	\
	gitg-sidebar.vala			\
	gitg-hook.vala				\
	gitg-date.vala				\
	gitg-avatar-cache.vala			\
	gitg-diff-stat.vala

# Ignore all warnings for vala code...
libgitg_1_0_la_CFLAGS =		\
	-w

libgitg_1_0_la_SOURCES = 		\
	gitg-resources.c		\
	$(VALA_FILES)

headerdir = $(prefix)/include/libgitg-1.0/libgitg
header_HEADERS = libgitg.h

vapidir = $(prefix)/share/vala/vapi
vapi_DATA = libgitg-1.0.vapi

girdir = $(INTROSPECTION_GIRDIR)
gir_DATA = Gitg-1.0.gir

typelibdir = $(INTROSPECTION_TYPELIBDIR)
typelib_DATA = Gitg-1.0.typelib

%.typelib: %.gir
	$(INTROSPECTION_COMPILER) $(INTROSPECTION_COMPILER_ARGS) --includedir=. -o $@ $<

pkgconfigdir = $(libdir)/pkgconfig
pkgconfig_DATA = libgitg-1.0.pc

gitg-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target="$@" --sourcedir=$(srcdir)/resources --generate-source $(srcdir)/resources/resources.xml

BUILT_SOURCES =				\
	$(gir_DATA)			\
	$(vapi_DATA)			\
	$(typelib_DATA)			\
	libgitg_1_0_la_vala.stamp	\
	gitg-resources.c		\
	libgitg.h

EXTRA_DIST = \
	$(pkgconfig_DATA)		\
	resources/resources.xml		\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)

CLEANFILES = $(VALA_FILES:.vala=.c)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
