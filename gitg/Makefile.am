bin_PROGRAMS = gitg

AM_CPPFLAGS =							\
	-I$(top_srcdir)						\
	-I$(srcdir)						\
	$(PACKAGE_CFLAGS)					\
	$(WARN_CFLAGS)						\
	$(DISABLE_DEPRECATED_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"				\
	-DGITG_DATADIR=\""$(datadir)/gitg"\"			\
	-DGITG_LOCALEDIR=\""$(datadir)/locale"\"

BUILT_SOURCES = 				\
	gitg-enum-types.c			\
	gitg-enum-types.h

NOINST_H_FILES = 			\
	gitg-branch-actions.h		\
	gitg-cell-renderer-path.h	\
	gitg-changed-file.h		\
	gitg-color.h			\
	gitg-config.h			\
	gitg-commit.h			\
	gitg-commit-view.h		\
	gitg-data-binding.h		\
	gitg-debug.h			\
	gitg-diff-line-renderer.h	\
	gitg-diff-view.h		\
	gitg-dirs.h			\
	gitg-dnd.h			\
	gitg-label-renderer.h		\
	gitg-lane.h			\
	gitg-lanes.h			\
	gitg-preferences-dialog.h	\
	gitg-preferences.h		\
	gitg-ref.h			\
	gitg-repository.h		\
	gitg-repository-dialog.h	\
	gitg-revision.h			\
	gitg-revision-tree-store.h	\
	gitg-revision-tree-view.h	\
	gitg-revision-view.h		\
	gitg-runner.h			\
	gitg-settings.h			\
	gitg-types.h			\
	gitg-utils.h			\
	gitg-window.h

gitg_SOURCES = 				\
	$(BUILT_SOURCES)		\
	gitg.c				\
	gitg-branch-actions.c		\
	gitg-cell-renderer-path.c	\
	gitg-changed-file.c		\
	gitg-color.c			\
	gitg-config.c			\
	gitg-commit.c			\
	gitg-commit-view.c		\
	gitg-data-binding.c		\
	gitg-debug.c			\
	gitg-diff-line-renderer.c	\
	gitg-diff-view.c		\
	gitg-dirs.c			\
	gitg-dnd.c			\
	gitg-label-renderer.c		\
	gitg-lane.c			\
	gitg-lanes.c			\
	gitg-preferences.c		\
	gitg-preferences-dialog.c	\
	gitg-ref.c			\
	gitg-repository.c		\
	gitg-repository-dialog.c	\
	gitg-revision.c			\
	gitg-revision-tree-store.c	\
	gitg-revision-tree-view.c	\
	gitg-revision-view.c		\
	gitg-runner.c			\
	gitg-settings.c			\
	gitg-utils.c			\
	gitg-window.c			\
	$(NOINST_H_FILES)

ENUM_H_FILES =				\
	gitg-changed-file.h

gitg_LDADD = $(PACKAGE_LIBS)
gitg_LDFLAGS = -export-dynamic -no-undefined -export-symbols-regex "^[[^_]].*"

uidir = $(datadir)/gitg/ui/
ui_DATA = \
	gitg-window.ui			\
	gitg-commit-menu.ui		\
	gitg-ui.xml 			\
	gitg-menus.xml			\
	gitg-preferences.ui		\
	gitg-tag.ui			\
	gitg-repository.ui

gitg-enum-types.h: gitg-enum-types.h.template $(ENUM_H_FILES) $(GLIB_MKENUMS)
	$(AM_V_GEN) (cd $(srcdir) && $(GLIB_MKENUMS) --template gitg-enum-types.h.template $(ENUM_H_FILES)) > $@
        
gitg-enum-types.c: gitg-enum-types.c.template $(ENUM_H_FILES) $(GLIB_MKENUMS)
	$(AM_V_GEN) (cd $(srcdir) && $(GLIB_MKENUMS) --template gitg-enum-types.c.template $(ENUM_H_FILES)) > $@

EXTRA_DIST = 				\
	$(ui_DATA)			\
	gitg-enum-types.h.template	\
	gitg-enum-types.c.template


CLEANFILES = $(BUILT_SOURCES)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)

bundle: $(bin_PROGRAMS) $(ui_DATA)
	for i in $(SUBDIRS); do (cd $$i && $(MAKE) top_bundledir="$(top_bundledir)" $(AM_MAKEFLAGS) bundle); done; \
for i in $(bin_PROGRAMS); do $(INSTALL) -D $$i $(top_bundledir)/bin/$$i; done; \
for i in $(ui_DATA); do $(INSTALL) -D $$i $(top_bundledir)/resources/ui/$$i; done;

.PHONY: bundle

# vi:ts=8

-include $(top_srcdir)/git.mk
