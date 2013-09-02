SUBDIRS = icons

desktopdir 	 = $(datadir)/applications
desktop_in_files = gitg.desktop.in
desktop_DATA 	 = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_DATA = gitg.appdata.xml

man_MANS = gitg.1

gsettings_SCHEMAS = org.gnome.gitg.gschema.xml

if GLADE_CATALOG
catalogdir = $(GLADE_CATALOG_DIR)
dist_catalog_DATA = gitg-glade.xml
endif

@INTLTOOL_XML_NOMERGE_RULE@

@GSETTINGS_RULES@

EXTRA_DIST =				\
	$(desktop_in_files)		\
	$(man_MANS)			\
	gitg.appdata.xml		\
	org.gnome.gitg.gschema.xml.in.in

CLEANFILES =				\
	$(desktop_DATA)			\
	$(gsettings_SCHEMAS)

DISTCLEANFILES =			\
	$(desktop_DATA)			\
	$(gsettings_SCHEMAS)

-include $(top_srcdir)/git.mk

# vi:ts=8:noet
