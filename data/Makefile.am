SUBDIRS = icons

desktopdir 	 = $(datadir)/applications
desktop_in_files = gitg.desktop.in
desktop_DATA 	 = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

man_MANS = gitg.1

gitglangsdir = $(datadir)/gitg/language-specs
gitglangs_DATA = gitgdiff.lang

gitgstylesdir = $(datadir)/gitg/styles
gitgstyles_DATA = gitgstyle.xml

EXTRA_DIST = 				\
	$(desktop_in_files)		\
	$(gitglangs_DATA)		\
	$(gitgstyles_DATA)		\
	$(man_MANS)

CLEANFILES =	 			\
	$(desktop_DATA)

