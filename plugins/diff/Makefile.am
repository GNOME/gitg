plugins_diff_libdiff_la_plugindir = $(GITG_PLUGIN_LIBDIR)
plugins_diff_libdiff_la_plugin_LTLIBRARIES = plugins/diff/libdiff.la
plugins_diff_libdiff_la_plugin_DATA = plugins/diff/diff.plugin

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

GITIGNOREFILES +=						\
	$(plugins_diff_libdiff_la_VALASOURCES:%.vala=%.c)	\
	plugins_diff_libdiff_la_vala.stamp

CLEANFILES +=					\
	plugins/diff/gitg-diff-resources.c

EXTRA_DIST +=						\
	$(plugins_diff_libdiff_la_plugin_DATA)		\
	$(plugins_diff_libdiff_resources_deps)

SCALABLE_ICONS += plugins/diff/icons/diff-symbolic.svg

# vi:ts=8:noet
