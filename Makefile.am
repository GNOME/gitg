NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(LISTBOX_CFLAGS) \
	$(NULL)

AM_VALAFLAGS = \
	@LISTBOX_PACKAGES@ \
	--vapidir=. \
	$(NULL)

noinst_LTLIBRARIES = libegglistbox.la

libegglistbox_la_SOURCES = egg-list-box.c egg-list-box.h
libegglistbox_la_LIBADD = $(LISTBOX_LIBS)

noinst_PROGRAMS = test-list test-scrolled test-focus test-sel

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

CLEANFILES = \
	$(test_list_SOURCES:.vala=.c) \
	$(test_scrolled_SOURCES:.vala=.c) \
	*.stamp

EXTRA_DIST = \
	$(NULL)
