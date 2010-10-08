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
	gitg-activatable.h		\
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
	gitg-revision-panel.h		\
	gitg-revision-details-panel.h	\
	gitg-revision-files-panel.h	\
	gitg-revision-changes-panel.h	\
	gitg-settings.h			\
	gitg-stat-view.h		\
	gitg-uri.h			\
	gitg-utils.h			\
	gitg-window.h			\
	gseal-gtk-compat.h

gitg_SOURCES = 				\
	$(BUILT_SOURCES)		\
	gitg.c				\
	gitg-activatable.c		\
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
	gitg-revision-panel.c		\
	gitg-revision-details-panel.c	\
	gitg-revision-files-panel.c	\
	gitg-revision-changes-panel.c	\
	gitg-settings.c			\
	gitg-stat-view.c		\
	gitg-uri.c			\
	gitg-utils.c			\
	gitg-window.c			\
	$(NOINST_H_FILES)

if BUILD_SPINNER
gitg_SOURCES += gitg-spinner.c
NOINST_H_FILES += gitg-spinner.h
endif

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
	gitg-new-branch.ui		\
	gitg-tag.ui			\
	gitg-repository.ui		\
	gitg-revision-details-panel.ui	\
	gitg-revision-changes-panel.ui	\
	gitg-revision-files-panel.ui

EXTRA_DIST = 				\
	$(ui_DATA)

-include $(top_srcdir)/git.mk

# vi:ts=8
