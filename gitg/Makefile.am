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

gitg_SOURCES = 		\
	gitg.c			\
	gitg-revision.c	\
	gitg-rv-model.c	\
	gitg-loader.c	\
	gitg-runner.c	\
	gitg-utils.c

gitg_LDADD = $(PACKAGE_LIBS)
gitg_LDFLAGS = 

uidir = $(datadir)/gitg/ui/
ui_DATA = gitg-ui.xml

update-ui:
	gtk-builder-convert gitg.glade gitg-ui.xml

EXTRA_DIST = 			\
	$(ui_DATA)
