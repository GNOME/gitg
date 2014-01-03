lib_LTLIBRARIES = libgitg-ext-1.0.la

libgitg_ext_1_0_la_CPPFLAGS =			\
	-I$(top_srcdir)				\
	-I$(srcdir)				\
	-DDATADIR=\""$(datadir)"\"		\
	-DLIBDIR=\""$(libdir)"\"

libgitg_ext_1_0_la_CFLAGS =			\
	$(LIBGITG_EXT_CFLAGS)			\
	$(WARN_CFLAGS)				\
	-w

libgitg_ext_1_0_la_VALAPKGS =			\
	--pkg Ggit-1.0 				\
	--pkg libgitg-1.0			\
	--pkg gio-2.0				\
	--pkg gtk+-3.0				\
	--pkg libsoup-2.4			\
	--pkg webkit2gtk-3.0			\
	--pkg gee-0.8

libgitg_ext_1_0_la_VALAFLAGS = 			\
	$(libgitg_ext_1_0_la_VALAPKGS)		\
	--basedir $(top_srcdir)			\
	--vapidir $(top_srcdir)/vapi		\
	--vapidir $(top_builddir)/libgitg	\
	--gir GitgExt-1.0.gir			\
	--vapi libgitg-ext-1.0.vapi		\
	--girdir $(top_builddir)/libgitg	\
	--includedir libgitg-ext		\
	--header libgitg-ext.h			\
	--library libgitg-ext-1.0		\
	$(GITG_VALAFLAGS)

libgitg_ext_1_0_la_LDFLAGS = 			\
	-export-dynamic				\
	-no-undefined				\
	-export-symbols-regex "^[^_].*"

libgitg_ext_1_0_la_LIBADD = $(LIBGITG_EXT_LIBS)

libgitg_ext_1_0_la_VALA_FILES =			\
	gitg-ext-assembly-info.vala		\
	gitg-ext-application.vala		\
	gitg-ext-ui-element.vala		\
	gitg-ext-activity.vala			\
	gitg-ext-message-id.vala		\
	gitg-ext-message.vala			\
	gitg-ext-message-bus.vala		\
	gitg-ext-history.vala			\
	gitg-ext-history-panel.vala		\
	gitg-ext-command-line.vala		\
	gitg-ext-preferences.vala		\
	gitg-ext-ui.vala

libgitg_ext_1_0_la_SOURCES =			\
	$(libgitg_ext_1_0_la_VALA_FILES)	\
	gitg-ext-resources.c

headerdir = $(prefix)/include/libgitg-ext-1.0/libgitg-ext
header_DATA = libgitg-ext.h

vapidir = $(prefix)/share/vala/vapi
vapi_DATA = libgitg-ext-1.0.vapi

if ENABLE_DOCS
docs: $(VALA_FILES)
	$(VALADOC)				\
	--directory $(top_builddir)/docs	\
	--package-name gitgext			\
	$(libgitg_ext_1_0_la_VALAPKGS)		\
	--basedir $(top_srcdir)			\
	--vapidir $(top_srcdir)/vapi		\
	--vapidir $(top_builddir)/libgitg	\
	$(VALA_FILES)
else
docs:
endif

libgitg_ext_1_0_la_girdir = $(INTROSPECTION_GIRDIR)
libgitg_ext_1_0_la_gir_DATA = GitgExt-1.0.gir

libgitg_ext_1_0_la_typelibdir = $(INTROSPECTION_TYPELIBDIR)
libgitg_ext_1_0_la_typelib_DATA = GitgExt-1.0.typelib

%.typelib: %.gir
	$(INTROSPECTION_COMPILER) $(INTROSPECTION_COMPILER_ARGS) --includedir=. --includedir=$(top_srcdir)/libgitg -o $@ $<

if ENABLE_PYTHON
overridesdir = $(pyoverridesdir)
overrides_PYTHON = \
	GitgExt.py
endif

libgitg_ext_1_0_la_pkgconfigdir = $(libdir)/pkgconfig
libgitg_ext_1_0_la_pkgconfig_DATA = libgitg-ext-1.0.pc

gitg-ext-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

CLEANFILES = $(libgitg_ext_1_0_la_typelib_DATA)

EXTRA_DIST =					\
	$(libgitg_ext_1_0_la_pkgconfig_DATA)	\
	$(libgitg_ext_1_0_la_gir_DATA)		\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
