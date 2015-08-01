plugins_files_libfiles_la_pluginexecdir = $(GITG_PLUGIN_LIBDIR)
plugins_files_libfiles_la_pluginexec_LTLIBRARIES = plugins/files/libfiles.la

plugins_files_libfiles_la_plugindatadir = $(GITG_PLUGIN_LIBDIR)
plugins_files_libfiles_la_plugindata_DATA = plugins/files/files.plugin

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

plugins_files_libfiles_la_LIBADD = 					\
	libgitg/libgitg-1.0.la 						\
	libgitg-ext/libgitg-ext-1.0.la					\
	$(GITG_PLUGIN_LIBS)

plugins_files_libfiles_la_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

plugins_files_libfiles_la_VALASOURCES =					\
	plugins/files/gitg-files.vala					\
	plugins/files/gitg-files-tree-store.vala			\
	$(GITG_PLUGIN_VAPISOURCES)

plugins_files_libfiles_la_SOURCES = 					\
	$(plugins_files_libfiles_la_VALASOURCES)			\
	plugins/files/gitg-files-resources.c

plugins_files_libfiles_resources_deps = $(call GRESDEPS,plugins/files/resources/resources.xml)
plugins/files/gitg-files-resources.c: $(plugins_files_libfiles_resources_deps)
	$(GRESGEN)

CLEANFILES +=							\
	plugins/files/gitg-files-resources.c

EXTRA_DIST +=							\
	$(plugins_files_libfiles_la_plugindata_DATA)		\
	$(plugins_files_libfiles_resources_deps)

# This is a hack to make parallel install work. libtool needs to relink at
# install (on some platforms) which requires dependency libraries to be
# already installed. automake does not generate the appropriate dependency
# so we do it here automatically. As an additional bonus, we have to trick
# automake using a variable indirection for the rule because it would otherwise
# omit the default install rule.
install_plugins_files_libfiles_la_pluginexecLTLIBRARIES = install-plugins_files_libfiles_la_pluginexecLTLIBRARIES
$(install_plugins_files_libfiles_la_pluginexecLTLIBRARIES): install-libgitg_extexecLTLIBRARIES

# vi:ts=8:noet
