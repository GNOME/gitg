SUBDIRS = icons

INCLUDES =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugindir = $(GITG_PLUGIN_LIBDIR)
plugin_LTLIBRARIES = libdiff.la
plugin_DATA = diff.plugin

VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)
VALA_SOURCES =								\
	gitg-diff.vala

libdiff_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)

libdiff_la_LIBADD = $(GITG_PLUGIN_LIBS)
libdiff_la_CFLAGS = -w

libdiff_la_SOURCES = 				\
	$(VALA_SOURCES)				\
	gitg-diff-resources.c

BUILT_SOURCES = 						\
	gitg-diff-resources.c					\
	gitg-diff-resources.h

gitg-diff-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

gitg-diff-resources.h: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-header 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST = $(plugin_DATA)			\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)

CLEANFILES = 					\
	$(VALA_SOURCES:.vala=.c)		\
	$(BUILT_SOURCES)			\
	libdiff_la_vala.stamp

install-data-hook:
	rm -f $(GITG_PLUGIN_LIBDIR)/libdiff.la

-include $(top_srcdir)/git.mk
