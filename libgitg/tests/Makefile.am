AM_CPPFLAGS = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS)

AM_VALAFLAGS = $(GITG_PLUGIN_VALAFLAGS) --vapidir $(srcdir) --pkg posix --pkg gitg-assert

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

EXTRA_DIST = gitg-assert.h gitg-assert.vapi

-include $(top_srcdir)/git.mk
