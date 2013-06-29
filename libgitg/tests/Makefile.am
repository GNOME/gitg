AM_CPPFLAGS = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS)

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS) --pkg posix

TEST_PROGS = test-libgitg

test_libgitg_SOURCES =				\
	test.vala				\
	main.vala				\
	repository.vala				\
	test-stage.vala

test_libgitg_LDADD = $(GITG_PLUGIN_LIBS)
test_libgitg_CFLAGS = $(GITG_PLUGIN_CFLAGS) -w

TESTS = $(TEST_PROGS)

BUILT_SOURCES =					\
	test_libgitg_vala.stamp

CLEANFILES =					\
	$(test_libgitg_SOURCES:.vala=.c)	\
	$(BUILT_SOURCES)

-include $(top_srcdir)/git.mk
