INCLUDES =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugindir = $(GITG_PLUGIN_LIBDIR)
plugin_LTLIBRARIES = libdash.la
plugin_DATA = dash.plugin

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)
VALA_SOURCES =								\
	gitg-dash.vala							\
	gitg-dash-navigation.vala

libdash_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)

libdash_la_LIBADD = $(GITG_PLUGIN_LIBS)
libdash_la_CFLAGS = -w

libdash_la_SOURCES = 				\
	$(VALA_SOURCES)				\
	gitg-dash-resources.c

BUILT_SOURCES = 						\
	gitg-dash-resources.c					\
	gitg-dash-resources.h

gitg-dash-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

gitg-dash-resources.h: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-header 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST = $(plugin_DATA)			\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)

CLEANFILES = 					\
	$(VALA_SOURCES:.vala=.c)		\
	$(BUILT_SOURCES)			\
	libdash_la_vala.stamp

install-data-hook:
	rm -f $(GITG_PLUGIN_LIBDIR)/libdash.la

-include $(top_srcdir)/git.mk
