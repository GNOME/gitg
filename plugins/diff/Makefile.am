plugins_diff_libdiff_la_pluginexecdir = $(GITG_PLUGIN_LIBDIR)
plugins_diff_libdiff_la_pluginexec_LTLIBRARIES = plugins/diff/libdiff.la

plugins_diff_libdiff_la_plugindatadir = $(GITG_PLUGIN_LIBDIR)
plugins_diff_libdiff_la_plugindata_DATA = plugins/diff/diff.plugin

plugins_diff_libdiff_la_CPPFLAGS =					\
	-I$(top_srcdir)							\
	-I$(srcdir)							\
	-DDATADIR=\""$(datadir)"\"					\
	-DLIBDIR=\""$(libdir)"\"

plugins_diff_libdiff_la_CFLAGS =					\
	$(GITG_PLUGIN_CFLAGS)						\
	$(WARN_CFLAGS)							\
	-w

plugins_diff_libdiff_la_LDFLAGS = $(GITG_PLUGIN_LIBTOOL_FLAGS) $(GITG_PLUGIN_LIBS)

plugins_diff_libdiff_la_LIBADD = 					\
	libgitg/libgitg-1.0.la 						\
	libgitg-ext/libgitg-ext-1.0.la

plugins_diff_libdiff_la_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS)

plugins_diff_libdiff_la_VALASOURCES =					\
	plugins/diff/gitg-diff.vala

plugins_diff_libdiff_la_SOURCES = 					\
	$(plugins_diff_libdiff_la_VALASOURCES)				\
	plugins/diff/gitg-diff-resources.c				\
	$(GITG_PLUGIN_VAPISOURCES)

plugins_diff_libdiff_resources_deps = $(call GRESDEPS,plugins/diff/resources/resources.xml)
plugins/diff/gitg-diff-resources.c: $(plugins_diff_libdiff_resources_deps)
	$(GRESGEN)

CLEANFILES +=					\
	plugins/diff/gitg-diff-resources.c

EXTRA_DIST +=						\
	$(plugins_diff_libdiff_la_plugindata_DATA)	\
	$(plugins_diff_libdiff_resources_deps)

SCALABLE_ICONS += plugins/diff/icons/diff-symbolic.svg

# This is a hack to make parallel install work. libtool needs to relink at
# install (on some platforms) which requires dependency libraries to be
# already installed. automake does not generate the appropriate dependency
# so we do it here automatically. As an additional bonus, we have to trick
# automake using a variable indirection for the rule because it would otherwise
# omit the default install rule.
install_plugins_diff_libdiff_la_pluginexecLTLIBRARIES = install-plugins_diff_libdiff_la_pluginexecLTLIBRARIES
$(install_plugins_diff_libdiff_la_pluginexecLTLIBRARIES): install-libgitg_extexecLTLIBRARIES

# vi:ts=8:noet
