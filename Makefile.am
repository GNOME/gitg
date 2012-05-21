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

libegglistbox_la_VALAFLAGS = \
	$(AM_VALAFLAGS) \
	--library=egglistbox \
	--vapi egglistbox.vapi \
	-H egg-list-box.h \
	$(NULL)
libegglistbox_la_SOURCES = egg-list-box.vala
libegglistbox_la_LIBADD = $(LISTBOX_LIBS)

noinst_PROGRAMS = test-list test-scrolled

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

CLEANFILES = \
	$(test_list_SOURCES:.vala=.c) \
	$(test_scrolled_SOURCES:.vala=.c) \
	$(libegglistbox_la_SOURCES:.vala=.c) \
	*.vapi *.stamp

EXTRA_DIST = \
	$(NULL)
