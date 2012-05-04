INCLUDES = -g -I$(top_srcdir) -I$(top_srcdir)/gitg -I$(top_srcdir)/libgitg $(GITG_DEBUG_FLAGS) $(GITG_CFLAGS)

noinst_PROGRAMS = $(TEST_PROGS)
progs_ldadd     = $(top_builddir)/libgitg/libgitg-1.0.la $(PACKAGE_LIBS) $(GITG_LIBS)

TESTS = $(TEST_PROGS)

-include $(top_srcdir)/git.mk
