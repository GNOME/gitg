data_desktopdir = $(datadir)/applications
data_desktop_in_files = data/gitg.desktop.in
data_desktop_DATA = $(data_desktop_in_files:.desktop.in=.desktop)

data_appdatadir = $(datadir)/appdata
data_appdata_DATA = data/gitg.appdata.xml

dist_man_MANS = data/gitg.1

gsettings_SCHEMAS += data/org.gnome.gitg.gschema.xml

if GLADE_CATALOG
data_catalogdir = $(GLADE_CATALOG_DIR)
dist_data_catalog_DATA = data/gitg-glade.xml
endif

EXTRA_DIST +=					\
	$(data_desktop_in_files)		\
	data/gitg.appdata.xml			\
	data/org.gnome.gitg.gschema.xml.in.in

CLEANFILES += 					\
	$(data_desktop_DATA)			\
	data/org.gnome.gitg.gschema.xml

DISTCLEANFILES +=				\
	$(data_desktop_DATA)			\
	data/org.gnome.gitg.gschema.xml

include data/icons/Makefile.am

# vi:ts=8:noet
