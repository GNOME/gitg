plugins_files_libfiles_la_plugindir = $(GITG_PLUGIN_LIBDIR)
plugins_files_libfiles_la_plugin_LTLIBRARIES = plugins/files/libfiles.la
plugins_files_libfiles_la_plugin_DATA = plugins/files/files.plugin

plugins_files_libfiles_la_CPPFLAGS =					\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugins_files_libfiles_la_CFLAGS = 					\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-w

plugins_files_libfiles_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS)
plugins_files_libfiles_la_LIBADD = $(GITG_PLUGIN_LIBS)
plugins_files_libfiles_la_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

plugins_files_libfiles_la_VALASOURCES =					\
	plugins/files/gitg-files.vala					\
	plugins/files/gitg-files-tree-store.vala

plugins_files_libfiles_la_SOURCES = 					\
	$(plugins_files_libfiles_la_VALASOURCES)			\
	plugins/files/gitg-files-resources.c

plugins_files_libfiles_resources_deps = $(call GRESDEPS,plugins/files/resources/resources.xml)
plugins/files/gitg-files-resources.c: $(plugins_files_libfiles_resources_deps)
	$(GRESGEN)

GITIGNOREFILES +=						\
	$(plugins_files_libfiles_la_VALASOURCES:%.vala=%.c)	\
	plugins_files_libfiles_la_vala.stamp

CLEANFILES +=							\
	plugins/files/gitg-files-resources.c

EXTRA_DIST +=							\
	$(plugins_files_libfiles_la_plugin_DATA)		\
	$(plugins_files_libfiles_resources_deps)

# vi:ts=8:noet
