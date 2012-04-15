INCLUDES =								\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugindir = $(GITG_PLUGIN_LIBDIR)
plugin_LTLIBRARIES = libhistory.la
plugin_DATA = history.plugin

VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)
VALA_SOURCES =								\
	gitg-history.vala						\
	gitg-history-navigation.vala

libhistory_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)
libhistory_la_LIBADD = $(GITG_PLUGIN_LIBS)
libhistory_la_CFLAGS = -w

libhistory_la_SOURCES = 			\
	$(VALA_SOURCES)				\
	gitg-history-resources.c

BUILT_SOURCES = 				\
	gitg-history-resources.c		\
	gitg-history-resources.h

gitg-history-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

gitg-history-resources.h: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-header 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST = $(plugin_DATA)			\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/resources.xml)

CLEANFILES = 					\
	$(VALA_SOURCES:.vala=.c)		\
	$(BUILT_SOURCES)

install-data-hook:
	rm -f $(GITG_PLUGIN_LIBDIR)/libhistory.la

-include $(top_srcdir)/git.mk
