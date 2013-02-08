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
