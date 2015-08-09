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
	-export-symbols-regex "^[^_].*"

libgitg_libgitg_1_0_la_LIBADD = 	\
	$(LIBGITG_LIBS)

GITG_GIR_IN = Gitg_in-1.0.gir

libgitg_libgitg_1_0_la_VALAFLAGS =	\
	--pkg ggit-1.0 			\
	--pkg gtk+-3.0			\
	--pkg gio-2.0			\
	--pkg libsoup-2.4		\
	--pkg $(WEBKIT_PKGCONFIG)	\
	--pkg gee-0.8			\
	--pkg json-glib-1.0		\
	--pkg libsecret-1		\
	--pkg gio-unix-2.0		\
	--pkg gitg-js-utils		\
	--pkg gdesktop-enums-3.0	\
	$(GITG_VALAFLAGS)		\
	--vapidir $(top_srcdir)/vapi	\
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir $(GITG_GIR_IN)		\
	--vapi libgitg/libgitg-1.0.vapi	\
	--library libgitg/libgitg-1.0	\
	--header libgitg/libgitg.h	\
	--gresources "$(top_srcdir)/libgitg/resources/resources.xml"

Gitg-1.0.gir: $(GITG_GIR_IN)
	$(SED) \
		-e 's/<include name="WebKit2" version="[34].0"\/>/<include name="WebKit2" version="$(WEBKIT_MAJOR_VERSION).0"\/>/g' \
		-e 's/Gitg_in/Gitg/g' \
		$< >$@

libgitg_libgitg_1_0_la_VALASOURCES =			\
	libgitg/gitg-assembly-info.vala			\
	libgitg/gitg-async.vala				\
	libgitg/gitg-authentication-dialog.vala		\
	libgitg/gitg-avatar-cache.vala			\
	libgitg/gitg-branch-base.vala			\
	libgitg/gitg-branch.vala			\
	libgitg/gitg-cell-renderer-lanes.vala		\
	libgitg/gitg-color.vala				\
	libgitg/gitg-commit-list-view.vala		\
	libgitg/gitg-commit-model.vala			\
	libgitg/gitg-commit.vala			\
	libgitg/gitg-credentials-manager.vala		\
	libgitg/gitg-date.vala				\
	libgitg/gitg-diff-stat.vala			\
	libgitg/gitg-diff-view-options.vala		\
	libgitg/gitg-diff-view-request-diff.vala	\
	libgitg/gitg-diff-view-request-icon.vala	\
	libgitg/gitg-diff-view-request-resource.vala	\
	libgitg/gitg-diff-view-request.vala		\
	libgitg/gitg-diff-view.vala			\
	libgitg/gitg-hook.vala				\
	libgitg/gitg-init.vala				\
	libgitg/gitg-label-renderer.vala		\
	libgitg/gitg-lane.vala				\
	libgitg/gitg-lanes.vala				\
	libgitg/gitg-progress-bin.vala			\
	libgitg/gitg-ref-base.vala			\
	libgitg/gitg-ref.vala				\
	libgitg/gitg-remote.vala			\
	libgitg/gitg-remote-notification.vala		\
	libgitg/gitg-repository-list-box.vala		\
	libgitg/gitg-repository.vala			\
	libgitg/gitg-sidebar.vala			\
	libgitg/gitg-stage-status-enumerator.vala	\
	libgitg/gitg-stage.vala				\
	libgitg/gitg-utils.vala				\
	libgitg/gitg-when-mapped.vala

libgitg_libgitg_1_0_la_SOURCES = 		\
	$(libgitg_libgitg_1_0_la_VALASOURCES)	\
	libgitg/gitg-resources.c		\
	libgitg/gitg-js-utils.c

libgitg_libgitg_1_0_la_headerdir = $(prefix)/include/libgitg-1.0/libgitg
libgitg_libgitg_1_0_la_header_HEADERS = libgitg/libgitg.h

noinst_HEADERS += libgitg/gitg-js-utils.h

libgitg_libgitg_1_0_la_vapidir = $(prefix)/share/vala/vapi
libgitg_libgitg_1_0_la_vapi_DATA = libgitg/libgitg-1.0.vapi

libgitg_libgitg_1_0_la_girdir = $(datadir)/gir-1.0
libgitg_libgitg_1_0_la_gir_DATA = Gitg-1.0.gir

libgitg_libgitg_1_0_la_typelibdir = $(libdir)/girepository-1.0
libgitg_libgitg_1_0_la_typelib_DATA = Gitg-1.0.typelib

libgitg_libgitg_1_0_la_pkgconfigdir = $(libdir)/pkgconfig
libgitg_libgitg_1_0_la_pkgconfig_DATA = libgitg/libgitg-1.0.pc

libgitg_resources_deps = $(call GRESDEPS,libgitg/resources/resources.xml)
libgitg/gitg-resources.c: $(libgitg_resources_deps)
	$(GRESGEN)

GITIGNOREFILES +=					\
	$(GITG_GIR_IN)					\
	libgitg/libgitg.h

CLEANFILES +=						\
	$(libgitg_libgitg_1_0_la_typelib_DATA)		\
	$(libgitg_libgitg_1_0_la_gir_DATA)		\
	libgitg/gitg-resources.c

EXTRA_DIST +=						\
	$(libgitg_libgitg_1_0_la_pkgconfig_DATA)	\
	$(GITG_GIR_IN)					\
	$(libgitg_resources_deps)

# vi:ts=8:noet
