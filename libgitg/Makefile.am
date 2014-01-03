lib_LTLIBRARIES = libgitg-1.0.la

libgitg_1_0_la_CPPFLAGS =				\
	-I$(top_srcdir)					\
	-I$(srcdir)					\
	-DDATADIR=\""$(datadir)"\"			\
	-DLIBDIR=\""$(libdir)"\"			\
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\"

libgitg_1_0_la_CFLAGS =		\
	$(LIBGITG_CFLAGS)	\
	$(WARN_CFLAGS)		\
	-w

libgitg_1_0_la_LDFLAGS = 		\
	-export-dynamic			\
	-no-undefined			\
	-export-symbols-regex "^[^_].*"

libgitg_1_0_la_LIBADD = $(LIBGITG_LIBS)

libgitg_1_0_la_VALAFLAGS =		\
	--pkg Ggit-1.0 			\
	--pkg gtk+-3.0			\
	--pkg gio-2.0			\
	--pkg libsoup-2.4		\
	--pkg webkit2gtk-3.0		\
	--pkg gee-0.8			\
	--pkg json-glib-1.0		\
	--pkg gio-unix-2.0		\
	--pkg gitg-js-utils		\
	$(GITG_VALAFLAGS)		\
	--vapidir $(top_srcdir)/vapi	\
	--header libgitg.h		\
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir Gitg-1.0.gir		\
	--vapi libgitg-1.0.vapi		\
	--library libgitg-1.0		\
	--gresources "$(top_srcdir)/libgitg/resources/resources.xml"

libgitg_1_0_la_VALA_FILES =			\
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

libgitg_1_0_la_SOURCES = 		\
	$(libgitg_1_0_la_VALA_FILES)	\
	gitg-resources.c		\
	gitg-js-utils.c

libgitg_1_0_la_headerdir = $(prefix)/include/libgitg-1.0/libgitg
libgitg_1_0_la_header_HEADERS = libgitg.h

noinst_HEADERS = gitg-js-utils.h

libgitg_1_0_la_vapidir = $(prefix)/share/vala/vapi
libgitg_1_0_la_vapi_DATA = libgitg-1.0.vapi

libgitg_1_0_la_girdir = $(INTROSPECTION_GIRDIR)
libgitg_1_0_la_gir_DATA = Gitg-1.0.gir

libgitg_1_0_la_typelibdir = $(INTROSPECTION_TYPELIBDIR)
libgitg_1_0_la_typelib_DATA = Gitg-1.0.typelib

%.typelib: %.gir
	$(INTROSPECTION_COMPILER) $(INTROSPECTION_COMPILER_ARGS) --includedir=. -o $@ $<

libgitg_1_0_la_pkgconfigdir = $(libdir)/pkgconfig
libgitg_1_0_la_pkgconfig_DATA = libgitg-1.0.pc

gitg-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)
	$(AM_V_GEN) $(GLIB_COMPILE_RESOURCES) --target="$@" --sourcedir=$(srcdir)/resources --generate-source $(srcdir)/resources/resources.xml

CLEANFILES = $(libgitg_1_0_la_typelib_DATA)

EXTRA_DIST =					\
	$(libgitg_1_0_la_pkgconfig_DATA)	\
	$(libgitg_1_0_la_gir_DATA)		\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
