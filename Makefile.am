NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(LISTBOX_CFLAGS) \
	$(NULL)

AM_VALAFLAGS = \
	@LISTBOX_PACKAGES@ \
	--vapidir=. \
	$(NULL)

noinst_LTLIBRARIES = \
	libegglistbox.la \
	libeggflowbox.la \
	$(NULL)

libegglistbox_la_SOURCES = \
	egg-list-box.c egg-list-box.h \
	egg-list-box-accessible.c egg-list-box-accessible.h

libegglistbox_la_LIBADD = $(LISTBOX_LIBS)

libeggflowbox_la_SOURCES = \
	egg-flow-box.c egg-flow-box.h

libeggflowbox_la_LIBADD = $(LISTBOX_LIBS)

noinst_PROGRAMS = test-list test-scrolled test-focus test-sel test-flow-box

test_sel_SOURCES = \
	test-sel.c \
	$(NULL)

test_sel_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_list_SOURCES = \
	test-list.vala \
	$(NULL)

test_list_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_list_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--pkg egglistbox \
	$(NULL)

test_scrolled_SOURCES = \
	test-scrolled.vala \
	$(NULL)

test_scrolled_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_scrolled_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--pkg egglistbox \
	$(NULL)

test_focus_SOURCES = \
	test-focus.c \
	$(NULL)

test_focus_LDADD = \
	$(LISTBOX_LIBS) \
	libegglistbox.la \
	$(NULL)

test_flow_box_SOURCES = \
	test-flow-box.c \
	$(NULL)

test_flow_box_LDADD = \
	$(LISTBOX_LIBS) \
	libeggflowbox.la \
	$(NULL)

CLEANFILES = \
	$(test_list_SOURCES:.vala=.c) \
	$(test_scrolled_SOURCES:.vala=.c) \
	*.stamp

EXTRA_DIST = \
	$(NULL)

include $(INTROSPECTION_MAKEFILE)
INTROSPECTION_GIRS =
INTROSPECTION_SCANNER_ARGS = --add-include-path=$(srcdir) --warn-all
INTROSPECTION_COMPILER_ARGS = --includedir=$(srcdir)

if HAVE_INTROSPECTION

Egg-1.0.gir: libegglistbox.la Makefile
Egg_1_0_gir_NAMESPACE = Egg
Egg_1_0_gir_VERSION = 1.0
Egg_1_0_gir_LIBS = libegglistbox.la libeggflowbox.la
Egg_1_0_gir_CFLAGS = $(LISTBOX_CFLAGS)
Egg_1_0_gir_SCANNERFLAGS =			\
       --warn-all				\
       --symbol-prefix=egg			\
       --identifier-prefix=Egg			\
       $(NULL)
Egg_1_0_gir_INCLUDES = GObject-2.0 Gtk-3.0
Egg_1_0_gir_FILES = $(libegglistbox_la_SOURCES) $(libeggflowbox_la_SOURCES)
INTROSPECTION_GIRS += Egg-1.0.gir

girdir= $(pkgdatadir)/gir-1.0
typelibdir= $(pkglibdir)/girepository-1.0

gir_DATA = $(INTROSPECTION_GIRS)
typelib_DATA = $(gir_DATA:.gir=.typelib)

CLEANFILES += $(gir_DATA) $(typelib_DATA)
MAINTAINERCLEANFILES = $(srcdir)/Egg-1.0.gir

endif
