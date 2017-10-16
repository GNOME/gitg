libgitgexecdir = $(libdir)
libgitgexec_LTLIBRARIES = libgitg/libgitg-1.0.la

libgitg_libgitg_1_0_la_CPPFLAGS =			\
	-I$(top_srcdir)					\
	-I$(srcdir)					\
	-I$(top_srcdir)/contrib/ide			\
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
	$(LIBGITG_LIBS)			\
	contrib/ide/libide.la

if GDK_WINDOWING_QUARTZ
libgitg_libgitg_1_0_la_LIBADD += -lobjc
libgitg_libgitg_1_0_la_CFLAGS += -xobjective-c
libgitg_libgitg_1_0_la_LDFLAGS += -framework Foundation -framework AppKit
endif

libgitg_libgitg_1_0_la_VALAFLAGS =	\
	--pkg ggit-1.0 			\
	--pkg gtk+-3.0			\
	--pkg gio-2.0			\
	--pkg $(GIO_SYSTEM_PKG)		\
	--pkg gee-0.8			\
	--pkg libsecret-1		\
	--pkg gsettings-desktop-schemas	\
	--pkg libsoup-2.4		\
	--pkg gtksourceview-3.0		\
	--pkg gitg-platform-support	\
	--pkg ide			\
	$(GITG_VALAFLAGS)		\
	--vapidir $(top_srcdir)/vapi	\
	--vapidir $(top_srcdir)/contrib/ide \
	--includedir libgitg		\
	--basedir $(top_srcdir)		\
	--gir Gitg-1.0.gir		\
	--vapi libgitg/libgitg-1.0.vapi	\
	--library libgitg/libgitg-1.0	\
	--header libgitg/libgitg.h	\
	--gresources "$(top_srcdir)/libgitg/resources/resources.xml"

libgitg_libgitg_1_0_la_VALASOURCES =				\
	libgitg/gitg-assembly-info.vala				\
	libgitg/gitg-async.vala					\
	libgitg/gitg-authentication-dialog.vala			\
	libgitg/gitg-avatar-cache.vala				\
	libgitg/gitg-branch-base.vala				\
	libgitg/gitg-branch.vala				\
	libgitg/gitg-cell-renderer-lanes.vala			\
	libgitg/gitg-color.vala					\
	libgitg/gitg-commit-list-view.vala			\
	libgitg/gitg-commit-model.vala				\
	libgitg/gitg-commit.vala				\
	libgitg/gitg-credentials-manager.vala			\
	libgitg/gitg-date.vala					\
	libgitg/gitg-diff-stat.vala				\
	libgitg/gitg-diff-image-composite.vala			\
	libgitg/gitg-diff-image-difference.vala			\
	libgitg/gitg-diff-image-overlay.vala			\
	libgitg/gitg-diff-image-side-by-side.vala		\
	libgitg/gitg-diff-image-slider.vala			\
	libgitg/gitg-diff-image-surface-cache.vala		\
	libgitg/gitg-diff-view.vala				\
	libgitg/gitg-diff-view-file.vala			\
	libgitg/gitg-diff-view-file-info.vala			\
	libgitg/gitg-diff-view-file-selectable.vala		\
	libgitg/gitg-diff-view-file-renderer.vala		\
	libgitg/gitg-diff-view-file-renderer-binary.vala	\
	libgitg/gitg-diff-view-file-renderer-text.vala		\
	libgitg/gitg-diff-view-file-renderer-image.vala		\
	libgitg/gitg-diff-view-lines-renderer.vala		\
	libgitg/gitg-diff-selectable.vala			\
	libgitg/gitg-diff-view-commit-details.vala		\
	libgitg/gitg-diff-view-options.vala			\
	libgitg/gitg-hook.vala					\
	libgitg/gitg-init.vala					\
	libgitg/gitg-label-renderer.vala			\
	libgitg/gitg-lane.vala					\
	libgitg/gitg-lanes.vala					\
	libgitg/gitg-progress-bin.vala				\
	libgitg/gitg-ref-base.vala				\
	libgitg/gitg-ref.vala					\
	libgitg/gitg-remote.vala				\
	libgitg/gitg-repository-list-box.vala			\
	libgitg/gitg-repository.vala				\
	libgitg/gitg-resource.vala				\
	libgitg/gitg-sidebar.vala				\
	libgitg/gitg-stage-status-enumerator.vala		\
	libgitg/gitg-stage.vala					\
	libgitg/gitg-utils.vala					\
	libgitg/gitg-when-mapped.vala

libgitg_libgitg_1_0_la_SOURCES = 				\
	$(libgitg_libgitg_1_0_la_VALASOURCES)			\
	libgitg/gitg-resources.c

if PLATFORM_WIN32
libgitg_libgitg_1_0_la_SOURCES += libgitg/gitg-platform-support-win32.c
else
if PLATFORM_OSX
libgitg_libgitg_1_0_la_SOURCES += libgitg/gitg-platform-support-osx.c
else
libgitg_libgitg_1_0_la_SOURCES += libgitg/gitg-platform-support.c
endif
endif

libgitg_libgitg_1_0_la_headerdir = $(prefix)/include/libgitg-1.0/libgitg
libgitg_libgitg_1_0_la_header_HEADERS = libgitg/libgitg.h

noinst_HEADERS += libgitg/gitg-platform-support.h

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
	$(libgitg_libgitg_1_0_la_gir_DATA)		\
	libgitg/libgitg.h

CLEANFILES +=						\
	$(libgitg_libgitg_1_0_la_typelib_DATA)		\
	libgitg/gitg-resources.c

EXTRA_DIST +=						\
	$(libgitg_libgitg_1_0_la_pkgconfig_DATA)	\
	$(libgitg_libgitg_1_0_la_gir_DATA)		\
	$(libgitg_resources_deps)

# vi:ts=8:noet
