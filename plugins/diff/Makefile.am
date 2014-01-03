SUBDIRS = icons

libdiff_la_CPPFLAGS =							\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

libdiff_la_CFLAGS =							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-w

libdiff_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)
libdiff_la_LIBADD = $(GITG_PLUGIN_LIBS)
libdiff_la_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

libdiff_la_VALASOURCES =						\
	gitg-diff.vala

libdiff_la_SOURCES = 							\
	$(libdiff_la_VALASOURCES)					\
	gitg-diff-resources.c

libdiff_la_plugindir = $(GITG_PLUGIN_LIBDIR)
libdiff_la_plugin_LTLIBRARIES = libdiff.la
libdiff_la_plugin_DATA = diff.plugin

gitg-diff-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST =					\
	$(libdiff_la_plugin_DATA)		\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
