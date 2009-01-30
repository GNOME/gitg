bin_PROGRAMS = gitg

INCLUDES =							\
	-I$(top_srcdir)						\
	-I$(srcdir)						\
	$(PACKAGE_CFLAGS)					\
	$(WARN_CFLAGS)						\
	$(DISABLE_DEPRECATED_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"				\
	-DGITG_DATADIR=\""$(datadir)/gitg"\"			\
	-DGITG_LOCALEDIR=\""$(prefix)/$(DATADIRNAME)/locale"\"	\
	-DGITG_UI_DIR=\""$(datadir)/gitg/ui/"\"			\
	-DGITG_ICONDIR=\""$(datadir)/gitg/icons"\"

BUILT_SOURCES = 				\
	gitg-enum-types.c			\
	gitg-enum-types.h

gitg_SOURCES = 					\
	$(BUILT_SOURCES)			\
	gitg.c						\
	gitg-debug.c				\
	gitg-window.c				\
	gitg-ref.c					\
	gitg-revision.c				\
	gitg-revision-tree-view.c	\
	gitg-revision-tree-store.c	\
	gitg-repository.c			\
	gitg-cell-renderer-path.c	\
	gitg-label-renderer.c		\
	gitg-runner.c				\
	gitg-revision-view.c		\
	gitg-utils.c				\
	gitg-lane.c					\
	gitg-lanes.c				\
	gitg-color.c				\
	gitg-changed-file.c			\
	gitg-commit.c				\
	gitg-commit-view.c			\
	sexy-icon-entry.c

ENUM_H_FILES =					\
	gitg-changed-file.h

gitg_LDADD = $(PACKAGE_LIBS)
gitg_LDFLAGS = -export-dynamic -no-undefined -export-symbols-regex "^[[^_]].*"

uidir = $(datadir)/gitg/ui/
ui_DATA = gitg-ui.xml gitg-menus.xml

gitg-enum-types.h: gitg-enum-types.h.template $(ENUM_H_FILES) $(GLIB_MKENUMS)
	(cd $(srcdir) && $(GLIB_MKENUMS) --template gitg-enum-types.h.template $(ENUM_H_FILES)) > $@
        
gitg-enum-types.c: gitg-enum-types.c.template $(ENUM_H_FILES) $(GLIB_MKENUMS)
	(cd $(srcdir) && $(GLIB_MKENUMS) --template gitg-enum-types.c.template $(ENUM_H_FILES)) > $@

EXTRA_DIST = 			\
	$(ui_DATA)


CLEANFILES = $(BUILT_SOURCES)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)
