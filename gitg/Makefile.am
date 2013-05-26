bin_PROGRAMS = gitg

AM_CPPFLAGS =							\
	-I$(top_srcdir)						\
	-I$(srcdir)						\
	-I$(top_srcdir)/libgd					\
	$(GITG_CFLAGS)						\
	$(WARN_CFLAGS)						\
	-DDATADIR=\""$(datadir)"\"				\
	-DGITG_DATADIR=\""$(datadir)/gitg"\"			\
	-DGITG_LOCALEDIR=\""$(datadir)/locale"\"

AM_VALAFLAGS = \
	--vapidir $(top_srcdir)/vapi				\
	$(GITG_VALAFLAGS)					\
	--pkg config						\
	--pkg Ggit-1.0						\
	--pkg libgitg-1.0					\
	--pkg libgitg-ext-1.0					\
	--pkg libgitg-gtk-1.0					\
	--pkg gtk+-3.0						\
	--pkg gio-2.0						\
	--pkg libpeas-1.0					\
	--pkg gobject-introspection-1.0				\
	--pkg gee-0.8						\
	--pkg gd-1.0						\
	--pkg webkit2gtk-3.0					\
	--girdir "$(top_builddir)/libgd"			\
	--girdir "$(top_builddir)/libgitg"			\
	--girdir "$(top_builddir)/libgitg-ext"			\
	--girdir "$(top_builddir)/libgitg-gtk"			\
	--vapidir "$(top_srcdir)/vapi"				\
	--vapidir "$(top_builddir)/libgd"			\
	--vapidir "$(top_builddir)/libgitg"			\
	--vapidir "$(top_builddir)/libgitg-ext"			\
	--vapidir "$(top_builddir)/libgitg-gtk"

VALASOURCES =							\
	gitg.vala						\
	gitg-dirs.vala						\
	gitg-window.vala					\
	gitg-resource.vala					\
	gitg-application.vala					\
	gitg-plugins-engine.vala				\
	gitg-ui-elements.vala					\
	gitg-preferences-dialog.vala				\
	gitg-preferences-interface.vala

BUILT_SOURCES = 						\
	gitg-resources.c					\
	gitg-resources.h					\
	gitg_vala.stamp

gitg_SOURCES =							\
	$(VALASOURCES)						\
	gitg-resources.c

gitg_LDADD =							\
	$(GITG_LIBS)						\
	$(PACKAGE_LIBS) 					\
	$(top_builddir)/libgd/libgd.la				\
	$(top_builddir)/libgitg/libgitg-1.0.la			\
	$(top_builddir)/libgitg-ext/libgitg-ext-1.0.la		\
	$(top_builddir)/libgitg-gtk/libgitg-gtk-1.0.la

gitg_LDFLAGS = -export-dynamic -no-undefined -export-symbols-regex "^[[^_]].*"

gitg-resources.c: resources/gitg-resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/gitg-resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-source 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

gitg-resources.h: resources/gitg-resources.xml $(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/gitg-resources.xml)
	$(GLIB_COMPILE_RESOURCES) --generate-header 	\
		--sourcedir $(srcdir)/resources 	\
		--target "$@" "$<"

# Ignore all warnings for vala code...
gitg_CFLAGS = \
	-w

EXTRA_DIST = 				\
	resources/gitg-resources.xml		\
	$(shell $(GLIB_COMPILE_RESOURCES) --generate-dependencies --sourcedir $(srcdir)/resources resources/gitg-resources.xml)

CLEANFILES = 				\
	$(VALASOURCES:.vala=.c)		\
	$(BUILT_SOURCES)

-include $(top_srcdir)/git.mk

# vi:ts=8
