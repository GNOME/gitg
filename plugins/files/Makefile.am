AM_CPPFLAGS =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugindir = $(GITG_PLUGIN_LIBDIR)
plugin_LTLIBRARIES = libfiles.la
plugin_DATA = files.plugin

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)
VALA_SOURCES =								\
	gitg-files.vala							\
	gitg-files-tree-store.vala

libfiles_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)

libfiles_la_LIBADD = $(GITG_PLUGIN_LIBS)
libfiles_la_CFLAGS = -w

libfiles_la_SOURCES = 				\
	$(VALA_SOURCES)				\
	gitg-files-resources.c

BUILT_SOURCES = 						\
	gitg-files-resources.c					\
	gitg-files-resources.h

gitg-files-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

gitg-files-resources.h: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-header 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST = $(plugin_DATA)			\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)

CLEANFILES = 					\
	$(VALA_SOURCES:.vala=.c)		\
	$(BUILT_SOURCES)			\
	libfiles_la_vala.stamp

install-data-hook:
	rm -f $(GITG_PLUGIN_LIBDIR)/libfiles.la

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
