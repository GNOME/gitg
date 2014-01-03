libfiles_la_CPPFLAGS =							\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

libfiles_la_CFLAGS = 							\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-w

libfiles_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)
libfiles_la_LIBADD = $(GITG_PLUGIN_LIBS)
libfiles_la_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

libfiles_la_VALASOURCES =						\
	gitg-files.vala							\
	gitg-files-tree-store.vala

libfiles_la_SOURCES = 							\
	$(libfiles_la_VALASOURCES)					\
	gitg-files-resources.c

libfiles_la_plugindir = $(GITG_PLUGIN_LIBDIR)
libfiles_la_plugin_LTLIBRARIES = libfiles.la
libfiles_la_plugin_DATA = files.plugin

gitg-files-resources.c: resources/resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

EXTRA_DIST =					\
	$(libfiles_la_plugin_DATA)		\
	resources/resources.xml			\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources $(srcdir)/resources/resources.xml)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
