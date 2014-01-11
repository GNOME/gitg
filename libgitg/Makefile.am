libgitgexecdir = $(libdir)
libgitgexec_LTLIBRARIES = libgitg/libgitg-1.0.la

libgitg_libgitg_1_0_la_CPPFLAGS =			\
	-I$(top_srcdir)					\
	-I$(srcdir)					\
	-DDATADIR=\""$(datadir)"\"			\
	-DLIBDIR=\""$(libdir)"\"			\
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\"

libgitg_libgitg_1_0_la_CFLAGS =		\
	$(LIBGITG_CFLAGS)		\
	$(WARN_CFLAGS)			\
	-w

libgitg_libgitg_1_0_la_LDFLAGS = 	\
	-export-dynamic			\
	-no-undefined			\
	-export-symbols-regex "^[^_].*"	\
	$(LIBGITG_LIBS)

libgitg_libgitg_1_0_la_VALAFLAGS =	\
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
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir Gitg-1.0.gir		\
	--vapi libgitg/libgitg-1.0.vapi	\
	--library libgitg/libgitg-1.0	\
	--header libgitg/libgitg.h	\
	--gresources "$(top_srcdir)/libgitg/resources/resources.xml"

libgitg_libgitg_1_0_la_VALASOURCES =			\
	libgitg/gitg-assembly-info.vala			\
	libgitg/gitg-async.vala				\
	libgitg/gitg-branch.vala			\
	libgitg/gitg-branch-base.vala			\
	libgitg/gitg-repository.vala			\
	libgitg/gitg-ref.vala				\
	libgitg/gitg-ref-base.vala			\
	libgitg/gitg-lane.vala				\
	libgitg/gitg-lanes.vala				\
	libgitg/gitg-color.vala				\
	libgitg/gitg-init.vala				\
	libgitg/gitg-commit.vala			\
	libgitg/gitg-commit-model.vala			\
	libgitg/gitg-label-renderer.vala		\
	libgitg/gitg-cell-renderer-lanes.vala		\
	libgitg/gitg-commit-list-view.vala		\
	libgitg/gitg-diff-view.vala			\
	libgitg/gitg-diff-view-request.vala		\
	libgitg/gitg-diff-view-request-resource.vala	\
	libgitg/gitg-diff-view-request-patch.vala	\
	libgitg/gitg-diff-view-request-diff.vala	\
	libgitg/gitg-repository-list-box.vala		\
	libgitg/gitg-when-mapped.vala			\
	libgitg/gitg-progress-bin.vala			\
	libgitg/gitg-stage.vala				\
	libgitg/gitg-stage-status-enumerator.vala	\
	libgitg/gitg-sidebar.vala			\
	libgitg/gitg-hook.vala				\
	libgitg/gitg-date.vala				\
	libgitg/gitg-avatar-cache.vala			\
	libgitg/gitg-diff-stat.vala

libgitg_libgitg_1_0_la_SOURCES = 		\
	$(libgitg_libgitg_1_0_la_VALASOURCES)	\
	libgitg/gitg-resources.c		\
	libgitg/gitg-js-utils.c

libgitg_libgitg_1_0_la_headerdir = $(prefix)/include/libgitg-1.0/libgitg
libgitg_libgitg_1_0_la_header_HEADERS = libgitg/libgitg.h

noinst_HEADERS += libgitg/gitg-js-utils.h

libgitg_libgitg_1_0_la_vapidir = $(prefix)/share/vala/vapi
libgitg_libgitg_1_0_la_vapi_DATA = libgitg/libgitg-1.0.vapi

libgitg_libgitg_1_0_la_girdir = $(INTROSPECTION_GIRDIR)
libgitg_libgitg_1_0_la_gir_DATA = Gitg-1.0.gir

libgitg_libgitg_1_0_la_typelibdir = $(INTROSPECTION_TYPELIBDIR)
libgitg_libgitg_1_0_la_typelib_DATA = Gitg-1.0.typelib

libgitg_libgitg_1_0_la_pkgconfigdir = $(libdir)/pkgconfig
libgitg_libgitg_1_0_la_pkgconfig_DATA = libgitg/libgitg-1.0.pc

libgitg_resources_deps = $(call GRESDEPS,libgitg/resources/resources.xml)
libgitg/gitg-resources.c: $(libgitg_resources_deps)
	$(GRESGEN)

GITIGNOREFILES +=						\
	$(libgitg_libgitg_1_0_la_gir_DATA)			\
	libgitg/libgitg.h

CLEANFILES +=						\
	$(libgitg_libgitg_1_0_la_typelib_DATA)		\
	libgitg/gitg-resources.c

EXTRA_DIST +=						\
	$(libgitg_libgitg_1_0_la_pkgconfig_DATA)	\
	$(libgitg_libgitg_1_0_la_gir_DATA)		\
	$(libgitg_resources_deps)

# vi:ts=8:noet
