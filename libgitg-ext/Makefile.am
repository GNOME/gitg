libgitg_extexecdir = $(libdir)
libgitg_extexec_LTLIBRARIES = libgitg-ext/libgitg-ext-1.0.la

libgitg_ext_libgitg_ext_1_0_la_CPPFLAGS =	\
	-I$(top_srcdir)				\
	-I$(srcdir)				\
	-DDATADIR=\""$(datadir)"\"		\
	-DLIBDIR=\""$(libdir)"\"

libgitg_ext_libgitg_ext_1_0_la_CFLAGS =		\
	$(LIBGITG_EXT_CFLAGS)			\
	$(WARN_CFLAGS)				\
	-w

libgitg_ext_libgitg_ext_1_0_la_VALAPKGS =	\
	--pkg Ggit-1.0 				\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg libsoup-2.4			\
	--pkg webkit2gtk-3.0			\
	--pkg gee-0.8

libgitg_ext_libgitg_ext_1_0_la_VALAFLAGS =		\
	$(libgitg_ext_libgitg_ext_1_0_la_VALAPKGS)	\
	--basedir $(top_srcdir)				\
	--vapidir $(top_srcdir)/vapi			\
	--gir GitgExt-1.0.gir				\
	--vapi libgitg-ext/libgitg-ext-1.0.vapi		\
	--girdir $(top_builddir)/libgitg		\
	--includedir libgitg-ext			\
	--header libgitg-ext/libgitg-ext.h		\
	--library libgitg-ext/libgitg-ext-1.0		\
	$(GITG_VALAFLAGS)

libgitg_ext_libgitg_ext_1_0_la_LDFLAGS = 	\
	-export-dynamic				\
	-no-undefined				\
	-export-symbols-regex "^[^_].*"		\
	$(LIBGITG_EXT_LIBS)

libgitg_ext_libgitg_ext_1_0_la_LIBADD = 	\
	libgitg/libgitg-1.0.la

libgitg_ext_libgitg_ext_1_0_la_VALASOURCES =		\
	libgitg-ext/gitg-ext-assembly-info.vala		\
	libgitg-ext/gitg-ext-application.vala		\
	libgitg-ext/gitg-ext-ui-element.vala		\
	libgitg-ext/gitg-ext-activity.vala		\
	libgitg-ext/gitg-ext-message-id.vala		\
	libgitg-ext/gitg-ext-message.vala		\
	libgitg-ext/gitg-ext-message-bus.vala		\
	libgitg-ext/gitg-ext-history.vala		\
	libgitg-ext/gitg-ext-history-panel.vala		\
	libgitg-ext/gitg-ext-command-line.vala		\
	libgitg-ext/gitg-ext-preferences.vala		\
	libgitg-ext/gitg-ext-ui.vala			\
	libgitg/libgitg-1.0.vapi

libgitg_ext_libgitg_ext_1_0_la_SOURCES =		\
	$(libgitg_ext_libgitg_ext_1_0_la_VALASOURCES)	\
	libgitg-ext/gitg-ext-resources.c

libgitg_ext_libgitg_ext_1_0_headerdir = $(prefix)/include/libgitg-ext-1.0/libgitg-ext
libgitg_ext_libgitg_ext_1_0_header_DATA = libgitg-ext/libgitg-ext.h

libgitg_ext_libgitg_ext_1_0_vapidir = $(prefix)/share/vala/vapi
libgitg_ext_libgitg_ext_1_0_vapi_DATA = libgitg-ext/libgitg-ext-1.0.vapi

if ENABLE_DOCS
libgitg-ext-docs: $(libgitg_ext_libgitg_ext_1_0_la_VALASOURCES)
	$(VALADOC)					\
	--directory $(top_builddir)/docs		\
	--package-name gitgext				\
	$(libgitg_ext_libgitg_ext_1_0_la_VALAPKGS)	\
	--basedir $(top_srcdir)				\
	--vapidir $(top_srcdir)/vapi			\
	--vapidir $(top_builddir)/libgitg		\
	$(libgitg_ext_libgitg_ext_1_0_la_VALASOURCES)

docs: libgitg-ext-docs
endif

libgitg_ext_libgitg_ext_1_0_la_girdir = $(INTROSPECTION_GIRDIR)
libgitg_ext_libgitg_ext_1_0_la_gir_DATA = GitgExt-1.0.gir

libgitg_ext_libgitg_ext_1_0_la_typelibdir = $(INTROSPECTION_TYPELIBDIR)
libgitg_ext_libgitg_ext_1_0_la_typelib_DATA = GitgExt-1.0.typelib

if ENABLE_PYTHON
libgitg_ext_libgitg_ext_1_0_la_overridesdir = $(pyoverridesdir)
libgitg_ext_libgitg_ext_1_0_la_overrides_PYTHON = libgitg-ext/GitgExt.py
endif

libgitg_ext_libgitg_ext_1_0_la_pkgconfigdir = $(libdir)/pkgconfig
libgitg_ext_libgitg_ext_1_0_la_pkgconfig_DATA = libgitg-ext/libgitg-ext-1.0.pc

libgitg_ext_resources_deps = $(call GRESDEPS,libgitg-ext/resources/resources.xml)
libgitg-ext/gitg-ext-resources.c: $(libgitg_ext_resources_deps)
	$(GRESGEN)

GITIGNOREFILES +=							\
	libgitg-ext/gitg-ext-resources.c				\
	$(libgitg_ext_libgitg_ext_1_0_la_gir_DATA)			\
	libgitg-ext/libgitg-ext.h

CLEANFILES +=								\
	$(libgitg_ext_libgitg_ext_1_0_la_typelib_DATA)

EXTRA_DIST +=								\
	$(libgitg_ext_libgitg_ext_1_0_la_pkgconfig_DATA)		\
	$(libgitg_ext_libgitg_ext_1_0_la_gir_DATA)			\
	$(libgitg_ext_resources_deps)

# This is a hack to make parallel install work. libtool needs to relink at
# install (on some platforms) which requires dependency libraries to be
# already installed. automake does not generate the appropriate dependency
# so we do it here automatically. As an additional bonus, we have to trick
# automake using a variable indirection for the rule because it would otherwise
# omit the default install rule.
install_libgitg_extexecLTLIBRARIES = install-libgitg_extexecLTLIBRARIES
$(install_libgitg_extexecLTLIBRARIES): install-libgitgexecLTLIBRARIES

# vi:ts=8:noet
