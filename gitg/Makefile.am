bin_PROGRAMS = gitg

AM_CPPFLAGS =							\
	-I$(top_srcdir)						\
	-I$(srcdir)						\
	$(GITG_CFLAGS)						\
	$(PACKAGE_CFLAGS)					\
	$(WARN_CFLAGS)						\
	$(DISABLE_DEPRECATED_CFLAGS)				\
	-DDATADIR=\""$(datadir)"\"				\
	-DGITG_DATADIR=\""$(datadir)/gitg"\"			\
	-DGITG_LOCALEDIR=\""$(datadir)/locale"\"

NOINST_H_FILES = 			\
	gitg-branch-actions.h		\
	gitg-cell-renderer-path.h	\
	gitg-commit-view.h		\
	gitg-data-binding.h		\
	gitg-diff-line-renderer.h	\
	gitg-diff-view.h		\
	gitg-dirs.h			\
	gitg-dnd.h			\
	gitg-label-renderer.h		\
	gitg-preferences-dialog.h	\
	gitg-preferences.h		\
	gitg-repository-dialog.h	\
	gitg-revision-tree-store.h	\
	gitg-revision-tree-view.h	\
	gitg-revision-view.h		\
	gitg-settings.h			\
	gitg-utils.h			\
	gitg-window.h			\
	gseal-gtk-compat.h

gitg_SOURCES = 				\
	$(BUILT_SOURCES)		\
	gitg.c				\
	gitg-branch-actions.c		\
	gitg-cell-renderer-path.c	\
	gitg-commit-view.c		\
	gitg-data-binding.c		\
	gitg-diff-line-renderer.c	\
	gitg-diff-view.c		\
	gitg-dirs.c			\
	gitg-dnd.c			\
	gitg-label-renderer.c		\
	gitg-preferences.c		\
	gitg-preferences-dialog.c	\
	gitg-repository-dialog.c	\
	gitg-revision-tree-store.c	\
	gitg-revision-tree-view.c	\
	gitg-revision-view.c		\
	gitg-settings.c			\
	gitg-utils.c			\
	gitg-window.c			\
	$(NOINST_H_FILES)

gitg_LDADD =		\
	$(GITG_LIBS)	\
	$(PACKAGE_LIBS) \
	$(top_builddir)/libgitg/libgitg-1.0.la

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

EXTRA_DIST = 				\
	$(ui_DATA)

bundle: $(bin_PROGRAMS) $(ui_DATA)
	for i in $(SUBDIRS); do (cd $$i && $(MAKE) top_bundledir="$(top_bundledir)" $(AM_MAKEFLAGS) bundle); done; \
for i in $(bin_PROGRAMS); do $(INSTALL) -D $$i $(top_bundledir)/bin/$$i; done; \
for i in $(ui_DATA); do $(INSTALL) -D $$i $(top_bundledir)/resources/ui/$$i; done;

.PHONY: bundle

# vi:ts=8

-include $(top_srcdir)/git.mk
