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

gsettings_SCHEMAS = org.gnome.gitg.gschema.xml

@INTLTOOL_XML_NOMERGE_RULE@

@GSETTINGS_RULES@

EXTRA_DIST =				\
	$(desktop_in_files)		\
	$(gitglangs_DATA)		\
	$(gitgstyles_DATA)		\
	$(man_MANS)			\
	org.gnome.gitg.gschema.xml.in.in

CLEANFILES =				\
	$(desktop_DATA)			\
	$(gsettings_SCHEMAS)

DISTCLEANFILES =			\
	$(desktop_DATA)			\
	$(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk
