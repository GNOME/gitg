NULL =

AM_CPPFLAGS = \
	-include config.h \
	$(LISTBOX_CFLAGS) \
	$(NULL)

AM_VALAFLAGS = \
	@LISTBOX_PACKAGES@ \
	$(NULL)

noinst_PROGRAMS = test-list test-scrolled

test_list_SOURCES = \
	egg-list-box.vala \
	test-list.vala \
	$(NULL)
test_list_LDADD = $(LISTBOX_LIBS)

test_scrolled_SOURCES = \
	egg-list-box.vala \
	test-scrolled.vala \
	$(NULL)
test_scrolled_LDADD = $(LISTBOX_LIBS)

CLEANFILES = \
	$(test_list_SOURCES:.vala=.c) \
	*.vapi *.stamp

EXTRA_DIST = \
	$(NULL)
